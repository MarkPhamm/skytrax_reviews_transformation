# Local Development

## Prerequisites

- Python 3.12+
- dbt-snowflake
- Snowflake account with appropriate credentials

## Setup

### 1. Install Dependencies

```bash
python -m venv dbt_venv
source dbt_venv/bin/activate
pip install -r requirements-dev.txt  # includes dbt + dev tools (pandas, ipykernel, etc.)
```

### 2. Set Environment Variables

Set these based on your Snowflake user. Each developer has their own dev schema (`SNOWFLAKE_SCHEMA`).

```bash
export SNOWFLAKE_ACCOUNT=nvnjoib-on80344
export SNOWFLAKE_USER=your_user            # your Snowflake username
export SNOWFLAKE_PASSWORD=your_password
export SNOWFLAKE_ROLE=SKYTRAX_ANALYST
export SNOWFLAKE_SCHEMA=DEV_your_name      # your personal dev schema (e.g., DEV_MINH)
```

Add these to your `~/.zshrc` or a `.envrc` so you don't have to set them every session.

### 3. Run dbt

```bash
cd dbt
dbt deps --profiles-dir ./
dbt debug --profiles-dir ./          # verify connection
dbt seed --profiles-dir ./           # load seed data
dbt run --profiles-dir ./            # run models (dev target)
dbt test --profiles-dir ./           # run tests
dbt docs generate --profiles-dir ./  # generate docs
dbt docs serve --profiles-dir ./     # serve docs locally
```

---

## SQL Linting

Linting is configured in `setup.cfg` at the project root using SQLFluff with the dbt templater.

### Rules

- All SQL must be **lowercased** (keywords, functions, identifiers, literals)
- **Trailing commas** required
- **Explicit column aliases** (`as` keyword required)
- **Shorthand casting** (`::` instead of `CAST()`)
- No implicit table aliases

### Commands

```bash
# Lint all models
sqlfluff lint models/

# Lint a specific file
sqlfluff lint models/staging/stg__skytrax_reviews.sql

# Auto-fix linting issues
sqlfluff fix models/
```

---

## Warehouse Selection

Five warehouses are available. All users default to `SKYTRAX_COMPUTE_XSMALL`. To use a larger warehouse for heavy queries:

```sql
USE WAREHOUSE SKYTRAX_COMPUTE_MEDIUM;
```

Or override in your dbt profile:

```yaml
warehouse: SKYTRAX_COMPUTE_MEDIUM
```

---

## Local Airflow (Astronomer)

The `dbt-dags/` directory contains an Astronomer project. The dbt project is mounted into the container via `docker-compose.override.yml`.

```bash
cd dbt-dags
astro dev start
```

- **Airflow UI**: <http://localhost:8082> (webserver) or <http://localhost:8083> (API server)
- **Postgres**: localhost:5433
- **DAG**: `skytrax_dbt_transformation` — runs all dbt models as `PROD_DBT` user via the `cosmos` provider
- **Snowflake connection**: configured in `dbt-dags/.env` via `AIRFLOW_CONN_SNOWFLAKE_DEFAULT`
