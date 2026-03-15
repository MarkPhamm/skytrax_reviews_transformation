---
name: CI/CD Pipeline Structure
description: GitHub Actions CI/CD setup for the Skytrax dbt project - workflow files, composite action, and artifact strategy
type: project
---

The dbt CI/CD pipeline was rebuilt from a single monolithic workflow into a multi-job architecture.

**Why:** The old cicd.yml ran everything (PR checks + deploy + docs) in a single job on every trigger. The new setup separates PR validation (slim CI with state comparison) from post-merge deployment, reducing warehouse costs on PRs and improving feedback loops.

**How to apply:**

- PR checks use merge-base manifest diffing (not S3 download) to detect changed models
- Deploy workflow uploads manifest.json and run_results.json to `s3://$S3_ARTIFACTS_BUCKET/artifacts/`
- Docs go to `s3://$S3_ARTIFACTS_BUCKET/docs/`
- dim_date must run before other models (ordering dependency)
- All dbt commands use `--profiles-dir ./` and `--target staging`
- The profiles.yml uses `env_var()` Jinja so no template rendering is needed (unlike Insurify's `{{ key }}` pattern)
