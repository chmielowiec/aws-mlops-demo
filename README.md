# aws-mlops-demo

Minimal MLOps loop on AWS: **MLflow** registry → **GitHub Actions** → **SageMaker Serverless** endpoint provisioned with **Terraform**, a **CloudWatch** alarm and automatic **rollback** when the post-deploy smoke test fails.

A learning project: it demonstrates the tooling end to end, not production scale. See [SPEC.md](SPEC.md) and [ADR 0001](docs/adr/0001-serverless-endpoint.md).

```
train.py ──► MLflow (iris@champion) ──► model.tar.gz ──► S3
                                                      │
GitHub Actions (IAM keys) ──► terraform apply ──► SageMaker Serverless endpoint
                     └──► smoke test ── fail ──► terraform apply (previous model)
```

## Layout
| Path | Purpose |
|---|---|
| `train.py` | train, register in MLflow, package the `champion` alias |
| `serving/inference.py` | SageMaker scikit-learn container entry point |
| `tests/test_smoke.py` | local package test; live endpoint test when `ENDPOINT_NAME` is set |
| `bootstrap/` | one-time: state bucket + CI IAM user (local state) |
| `infra/` | artifacts bucket, SageMaker role/model/endpoint, alarm, budget |
| `.github/workflows/` | `ci` (tests, fmt, validate), `deploy` (deploy / rollback drill / destroy) |

## Setup (once)
1. In AWS CloudShell (or with your own credentials): `terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply`.
2. Create the CI key: `aws iam create-access-key --user-name aws-mlops-demo-ci`.
3. In GitHub repo settings:
   - secrets `BUDGET_EMAIL`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
   - variable `TF_STATE_BUCKET` (bootstrap output).

Why keys and not OIDC: [ADR 0002](docs/adr/0002-ci-access-keys.md). Delete the key when you are done.

## Run
- **Actions → deploy → Run workflow**: trains, deploys, smoke-tests.
- Same with **broken** ticked: deploys a model that fails to load; the smoke test fails and the workflow rolls back to the previous model (the run ends red on purpose).
- With **destroy** ticked: removes everything in `infra/`. Bootstrap stays (S3 state bucket, IAM user; ~0 USD).

## Cost
Serverless endpoint bills only per request; one apply → deploy → destroy cycle is expected under 1 USD. An AWS Budget (5 USD/month, alert at 20%) emails `BUDGET_EMAIL`.

## Local
```
python3.10 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/pytest
```
