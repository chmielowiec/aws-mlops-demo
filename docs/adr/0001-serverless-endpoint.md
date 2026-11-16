# ADR 0001: SageMaker Serverless endpoint, rollback in CI

## Status
Accepted

## Context
The demo must show an AWS model deployment with monitoring and rollback, while one test cycle costs under 1 USD on a private account. EKS costs ~73 USD/month for the control plane alone; a real-time endpoint bills per instance-hour while idle.

## Decision
- Serve the model from a SageMaker **Serverless** endpoint (billed per request duration, zero when idle).
- Terraform owns model, endpoint config and endpoint; the deployed artifact is the single variable `model_data_url`.
- When an endpoint update fails (model does not load), SageMaker reverts the endpoint to its previous config, but the Terraform provider still reports success and then deletes that previous config and model. CI therefore compares the live `EndpointConfigName` with the one Terraform created and treats a mismatch, or a failing smoke test, as a failed deploy.
- Rollback = re-apply the previous `model_data_url` after deleting the endpoint with the AWS CLI and waiting for deletion (SageMaker deletes asynchronously, so Terraform `-replace` fails): the endpoint is recreated because the config it reverted to no longer exists (a few minutes of downtime, acceptable for a demo). SageMaker deployment guardrails (blue/green with alarm-based auto-rollback) are not available for serverless endpoints.
- MLflow runs with a local SQLite store inside the CI job; the registry alias `champion` selects what gets packaged.

## Consequences
- Cold starts of several seconds; acceptable for a demo, not for latency-sensitive production.
- The CloudWatch 5xx alarm is informational; it does not trigger rollback.
- The MLflow registry is ephemeral per run; a hosted tracking server would be needed for real lineage across runs.
