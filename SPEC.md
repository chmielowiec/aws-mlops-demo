# SPEC — aws-mlops-demo

## Goal
Public repo demonstrating (exposure, not production experience): Terraform on AWS, MLflow as model registry, GitHub Actions → SageMaker, CloudWatch alarm, rollback.

## Constraints
- Private AWS account, region `eu-central-1`.
- One test cycle (apply → deploy → destroy) costs < 1 USD.
- No long-lived AWS keys: GitHub OIDC only.

## Scope (MVP)
1. **Model:** scikit-learn (iris), trained in CI, logged and registered in MLflow (local file store, no server), alias `champion`.
2. **Infra (Terraform, `terraform-aws-modules` where available):** S3 bucket for model artifacts, SageMaker execution role, GitHub OIDC role, SageMaker **Serverless** endpoint, CloudWatch alarm (Invocation5XXErrors), AWS Budget with email alert. State in S3 backend.
3. **CI (GitHub Actions):**
   - PR: `pytest`, `terraform fmt -check`, `terraform validate`.
   - Manual `deploy`: package `champion` model → new endpoint config → smoke test → on failure revert endpoint to previous config (rollback).
4. **Evidence:** one smoke test, one ADR (serverless vs EKS/real-time), README with teardown (`terraform destroy`).

## Out of scope
EKS (~73 USD/month control plane), hosted MLflow server, drift monitoring, multiple environments, blue/green deployment guardrails (not supported for serverless).

## Acceptance criteria
- `terraform apply` from scratch and `terraform destroy` to zero; only manual step is one-time state bucket + OIDC bootstrap.
- Deploying a deliberately broken model → smoke test fails → endpoint serves the previous version (visible in Actions log).
- CloudWatch alarm and Budget exist after apply.
- Measured cost of one test cycle < 1 USD (Cost Explorer, next day).

## Decisions
- Repo: `chmielowiec/aws-mlops-demo` (public).
- Budget alert email: GitHub secret `BUDGET_EMAIL`.
