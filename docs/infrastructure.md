# Infrastructure

All infrastructure is managed with Terraform across two configurations: Snowflake and AWS.

---

## Snowflake (`terraform/snowflake/`)

### Database & Schemas

| Schema | Purpose |
|--------|---------|
| `RAW` | Seed data loaded by `dbt seed` |
| `STAGING` | Staging models — cleaned and standardized (views) |
| `MARTS` | Business-ready tables for BI tools |
| `DEV_MINH` | Development schema for Minh (accountadmin) |
| `DEV_GINA` | Development schema for Gina |
| `DEV_VICIENT` | Development schema for Vicient |

### Warehouses

Five warehouses of increasing size, all with auto-suspend (60s) and auto-resume:

| Warehouse | Size |
|-----------|------|
| `SKYTRAX_COMPUTE_XSMALL` | X-Small (default for all users) |
| `SKYTRAX_COMPUTE_SMALL` | Small |
| `SKYTRAX_COMPUTE_MEDIUM` | Medium |
| `SKYTRAX_COMPUTE_LARGE` | Large |
| `SKYTRAX_COMPUTE_XLARGE` | X-Large |

### Role Hierarchy

```
ACCOUNTADMIN
  └── SYSADMIN
        └── SKYTRAX_ADMIN (full control over project database)
              ├── SKYTRAX_TRANSFORMER (read/write on production schemas)
              └── SKYTRAX_ANALYST (read-only on MARTS + write on own dev schema)
```

### Role Permissions

| Role | Warehouse | Database | Production Schemas | Dev Schemas | MARTS |
|------|-----------|----------|--------------------|-------------|-------|
| SKYTRAX_ADMIN | All privileges | All privileges | Inherited | Inherited | Inherited |
| SKYTRAX_TRANSFORMER | USAGE + OPERATE | USAGE | USAGE, CREATE TABLE/VIEW, full DML on future tables/views | — | Read/write |
| SKYTRAX_ANALYST | USAGE | USAGE | — | USAGE, CREATE TABLE/VIEW, full DML on future tables/views | Read-only (SELECT on future tables/views) |

### Users

| User | Role | Default Schema | Purpose |
|------|------|----------------|---------|
| `PROD_DBT` | SKYTRAX_TRANSFORMER | STAGING | Production dbt runs |
| `DBT_CICD` | SKYTRAX_TRANSFORMER | STAGING | GitHub Actions CI/CD |
| `GINA_ANALYST` | SKYTRAX_ANALYST | DEV_GINA | Analyst (Gina) |
| `VICIENT_ANALYST` | SKYTRAX_ANALYST | DEV_VICIENT | Analyst (Vicient) |

### Setup

```bash
cd terraform/snowflake
cp terraform.tfvars.example terraform.tfvars
# Fill in: snowflake_organization_name, snowflake_account_name,
#          snowflake_admin_user, snowflake_admin_password,
#          prod_dbt_password, cicd_user_password,
#          gina_analyst_password, vicient_analyst_password
terraform init
terraform plan
terraform apply
```

---

## AWS (`terraform/aws/`)

### S3 Bucket

A single bucket stores all dbt artifacts with organized prefixes:

```
s3://skytrax-reviews-dbt-artifacts-<account-id>/
├── manifests/manifest.json       # Production state for defer/favor-state
├── run_results/run_results.json  # Last deploy results
└── docs/                         # dbt docs site (HTML + JSON)
```

**Configuration**:

- Versioning enabled (recover previous artifact states)
- Server-side encryption (AES-256)
- All public access blocked
- Lifecycle rule: noncurrent versions expire after 30 days

### OIDC Provider

GitHub Actions authenticates with AWS using OIDC instead of static credentials:

- **Provider URL**: `https://token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com`
- **Trust scope**: `repo:MarkPhamm/skytrax_reviews_transformation:*` (covers both pushes and PRs)

### IAM Role

The `skytrax-reviews-github-actions-role` is assumed by GitHub Actions via OIDC. Its policy grants:

| Action | Resource |
|--------|----------|
| `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` | `<bucket-arn>/*` |
| `s3:ListBucket` | `<bucket-arn>` |

### Setup

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
# Fill in: artifacts_bucket_name, github_repository, ssh_key_name
terraform init

# Deploy S3 + OIDC only (skip EC2/VPC for now)
terraform apply \
  -target=aws_s3_bucket.dbt_artifacts \
  -target=aws_s3_bucket_versioning.dbt_artifacts \
  -target=aws_s3_bucket_server_side_encryption_configuration.dbt_artifacts \
  -target=aws_s3_bucket_public_access_block.dbt_artifacts \
  -target=aws_s3_bucket_lifecycle_configuration.dbt_artifacts \
  -target=aws_iam_openid_connect_provider.github_actions \
  -target=aws_iam_role.github_actions_cicd \
  -target=aws_iam_role_policy.github_actions_s3

# Note the outputs for GitHub secrets:
# - github_actions_role_arn  → AWS_ROLE_ARN secret
# - artifacts_bucket_name    → S3_ARTIFACTS_BUCKET secret
```

### EC2 Docs Server (not yet deployed)

The Terraform config also includes a VPC + EC2 instance for hosting dbt docs via nginx. This is defined but not yet applied — deploy with a full `terraform apply` when ready.
