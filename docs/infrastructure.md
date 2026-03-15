# Infrastructure

All infrastructure is managed with Terraform across two configurations:
Snowflake and AWS.

---

## Snowflake (`terraform/snowflake/`)

### Database & Schemas

| Schema | Purpose |
| ------ | ------- |
| `RAW` | Seed data loaded by `dbt seed` (one-off) |
| `SOURCE` | Production staging models — cleaned and standardized (views) |
| `INTERMEDIATE` | Production intermediate models — business logic (views) |
| `MARTS` | Business-ready tables for BI tools |
| `STAGING` | CI scratch schema — used only during PR checks (flat) |
| `DEV_MINH` | Development schema for Minh (accountadmin) |
| `DEV_GINA` | Development schema for Gina |
| `DEV_VICIENT` | Development schema for Vicient |

### Warehouses

Five warehouses of increasing size, all with auto-suspend (60s) and
auto-resume:

| Warehouse | Size |
| --------- | ---- |
| `SKYTRAX_COMPUTE_XSMALL` | X-Small (default for all users) |
| `SKYTRAX_COMPUTE_SMALL` | Small |
| `SKYTRAX_COMPUTE_MEDIUM` | Medium |
| `SKYTRAX_COMPUTE_LARGE` | Large |
| `SKYTRAX_COMPUTE_XLARGE` | X-Large |

### Role Hierarchy

```text
ACCOUNTADMIN
  └── SYSADMIN
        └── SKYTRAX_ADMIN (full control over project database)
              ├── SKYTRAX_TRANSFORMER (read/write on production schemas)
              └── SKYTRAX_ANALYST (read-only on MARTS + write on own dev schema)
```

### Role Permissions

| Role | Warehouse | Database | Prod Schemas | Dev Schemas | MARTS |
| ---- | --------- | -------- | ------------ | ----------- | ----- |
| SKYTRAX_ADMIN | All privileges | All privileges | Inherited | Inherited | Inherited |
| SKYTRAX_TRANSFORMER | USAGE + OPERATE | USAGE | Full DML | — | Read/write |
| SKYTRAX_ANALYST | USAGE | USAGE | — | Full DML | Read-only |

### Users

| User | Role | Default Schema | Purpose |
| ---- | ---- | -------------- | ------- |
| `PROD_DBT` | SKYTRAX_TRANSFORMER | SOURCE | Production dbt runs |
| `DBT_CICD` | SKYTRAX_TRANSFORMER | STAGING | GitHub Actions CI/CD |
| `GINA_ANALYST` | SKYTRAX_ANALYST | DEV_GINA | Analyst (Gina) |
| `VICIENT_ANALYST` | SKYTRAX_ANALYST | DEV_VICIENT | Analyst (Vicient) |

### Snowflake Setup

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

```text
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

### CloudFront

dbt docs are served via CloudFront + S3 (see [dbt_docs.md](dbt_docs.md)
for full details). The distribution uses Origin Access Control so the
S3 bucket stays private.

### OIDC Provider

GitHub Actions authenticates with AWS using OIDC instead of static
credentials:

- **Provider URL**: `https://token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com`
- **Trust scope**: `repo:MarkPhamm/skytrax_reviews_transformation:*`

### IAM Role

The `skytrax-reviews-github-actions-role` is assumed by GitHub Actions
via OIDC. Its policy grants:

| Action | Resource |
| ------ | -------- |
| `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` | `<bucket-arn>/*` |
| `s3:ListBucket` | `<bucket-arn>` |
| `cloudfront:CreateInvalidation` | `<distribution-arn>` |

### AWS Setup

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
# Fill in: artifacts_bucket_name, github_repository
terraform init
terraform apply
```

### EC2 Docs Server (disabled)

The Terraform config also includes a VPC + EC2 instance for hosting dbt
docs via nginx. This approach was replaced by CloudFront + S3 but the
code is preserved in `ec2.tf.disabled`, `vpc.tf.disabled`, and
`user_data.sh.disabled` for reference.
