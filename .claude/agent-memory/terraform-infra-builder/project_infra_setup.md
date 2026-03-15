---
name: Terraform infrastructure setup
description: Terraform config at terraform/ with snowflake/ and aws/ modules for RBAC, S3 artifacts, and EC2 docs hosting
type: project
---

Terraform infrastructure lives at `../terraform/` (relative to the dbt project root) with two independent root modules:

- `snowflake/` -- RBAC (SKYTRAX_ADMIN, SKYTRAX_TRANSFORMER, SKYTRAX_ANALYST roles), users (DBT_TRANSFORMER, SKYTRAX_ANALYST), warehouse SKYTRAX_COMPUTE_WH, database SKYTRAX_REVIEWS_DB with schemas RAW/STAGING/MARTS/DEV
- `aws/` -- S3 bucket for dbt artifacts (slim CI), VPC + public subnet, EC2 t3.micro with nginx for dbt docs hosting, IAM instance profile for S3 read
s
**Why:** Project needs CI/CD artifact storage for dbt slim CI and a simple docs hosting solution.
**How to apply:** Each module is applied independently (`terraform init && terraform apply` in each directory). No shared remote state backend configured yet -- using local state.
