terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {} # bucket/key/region passed via -backend-config
}

provider "aws" { region = var.region }

variable "region" { default = "eu-north-1" }
variable "budget_email" { type = string }
variable "model_data_url" {
  type        = string
  default     = ""
  description = "s3:// URL of model.tar.gz; empty = no endpoint yet"
}

locals {
  name   = "aws-mlops-demo"
  deploy = var.model_data_url != ""
}

data "aws_caller_identity" "me" {}

module "artifacts" {
  source        = "terraform-aws-modules/s3-bucket/aws"
  version       = "~> 4.0"
  bucket        = "${local.name}-artifacts-${data.aws_caller_identity.me.account_id}"
  force_destroy = true
}

resource "aws_iam_role" "sagemaker" {
  name = "${local.name}-sagemaker"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "sagemaker.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "sagemaker" {
  role = aws_iam_role.sagemaker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${module.artifacts.s3_bucket_arn}/*" },
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "cloudwatch:PutMetricData"], Resource = "*" },
    ]
  })
}

data "aws_sagemaker_prebuilt_ecr_image" "sklearn" {
  repository_name = "sagemaker-scikit-learn"
  image_tag       = "1.2-1-cpu-py3"
}

resource "aws_sagemaker_model" "this" {
  count              = local.deploy ? 1 : 0
  execution_role_arn = aws_iam_role.sagemaker.arn
  primary_container {
    image          = data.aws_sagemaker_prebuilt_ecr_image.sklearn.registry_path
    model_data_url = var.model_data_url
    environment = {
      SAGEMAKER_PROGRAM          = "inference.py"
      SAGEMAKER_SUBMIT_DIRECTORY = "/opt/ml/model/code"
    }
  }
}

resource "aws_sagemaker_endpoint_configuration" "this" {
  count = local.deploy ? 1 : 0
  production_variants {
    variant_name = "main"
    model_name   = aws_sagemaker_model.this[0].name
    serverless_config {
      memory_size_in_mb = 2048
      max_concurrency   = 1
    }
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_sagemaker_endpoint" "this" {
  count                = local.deploy ? 1 : 0
  name                 = local.name
  endpoint_config_name = aws_sagemaker_endpoint_configuration.this[0].name
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  count               = local.deploy ? 1 : 0
  alarm_name          = "${local.name}-5xx"
  namespace           = "AWS/SageMaker"
  metric_name         = "Invocation5XXErrors"
  dimensions          = { EndpointName = aws_sagemaker_endpoint.this[0].name, VariantName = "main" }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_budgets_budget" "monthly" {
  name         = local.name
  budget_type  = "COST"
  limit_amount = "5"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 20
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}

output "artifacts_bucket" { value = module.artifacts.s3_bucket_id }
output "model_data_url" { value = var.model_data_url }
output "endpoint_name" { value = local.deploy ? aws_sagemaker_endpoint.this[0].name : "" }
output "endpoint_config_name" { value = local.deploy ? aws_sagemaker_endpoint_configuration.this[0].name : "" }
