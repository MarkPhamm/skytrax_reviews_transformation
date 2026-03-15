# CI/CD Pipeline

## Overview

Two GitHub Actions workflows handle continuous integration and deployment.
Both authenticate with AWS using **OIDC** (no static credentials) and
connect to Snowflake via the `DBT_CICD` service account with the
`SKYTRAX_TRANSFORMER` role.

---

## Continuous Deployment — `deploy_main.yml`

**Triggers:**

- Push to `main` (only when `dbt/`, `requirements.txt`, or workflow files change)
- Weekly schedule (Monday 00:00 UTC)
- Manual dispatch

**Concurrency:** Only one deploy runs at a time. If a second push happens
while a deploy is running, it queues instead of cancelling.

### Step-by-Step Walkthrough

#### Step 1: Setup

| What | Why |
| ---- | --- |
| Checkout code with full history | Needed for state comparison |
| Assume AWS IAM role via OIDC | Keyless auth — no static AWS credentials |
| Create Python venv, install dbt + sqlfluff | Fresh venv every run (no caching) |
| Install dbt packages (`dbt deps`) | Pulls dbt_utils, dbt_expectations, etc. |
| `dbt debug --target prod` | Verify Snowflake connection before doing any work |

#### Step 2: Download Production State

```bash
aws s3 cp s3://<bucket>/manifests/manifest.json prod_state/manifest.json
```

Downloads the manifest from the last successful deploy. If this is the
very first deploy and no manifest exists, the workflow flags it and falls
back to a full build in the next step.

#### Step 3: Build Models

**If production manifest exists (normal case):**

```bash
dbt build \
  --select state:modified+ \
  --defer \
  --favor-state \
  --state prod_state \
  --target prod
```

- `state:modified+` — selects models that changed since the last deploy,
  plus all their downstream dependencies
- `--defer` — for unmodified models, reference the existing production
  tables instead of rebuilding them
- `--favor-state` — when resolving deferred refs, prefer the production
  state over the local project
- Result: only the models you actually changed get rebuilt

**If no production manifest exists (first deploy):**

```bash
dbt run --target prod
dbt test --target prod
```

Runs and tests everything from scratch.

#### Step 4: Generate and Upload dbt Docs

```bash
dbt docs generate --target prod

aws s3 sync target/ s3://<bucket>/docs/ \
  --delete \
  --include "*.html" \
  --include "*.json"
```

Generates the static docs site (`index.html`, `catalog.json`,
`manifest.json`) and syncs it to S3.

#### Step 5: Invalidate CloudFront Cache

```bash
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

Busts the CloudFront cache so the latest docs are live immediately at
<https://d38l3fc9bckvbz.cloudfront.net>.

#### Step 6: Upload Artifacts for Next Deploy

```bash
aws s3 cp target/manifest.json s3://<bucket>/manifests/manifest.json
aws s3 cp target/run_results.json s3://<bucket>/run_results/run_results.json
```

Saves the new manifest so the next deploy can use `--defer --favor-state`
against it. This is what closes the loop — each deploy builds on the
last one.

#### Step 7: Email Notification

Sends a status email (success or failure) with a link to the workflow run.
Runs even if previous steps failed (`if: always()`).

---

## Continuous Integration — `pr_checks.yml`

**Triggers:** Pull request opened, synchronized, or reopened against `main`.

**Concurrency:** Cancels in-progress runs on the same PR number. Saves
CI minutes when pushing rapid commits.

### CI Step-by-Step Walkthrough

The CI pipeline has **5 sequential jobs**. Each job sets up its own
fresh Python venv (no caching). Jobs 3-5 only run if changes are detected.

#### Job 1: Setup & Detect Changes

**Goal:** Figure out which dbt models changed in this PR.

```text
1. Compute merge-base SHA between PR branch and main
2. Check out the base code (main at merge point)
3. Run dbt parse on the base code → produces baseline manifest
4. Run dbt parse on the PR code
5. Run dbt ls --state base_state --select state:modified state:new
6. Output: list of changed model names + boolean has_changes flag
7. Upload base manifest and changed models list as artifacts
```

The merge-base approach is important — it compares your PR against the
point where your branch diverged from `main`, not against the latest
`main`. This avoids false positives from other PRs that merged while
you were working.

#### Job 2: Lint SQL

**Goal:** Catch style/formatting issues early.

```text
1. Compute the same merge-base SHA
2. git diff --name-only to find changed .sql files
3. Run sqlfluff lint on only those files
```

Uses the `setup.cfg` config at the project root (lowercased SQL,
trailing commas, explicit aliases, shorthand casting).

This job runs in parallel with Job 1 — it doesn't need the changed
models list, just the git diff.

#### Job 3: Compile Changed Models

**Goal:** Verify the SQL compiles without hitting Snowflake.

```bash
dbt compile --select <changed_models> --target staging
```

- Only runs if Job 1 found changes (`has_changes == true`)
- Catches Jinja errors, missing refs, and syntax issues
- No Snowflake queries — pure compilation

#### Job 4: Run Changed Models

**Goal:** Actually execute the changed models against Snowflake.

```bash
dbt run \
  --select <changed_models> \
  --defer \
  --state base_state \
  --target staging \
  --fail-fast
```

- Uses `--defer` so unchanged upstream models reference the base state
  (from the merge-base manifest) instead of being rebuilt
- `--target staging` writes to the `STAGING` schema (CI scratch space)
- `--fail-fast` stops on first failure to save time
- Only runs if compilation succeeded (depends on Job 3)

#### Job 5: Test Changed Models

**Goal:** Run data quality tests on the models you changed.

```bash
dbt test \
  --select <changed_models> \
  --defer \
  --state base_state \
  --target staging
```

- Same defer logic — unchanged upstream models use the base state
- Tests run in the `STAGING` schema
- Only runs if the run step succeeded (depends on Job 4)

---

## S3 Artifact Layout

```text
s3://<bucket>/
├── manifests/
│   └── manifest.json          # Production state for defer/favor-state
├── run_results/
│   └── run_results.json       # Last deploy results
└── docs/
    ├── index.html             # dbt docs site (served by CloudFront)
    ├── catalog.json
    └── manifest.json
```

---

## OIDC Authentication Flow

```text
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
        (workflow can now call S3 and CloudFront APIs)
```

No long-lived AWS credentials are stored anywhere. The trust is
established between GitHub's OIDC issuer and the AWS IAM role's trust
policy (defined in `terraform/aws/iam.tf`).

---

## GitHub Secrets Required

| Secret | Description | Example |
| ------ | ----------- | ------- |
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | `nvnjoib-on80344` |
| `SNOWFLAKE_USER` | CI/CD service account | `DBT_CICD` |
| `SNOWFLAKE_PASSWORD` | Password for DBT_CICD | — |
| `SNOWFLAKE_ROLE` | Role for CI/CD | `SKYTRAX_TRANSFORMER` |
| `AWS_ROLE_ARN` | IAM role ARN for OIDC | `arn:aws:iam::<id>:role/...` |
| `S3_ARTIFACTS_BUCKET` | S3 bucket for artifacts | `skytrax-reviews-dbt-artifacts-<id>` |
| `CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution for docs | `E3LT0BDSMSIG7H` |
| `EMAIL_USERNAME` | Gmail for notifications | — |
| `EMAIL_PASSWORD` | Gmail app password | — |
