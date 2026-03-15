# CI/CD Pipeline

## Overview

The project uses two GitHub Actions workflows for continuous integration and deployment. Both authenticate with AWS using **OIDC** (no static credentials) and connect to Snowflake via the `DBT_CICD` service account.

---

## Continuous Deployment — `deploy_main.yml`

**Triggers**: push to `main`, weekly schedule (Monday 00:00 UTC), manual dispatch.

### How It Works

1. **OIDC Authentication**: The workflow assumes an AWS IAM role via GitHub's OIDC provider — no `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` needed.

2. **Incremental Deploy (defer/favor-state)**: Instead of rebuilding every model on each deploy, the workflow downloads the production manifest from S3 and uses dbt's `--defer --favor-state` flags to only rebuild what changed:

   ```bash
   dbt build \
     --select state:modified+ \
     --defer \
     --favor-state \
     --state prod_state \
     --target staging
   ```

   - `state:modified+` — selects models that changed plus their downstream dependencies
   - `--defer` — for unmodified models, reference the production tables instead of rebuilding
   - `--favor-state` — prefer the production state when resolving deferred models

3. **First Run Fallback**: If no prior manifest exists in S3 (very first deploy), the workflow runs a full build:

   ```bash
   dbt seed --target staging
   dbt run --target staging
   dbt test --target staging
   ```

4. **Artifact Upload**: After a successful build, the new manifest and run results are uploaded to S3 for the next deploy cycle:

   ```
   s3://<bucket>/manifests/manifest.json
   s3://<bucket>/run_results/run_results.json
   s3://<bucket>/docs/            # dbt docs site
   ```

5. **Email Notification**: Sends a status email on every run (success or failure).

### Concurrency

Only one deploy runs at a time (`cancel-in-progress: false`). If a second push happens while a deploy is running, it queues rather than cancels the in-progress run.

---

## Continuous Integration — `pr_checks.yml`

**Triggers**: pull request opened, synchronized, or reopened against `main`.

### How It Works

The CI pipeline has 5 jobs that run sequentially:

#### Job 1: Setup & Detect Changes

- Computes the merge-base between the PR branch and `main`
- Checks out the base code and runs `dbt parse` to produce a baseline manifest
- Parses the PR code and uses `dbt ls --state base_state --select state:modified state:new` to find changed models
- Outputs: list of changed models, boolean flag for whether changes exist

#### Job 2: Lint SQL

- Runs `sqlfluff lint` on changed `.sql` files only (not the entire project)
- Uses merge-base diff to identify which files changed

#### Job 3: Compile Changed Models

- Runs `dbt compile --select <changed_models>` to verify SQL compiles
- Only runs if changes were detected

#### Job 4: Run Changed Models

- Runs `dbt run --select <changed_models> --defer --state base_state`
- Uses `--defer` so unchanged upstream models reference the base state instead of being rebuilt
- Only runs if compilation succeeded

#### Job 5: Test Changed Models

- Runs `dbt test --select <changed_models> --defer --state base_state`
- Tests only the models that changed
- Only runs if the run step succeeded

### Concurrency

PRs cancel in-progress runs on the same PR number (`cancel-in-progress: true`). This saves CI minutes when pushing rapid commits.

---

## S3 Artifact Layout

```
s3://<bucket>/
├── manifests/
│   └── manifest.json          # Production state for defer/favor-state
├── run_results/
│   └── run_results.json       # Last deploy results
└── docs/
    ├── index.html             # dbt docs site
    ├── catalog.json
    └── manifest.json
```

---

## GitHub Secrets Required

| Secret | Description | Example |
|--------|-------------|---------|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | `nvnjoib-on80344` |
| `SNOWFLAKE_USER` | CI/CD service account | `DBT_CICD` |
| `SNOWFLAKE_PASSWORD` | Password for DBT_CICD | — |
| `SNOWFLAKE_ROLE` | Role for CI/CD | `SKYTRAX_TRANSFORMER` |
| `SNOWFLAKE_SCHEMA` | Target schema | `STAGING` |
| `AWS_ROLE_ARN` | IAM role ARN for OIDC | `arn:aws:iam::<account>:role/skytrax-reviews-github-actions-role` |
| `S3_ARTIFACTS_BUCKET` | S3 bucket for artifacts | `skytrax-reviews-dbt-artifacts-<account>` |
| `EMAIL_USERNAME` | Gmail for notifications | — |
| `EMAIL_PASSWORD` | Gmail app password | — |

---

## OIDC Authentication Flow

```
GitHub Actions Runner
  │
  ├─ 1. Request OIDC token from GitHub's token endpoint
  │     (includes repo, branch, and event in "sub" claim)
  │
  ├─ 2. Call aws-actions/configure-aws-credentials
  │     (passes OIDC token + role ARN to AWS STS)
  │
  ├─ 3. AWS STS validates token against registered OIDC provider
  │     - Checks audience = "sts.amazonaws.com"
  │     - Checks subject matches "repo:MarkPhamm/skytrax_reviews_transformation:*"
  │
  └─ 4. STS returns temporary credentials (15 min default)
        (workflow can now call S3 APIs)
```

No long-lived AWS credentials are stored anywhere. The trust is established between GitHub's OIDC issuer and the AWS IAM role's trust policy.
