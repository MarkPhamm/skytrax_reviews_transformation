# Skytrax Airline Reviews Data Transformation

A modern data transformation and CI/CD pipeline for airline industry analytics, processing **100,000+ customer reviews** from **500+ airlines** via [Skytrax Airline Quality](https://www.airlinequality.com/). Built with **dbt**, **Snowflake**, **Terraform**, **GitHub Actions**, **AWS S3**, **AWS IAM OIDC**, **AWS EC2**, **nginx**, **Apache Airflow (Astronomer)**, **SQLFluff**, and **Python**.

![image](https://github.com/user-attachments/assets/44063b8d-ad6b-45a3-b802-de5b449cc5d4)

---

## Project Structure

```text
.
├── dbt/     # dbt project (single source of truth)
│   ├── models/
│   │   ├── staging/            # 1:1 source mirrors (views)
│   │   ├── intermediate/       # Cleaned/normalized business logic
│   │   └── marts/              # Star schema dims + facts (tables)
│   ├── macros/                 # Custom dbt macros
│   ├── tests/                  # Data quality tests
│   └── profiles.yml            # Snowflake connection (env vars, no secrets)
├── dbt-dags/                   # Astronomer/Airflow orchestration
│   ├── dags/
│   │   ├── transformation_dag.py
│   │   └── dbt/ -> ../../dbt  (symlink)
│   └── Dockerfile
├── terraform/
│   ├── snowflake/              # Snowflake RBAC, users, warehouses, schemas
│   └── aws/                    # S3 artifacts, OIDC, VPC, EC2 docs hosting
├── .github/
│   ├── workflows/
│   │   ├── deploy_main.yml     # CD: build, deploy, upload artifacts
│   │   └── pr_checks.yml       # CI: lint, compile, run, test changed models
│   └── actions/
│       └── dbt-ci-init/        # Composite action: Python, venv, dbt deps
├── docs/                       # Project documentation
├── data/                       # Raw CSV data
├── notebooks/                  # Snowflake analysis notebooks
├── setup.cfg                   # SQLFluff linting config
└── requirements.txt
```

---

## Technology Stack

| Layer | Tool |
|-------|------|
| Data Warehouse | Snowflake |
| Transformation | dbt (dbt-snowflake) |
| Orchestration | Apache Airflow (Astronomer) |
| Infrastructure | Terraform (AWS + Snowflake) |
| CI/CD | GitHub Actions |
| Authentication | AWS OIDC (keyless) |
| Linting | SQLFluff |
| Docs Hosting | EC2 + nginx |
| Artifact Storage | S3 |

---

## Data Model

### Star Schema

The project follows **Kimball star schema** methodology with deterministic surrogate keys (`dbt_utils.generate_surrogate_key`).

**Grain**: one row per customer review per flight.

| Model | Type | Description |
|-------|------|-------------|
| `fct_review` | Fact | Review metrics, ratings, calculated averages, and rating bands |
| `dim_customer` | Dimension | Reviewer identity and flight count |
| `dim_airline` | Dimension | Airline name |
| `dim_aircraft` | Dimension | Aircraft model, manufacturer, seat capacity |
| `dim_location` | Dimension | City + airport (role-playing: origin, destination, transit) |
| `dim_date` | Dimension | Calendar + fiscal dates (role-playing: submitted, flown) |

### DAG Flow

```
source (raw.skytrax_reviews)
  └── stg__skytrax_reviews (SOURCE schema, view)
        └── int_reviews_cleaned (INTERMEDIATE schema, view)
              ├── dim_customer (MARTS schema, table)
              ├── dim_airline
              ├── dim_aircraft
              ├── dim_location
              ├── dim_date (macro-generated, one_time_run tag)
              └── fct_review (joins all dimensions, calculates average_rating + rating_band)
```

![schema](https://github.com/user-attachments/assets/f6276b06-9f03-410a-b2cc-785b0a23b8f2)

---

## CI/CD Pipeline

See [docs/cicd.md](docs/cicd.md) for full details.

### Continuous Deployment (merge to `main`)

Uses **defer/favor-state** for incremental deploys — only modified models and their downstream dependencies are rebuilt:

```
1. Checkout code + configure AWS via OIDC
2. Download production manifest from S3 (if exists)
3. dbt build --select state:modified+ --defer --favor-state --state prod_state
4. Generate and upload dbt docs to S3
5. Upload manifest + run_results to S3 for next deploy
6. Email notification
```

Falls back to a full build if no prior manifest exists (first run).

### Continuous Integration (pull requests)

Uses **merge-base state comparison** — only changed models are linted, compiled, run, and tested:

```
1. Build merge-base manifest (state baseline from main)
2. Detect changed models (state:modified + state:new)
3. Lint changed SQL files with SQLFluff
4. Compile changed models
5. Run changed models with --defer to base state
6. Test changed models with --defer to base state
```

---

## Infrastructure

See [docs/infrastructure.md](docs/infrastructure.md) for full details.

### Snowflake (`terraform/snowflake/`)

| Resource | Details |
|----------|---------|
| Database | `SKYTRAX_REVIEWS_DB` |
| Warehouses | 5 sizes: `SKYTRAX_COMPUTE_XSMALL` through `XLARGE` |
| Production Schemas | `RAW`, `SOURCE`, `INTERMEDIATE`, `MARTS` |
| CI Schema | `STAGING` (scratch space for PR checks) |
| Dev Schemas | `DEV_MINH`, `DEV_GINA`, `DEV_VICIENT` (per-user) |
| Roles | `SKYTRAX_ADMIN` > `SKYTRAX_TRANSFORMER` + `SKYTRAX_ANALYST` |
| Service Accounts | `PROD_DBT`, `DBT_CICD` (transformer role) |
| Analyst Users | `GINA_ANALYST`, `VICIENT_ANALYST` (analyst role) |

### AWS (`terraform/aws/`)

| Resource | Purpose |
|----------|---------|
| S3 Bucket | dbt artifacts (manifests, run_results, docs) — versioned, encrypted |
| OIDC Provider | GitHub Actions keyless authentication |
| IAM Role | CI/CD role with S3 read/write (assumed via OIDC) |

---

## Local Development

See [docs/local-development.md](docs/local-development.md) for full details.

### Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Set Snowflake env vars
export SNOWFLAKE_ACCOUNT='nvnjoib-on80344'
export SNOWFLAKE_USER='your-user'
export SNOWFLAKE_PASSWORD='your-password'
export SNOWFLAKE_ROLE='SKYTRAX_TRANSFORMER'

# 3. Run dbt
cd dbt
dbt deps --profiles-dir ./
dbt debug --profiles-dir ./
dbt run --profiles-dir ./         # uses dev target (your DEV_* schema)
dbt test --profiles-dir ./
```

### SQL Linting

```bash
sqlfluff lint models/
sqlfluff fix models/
```

---

## GitHub Secrets

| Secret | Description |
|--------|-------------|
| `SNOWFLAKE_ACCOUNT` | `nvnjoib-on80344` |
| `SNOWFLAKE_USER` | `DBT_CICD` |
| `SNOWFLAKE_PASSWORD` | Password for DBT_CICD user |
| `SNOWFLAKE_ROLE` | `SKYTRAX_TRANSFORMER` |
| `AWS_ROLE_ARN` | IAM role ARN for OIDC (from `terraform output`) |
| `S3_ARTIFACTS_BUCKET` | S3 bucket name for artifacts |
| `EMAIL_USERNAME` | Gmail address for deploy notifications |
| `EMAIL_PASSWORD` | Gmail app password |

---

## Workflow Status

[![Deploy Main](https://github.com/MarkPhamm/skytrax_reviews_transformation/actions/workflows/deploy_main.yml/badge.svg)](https://github.com/MarkPhamm/skytrax_reviews_transformation/actions/workflows/deploy_main.yml)
[![PR Checks](https://github.com/MarkPhamm/skytrax_reviews_transformation/actions/workflows/pr_checks.yml/badge.svg)](https://github.com/MarkPhamm/skytrax_reviews_transformation/actions/workflows/pr_checks.yml)
