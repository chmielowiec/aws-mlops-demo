#!/usr/bin/env bash
# Delete the endpoint and wait until it is really gone: SageMaker deletes asynchronously and
# Terraform's -replace recreates too early ("Cannot create already existing endpoint").
set -euo pipefail
EP=aws-mlops-demo
aws sagemaker delete-endpoint --endpoint-name "$EP" 2>/dev/null || true
aws sagemaker wait endpoint-deleted --endpoint-name "$EP"
terraform -chdir=infra state rm 'aws_sagemaker_endpoint.this[0]' 2>/dev/null || true
