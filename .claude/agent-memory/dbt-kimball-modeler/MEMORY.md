# dbt-Kimball Modeler Memory Index

**Project**: Skytrax Reviews Transformation (Airline Reviews Star Schema)

## Core Analysis

- [ANALYSIS.md](./ANALYSIS.md) - Comprehensive Kimball star schema assessment with 10 critical/major issues, redesign recommendations, and phased roadmap for fixes

## Project Context

- **Domain**: Airline review analytics (Skytrax reviews)
- **Fact Table Grain**: One row per review
- **Dimensions**: customer, date (2 roles), location (3 roles), aircraft
- **Source**: SKYTRAX_REVIEWS_DB.RAW.AIRLINE_REVIEWS
- **Warehouse**: Snowflake (inferred from macro syntax)
- **Status**: Structurally sound foundation with significant best-practice violations

## Quick Reference - Top 5 Issues to Fix

1. **Surrogate keys non-deterministic** - Use `dbt_utils.generate_surrogate_key()` instead of `row_number()`
2. **Missing staging/intermediate layers** - Create models/intermediate/ directory
3. **Grain undefined in code** - Add explicit grain comments to fact tables
4. **Missing dim_airline** - Move airline_name from fact table to separate dimension
5. **SQL style violations** - Add trailing commas, explicit aliases, lowercase keywords

## Phased Remediation

- **Phase 1 (Critical)**: Deterministic keys, intermediate layer, explicit grain (1-2 weeks)
- **Phase 2 (Major)**: Fact table consolidation, null handling, SQL linting (2-3 weeks)
- **Phase 3 (Optional)**: Incremental materialization, data quality tests, SCD patterns (1-2 weeks)
