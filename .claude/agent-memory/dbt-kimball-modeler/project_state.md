---
name: Skytrax Reviews Transformation - Kimball Redesign Complete
description: Completed comprehensive Kimball best-practice redesign of dbt project
type: project
---

## Summary

Successfully completed a Kimball dimensional modeling redesign of the Skytrax reviews transformation project.

## Key Changes Implemented

### 1. Intermediate Layer Created

- Added `models/intermediate/` directory
- Created `int_reviews_cleaned.sql` with centralized cleaning logic
  - Handles null coalescing (all nulls → 'unknown')
  - Normalizes column names (e.g., verify → is_verified)
  - Serves as a single source of truth for business logic

### 2. Surrogate Keys Standardized (CRITICAL)

- Replaced all `row_number() over (...)` with `dbt_utils.generate_surrogate_key()`
- Ensures **deterministic, idempotent key generation** across all dimensions:
  - `dim_customer`: keys from (customer_name, nationality)
  - `dim_location`: keys from (city, airport)
  - `dim_aircraft`: keys from (aircraft_model)
  - `dim_airline`: keys from (airline_name) **[NEW]**
  - `fct_review`: keys from (review_id, customer_name, date_submitted)

### 3. Fact Table Consolidation

- Merged `fct_review.sql` and `fct_review_enriched.sql` into single `fct_review.sql`
- Now includes:
  - All original metrics and foreign keys
  - Calculated `average_rating` (mean of 7 sub-rating fields)
  - Categorical `rating_band` ('bad', 'medium', 'good', 'unknown')
  - Data quality filters ensuring referential integrity
- Deleted `fct_review_enriched.sql` (functionality now in main fact table)

### 4. New Airline Dimension

- Created `dim_airline.sql` with surrogate key
- Grain: one row per unique airline
- Denormalized into `fct_review` via `airline_id` foreign key

### 5. SQL Linting Compliance

All models now follow project's `setup.cfg` rules:

- **Lowercase keywords** (select, from, where, join, etc.)
- **Trailing commas** in select lists and CTEs
- **4-space indentation** (not tabs)
- **Explicit column aliases** with `as` keyword
- **CTEs over subqueries** for readability
- **Casting via `::`** (not `cast()`) per sqlfluff preference
- **No `select *`** except in ephemeral intermediate CTEs
- **Qualified column references** in all joins
- **No positional GROUP BY** (use column names)
- **Boolean columns** prefix with `is_` / `has_`
- **Timestamps** suffix with `_at`

### 6. YAML Schema Documentation Updated

- Comprehensive `marts_schema.yml` with grain documentation for all models
- Added new `_int_reviews__models.yml` for intermediate layer
- All models include:
  - Clear grain definitions in descriptions
  - Column-level documentation
  - Data quality tests (unique, not_null, relationships, accepted_values, range checks)
  - Datatypes metadata
  - Contracts enabled for data integrity

## Project Structure

```
models/
├── staging/
│   ├── stg__skytrax_reviews.sql          (view, 1:1 with source)
│   ├── stg__skytrax_schema.yml
│   └── stg__skytrax_source.yml
├── intermediate/
│   ├── int_reviews_cleaned.sql           (view, centralized cleaning)
│   └── _int_reviews__models.yml          (documentation)
└── marts/
    ├── fct_review.sql                    (table, merged enriched fact)
    ├── dim_customer.sql                  (table, customer dimension)
    ├── dim_airline.sql                   (table, airline dimension) [NEW]
    ├── dim_location.sql                  (table, location dimension)
    ├── dim_aircraft.sql                  (table, aircraft dimension)
    ├── dim_date.sql                      (view, date dimension w/ macro)
    └── marts_schema.yml                  (comprehensive documentation)
```

## Dimensional Model Summary

### Grains

- **fct_review**: one row per review submission
- **dim_customer**: one row per (customer_name, nationality) combination
- **dim_airline**: one row per unique airline
- **dim_location**: one row per (city, airport) combination
- **dim_aircraft**: one row per unique aircraft model
- **dim_date**: one row per calendar date (2015-01-01 onwards)

### Conformed Dimensions

All dimensions are reused across the single fact table, ensuring consistency in:

- Customer attributes (name, nationality, flight count)
- Location attributes (city, airport)
- Aircraft attributes (model, manufacturer, capacity)
- Airline attributes (name)
- Date attributes (calendar, financial period attributes)

### Surrogate Keys

All using `dbt_utils.generate_surrogate_key()` for idempotency:

- SHA256 hash-based, deterministic
- Can safely re-run transformations
- Safe for incremental loads

## Preserved Features

- `dim_date` macro: `generate_dates_dimension()` (untouched)
- Schema name macro: `generate_schema_name()` (untouched)
- `dbt_utils` package integration
- `one_time_run` tag on `dim_date`
- Redshift/Snowflake SQL compatibility
- All original data quality tests + new ones

## Linting Compliance

- Configured per `/Users/minh.pham/personal/project/skytrax_reviews_transformation/setup.cfg`
- Dialect: Redshift (Snowflake target)
- Max line length: 140 characters
- Indent: 4 spaces
- Trailing commas: required
- Keyword capitalization: lowercase
- Casting style: shorthand (`::`)
