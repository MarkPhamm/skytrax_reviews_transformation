# Skytrax Airline Reviews Data Transformation

A modern data transformation and CI/CD pipeline for airline industry analytics, processing **100,000+ customer reviews** from **500+ airlines** via [Skytrax Airline Quality](https://www.airlinequality.com/). Built with **dbt**, **Snowflake**, **Terraform**, and **GitHub Actions**.

![image](https://github.com/user-attachments/assets/44063b8d-ad6b-45a3-b802-de5b449cc5d4)

---

## Project Structure

```
.
├── skytrax_transformation/     # dbt project (single source of truth)
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
│   │   └── dbt/ -> ../../skytrax_transformation  (symlink)
│   └── Dockerfile
├── terraform/
│   ├── snowflake/              # Snowflake RBAC, users, warehouses, schemas
│   └── aws/                    # S3 artifacts, VPC, EC2 dbt docs hosting
├── .github/workflows/
│   └── cicd.yml                # CI/CD pipeline
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
  └── stg__skytrax_reviews (staging, view)
        └── int_reviews_cleaned (intermediate, cleaning + normalization)
              ├── dim_customer
              ├── dim_airline
              ├── dim_aircraft
              ├── dim_location
              ├── dim_date (macro-generated, one_time_run tag)
              └── fct_review (joins all dimensions, calculates average_rating + rating_band)
```

![schema](https://github.com/user-attachments/assets/f6276b06-9f03-410a-b2cc-785b0a23b8f2)

---

## CI/CD Pipeline

### Workflow Triggers

| Trigger | When |
|---------|------|
| Push | Merge to `main` |
| Pull Request | PR opened against `main` |
| Schedule | Every Monday 00:00 UTC |
| Manual | `workflow_dispatch` |

### Pipeline Steps

```
1. Checkout code
2. Set up Python 3.12 + install dependencies
3. dbt deps → dbt debug (staging target)
4. dbt run --target staging (dim_date first, then remaining models)
5. dbt docs generate → upload to S3 (/docs/)
6. Upload manifest.json + run_results.json to S3 (/artifacts/)
7. Email notification with status
```

The pipeline uses the **staging** target (writes to `STAGING` schema in Snowflake), keeping `DEV` for local development and `MARTS` for production.

### Slim CI (State Comparison)

After each successful run, `manifest.json` is uploaded to S3. This enables **slim CI** on PRs — only modified models and their downstream dependencies are built:

```bash
dbt build --select state:modified+ --state ./artifacts/
```

### dbt Docs Hosting

dbt docs are auto-published on every merge to `main`:
1. CI generates docs and syncs to S3
2. EC2 instance (nginx) pulls from S3 every 5 minutes
3. Docs are served at `http://<ec2-public-ip>`

---

## Infrastructure (Terraform)

### Snowflake (`terraform/snowflake/`)

| Resource | Purpose |
|----------|---------|
| Roles | `TRANSFORMER` (CI/CD), `ANALYST` (read-only), `ADMIN` |
| Users | Created with passwords, assigned to roles |
| Schemas | RAW, STAGING, MARTS, DEV |
| Grants | Future grants on tables/views for automatic permission inheritance |
| Warehouses | COMPUTE_WH for transformations |

### AWS (`terraform/aws/`)

| File | Resources |
|------|-----------|
| `s3.tf` | Artifacts bucket (versioned, encrypted, lifecycle rules) |
| `vpc.tf` | VPC, public subnet, internet gateway, route table |
| `iam.tf` | IAM role + instance profile for EC2 → S3 access |
| `ec2.tf` | t3.micro running nginx, security group (HTTP + SSH) |

### Setup

```bash
# Snowflake
cd terraform/snowflake
cp terraform.tfvars.example terraform.tfvars  # fill in credentials
terraform init && terraform plan && terraform apply

# AWS
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars  # fill in credentials
terraform init && terraform plan && terraform apply
```

---

## Local Development

### Prerequisites

- Python 3.12+
- dbt-snowflake
- Snowflake account with appropriate permissions

### Setup

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Set Snowflake env vars
export SNOWFLAKE_ACCOUNT='your-account'
export SNOWFLAKE_USER='your-user'
export SNOWFLAKE_PASSWORD='your-password'
export SNOWFLAKE_ROLE='your-role'

# 3. Run dbt
cd skytrax_transformation
dbt deps
dbt debug --profiles-dir ./
dbt run --profiles-dir ./         # uses dev target (DEV schema)
dbt test --profiles-dir ./
dbt docs generate --profiles-dir ./
dbt docs serve --profiles-dir ./
```

### SQL Linting

Linting is configured in `setup.cfg` (SQLFluff with dbt templater):
- All SQL lowercase (keywords, functions, identifiers)
- Trailing commas
- Shorthand casting (`::`)
- Explicit column aliases

```bash
sqlfluff lint models/
sqlfluff fix models/
```

### Local Airflow (Astronomer)

The `dbt-dags/` directory symlinks to the root dbt project — no code duplication.

```bash
cd dbt-dags
astro dev start
```

---

## GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier |
| `SNOWFLAKE_USER` | Snowflake username |
| `SNOWFLAKE_PASSWORD` | Snowflake password |
| `SNOWFLAKE_ROLE` | Snowflake role |
| `SNOWFLAKE_SCHEMA` | Target schema |
| `AWS_ACCESS_KEY_ID` | AWS access key for S3 uploads |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `S3_ARTIFACTS_BUCKET` | S3 bucket name for artifacts/docs |
| `EMAIL_USERNAME` | Gmail address for notifications |
| `EMAIL_PASSWORD` | Gmail app password |

---

## Workflow Status

[![BA Transformation](https://github.com/MarkPhamm/skytrax_reviews_transformation/actions/workflows/cicd.yml/badge.svg)](https://github.com/MarkPhamm/skytrax_reviews_transformation/actions/workflows/cicd.yml)
