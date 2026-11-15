# One-time, run locally with your own AWS credentials (local state).
# Creates the Terraform state bucket and the IAM user used by CI.
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "eu-north-1" }

data "aws_caller_identity" "me" {}

resource "aws_s3_bucket" "state" {
  bucket = "aws-mlops-demo-tfstate-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

# OIDC provider creation is blocked on this account (needs advanced account activation), see ADR 0002.
# Access key is created by hand (aws iam create-access-key) so the secret never lands in Terraform state.
resource "aws_iam_user" "ci" {
  name = "aws-mlops-demo-ci"
}

# shortcut: PowerUser + IAM limited to this project's roles; tighten to per-service actions if reused beyond a demo
resource "aws_iam_user_policy_attachment" "power" {
  user       = aws_iam_user.ci.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_user_policy" "iam" {
  user = aws_iam_user.ci.name
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
output "ci_user" { value = aws_iam_user.ci.name }
