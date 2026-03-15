# Kimball Best-Practice Redesign - Implementation Notes

## Overview

This document summarizes the comprehensive Kimball dimensional modeling redesign of the Skytrax reviews transformation dbt project.

## Critical Changes

### 1. Surrogate Keys (CRITICAL FIX)

**Issue**: All dimensions used `row_number() over (...)` which is non-deterministic and not idempotent.
**Solution**: Replaced with `dbt_utils.generate_surrogate_key()` in ALL dimension and fact models.

Models updated:

- `dim_customer.sql` — from (customer_name, nationality)
- `dim_location.sql` — from (city, airport)
- `dim_aircraft.sql` — from (aircraft_model)
- `dim_airline.sql` [NEW] — from (airline_name)
- `fct_review.sql` — from (review_id, customer_name, date_submitted)

**Benefit**: Safe for re-runs, production-ready, idempotent transformations.

### 2. Intermediate Layer

**Created**: `models/intermediate/` directory with:

- `int_reviews_cleaned.sql` — Centralized cleaning and normalization logic
- `_int_reviews__models.yml` — Complete documentation

Centralizes all null coalescing, column aliasing, and value normalization in one place, following Kimball best practices of separating concerns across layers.

### 3. Fact Table Consolidation

**Before**: Two separate models (`fct_review.sql` and `fct_review_enriched.sql`)
**After**: Single `fct_review.sql` with all functionality merged

The consolidated fact table now includes:

- All original metrics and foreign keys
- Calculated `average_rating` (mean of 7 sub-ratings)
- Categorical `rating_band` ('bad', 'medium', 'good', 'unknown')
- Data quality filters for referential integrity

Deleted: `fct_review_enriched.sql` (no longer needed)

### 4. New Airline Dimension

**Created**: `dim_airline.sql`

- Grain: one row per unique airline
- Surrogate key using `dbt_utils.generate_surrogate_key()`
- Denormalized into `fct_review` via `airline_id` foreign key
- Follows all Kimball conformed dimension patterns

### 5. SQL Linting Compliance

All models now follow the project's `setup.cfg` rules (Redshift dialect, sqlfluff):

- All keywords lowercase: `select`, `from`, `where`, `join`, etc.
- All functions lowercase: `count()`, `coalesce()`, `round()`, etc.
- All identifiers lowercase: table names, column names, CTEs
- **Trailing commas** required in select lists and CTEs
- 4-space indentation (no tabs)
- **Explicit column aliases** with `as` keyword
- **CTEs over subqueries** for readability
- **Shorthand casting with `::`** (not `cast()`)
- **No positional GROUP BY** — use column names
- **Qualified column references** in all joins (table_alias.column_name)
- **No `select *`** in production models

### 6. Comprehensive YAML Documentation

Updated/Created:

- `marts_schema.yml` — All dimension and fact models with grain definitions
- `_int_reviews__models.yml` — Intermediate layer with complete documentation
- All columns documented with data quality tests
- Tests include: unique, not_null, relationships, accepted_values, range checks
- Contracts enabled for data integrity

## Project Structure

```
models/
├── staging/
│   ├── stg__skytrax_reviews.sql           # 1:1 with source
│   ├── stg__skytrax_schema.yml
│   └── stg__skytrax_source.yml
│
├── intermediate/                          # NEW LAYER
│   ├── int_reviews_cleaned.sql            # Centralized cleaning
│   └── _int_reviews__models.yml           # Documentation
│
└── marts/
    ├── fct_review.sql                     # Merged enriched facts
    ├── dim_customer.sql                   # Customer dimension
    ├── dim_airline.sql                    # Airline dimension [NEW]
    ├── dim_location.sql                   # Location dimension
    ├── dim_aircraft.sql                   # Aircraft dimension
    ├── dim_date.sql                       # Date dimension
    └── marts_schema.yml                   # Complete documentation
```

## Dimensional Model

### Star Schema

```
                            fct_review
                                |
                ┌───────────────┼───────────────┐
                |               |               |
          dim_customer     dim_airline     dim_location (origin)
          dim_location (dest)  dim_location (transit)  dim_aircraft  dim_date (submitted, flown)
```

### Grains

- **fct_review**: One row per review submission
- **dim_customer**: One row per (customer_name, nationality)
- **dim_airline**: One row per unique airline
- **dim_location**: One row per (city, airport)
- **dim_aircraft**: One row per unique aircraft model
- **dim_date**: One row per calendar date

## Preserved Features

All original functionality preserved:

- ✓ `generate_dates_dimension()` macro — untouched
- ✓ `generate_schema_name()` macro — untouched
- ✓ `dbt_utils` package integration
- ✓ `one_time_run` tag on `dim_date`
- ✓ Redshift/Snowflake SQL compatibility
- ✓ All original tests — plus new ones

## Data Quality

Comprehensive testing across all models:

- **Primary keys**: unique + not_null tests
- **Foreign keys**: relationships tests to dimension primary keys
- **Categorical fields**: accepted_values tests
- **Numeric fields**: range checks (dbt_expectations)
- **Grain validation**: grain documented in model descriptions

## Files Changed

### Created

- `models/intermediate/int_reviews_cleaned.sql`
- `models/intermediate/_int_reviews__models.yml`
- `models/marts/dim_airline.sql`
- Agent memory files (see `.claude/agent-memory/dbt-kimball-modeler/`)

### Modified

- `models/staging/stg__skytrax_reviews.sql` — minor linting
- `models/marts/dim_customer.sql` — surrogate keys, linting
- `models/marts/dim_location.sql` — surrogate keys, linting
- `models/marts/dim_aircraft.sql` — surrogate keys, linting
- `models/marts/fct_review.sql` — merged enriched, surrogate keys, linting
- `models/marts/marts_schema.yml` — comprehensive rewrite

### Deleted

- `models/marts/fct_review_enriched.sql` — functionality merged

## Next Steps

1. **Validate syntax**

   ```bash
   dbt parse
   ```

2. **Run tests**

   ```bash
   dbt test
   ```

3. **Build entire project**

   ```bash
   dbt build
   ```

4. **Generate documentation**

   ```bash
   dbt docs generate
   dbt docs serve
   ```

5. **(Optional) Verify SQL linting**

   ```bash
   sqlfluff lint models/
   ```

## Additional Resources

See `.claude/agent-memory/dbt-kimball-modeler/` for:

- `PROJECT_STATE.md` — Detailed implementation summary
- `LINTING_RULES.md` — SQL style guide reference
- `MEMORY.md` — Index of memory files

These resources are designed to maintain consistency and context for future work on this project.
