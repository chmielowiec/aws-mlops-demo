# One-time, run locally with your own AWS credentials (local state).
# Creates the Terraform state bucket and the GitHub OIDC role used by CI.
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "eu-north-1" }

variable "repo" { default = "chmielowiec/aws-mlops-demo" }

data "aws_caller_identity" "me" {}

resource "aws_s3_bucket" "state" {
  bucket = "aws-mlops-demo-tfstate-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "ci" {
  name = "aws-mlops-demo-ci"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        # only workflows on main can deploy
        StringLike = { "token.actions.githubusercontent.com:sub" = "repo:${var.repo}:ref:refs/heads/main" }
      }
    }]
  })
}

# shortcut: PowerUser + IAM limited to this project's roles; tighten to per-service actions if reused beyond a demo
resource "aws_iam_role_policy_attachment" "power" {
  role       = aws_iam_role.ci.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy" "iam" {
  role = aws_iam_role.ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole", "iam:TagRole", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole"]
      Resource = "arn:aws:iam::${data.aws_caller_identity.me.account_id}:role/aws-mlops-demo-sagemaker"
    }]
  })
}

output "state_bucket" { value = aws_s3_bucket.state.id }
output "ci_role_arn" { value = aws_iam_role.ci.arn }
