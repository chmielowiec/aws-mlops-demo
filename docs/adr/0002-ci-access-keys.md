# ADR 0002: CI authenticates with IAM user access keys, not OIDC

## Status
Accepted (supersedes the OIDC part of SPEC)

## Context
Creating the GitHub OIDC identity provider failed with `AccessDenied` from an organization service control policy; the account needs advanced activation to allow it. Creating an IAM user and access key is allowed.

## Decision
- Bootstrap creates IAM user `aws-mlops-demo-ci` with PowerUserAccess plus IAM actions limited to the project's SageMaker role.
- The access key is created manually with the AWS CLI and stored only in GitHub secrets, never in Terraform state.
- The `deploy` workflow runs only on manual dispatch.

## Consequences
- Long-lived credentials: rotate the key (`aws iam create-access-key` / `delete-access-key`) and delete it when the demo is done.
- A leaked key grants PowerUser on the account until revoked; the AWS Budget alert is the cost backstop.
- Migrate back to OIDC (no stored secrets, branch-scoped trust) once the account allows it.
