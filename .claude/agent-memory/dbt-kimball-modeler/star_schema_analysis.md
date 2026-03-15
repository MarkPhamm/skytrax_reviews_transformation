---
name: Skytrax Transformation - Star Schema Analysis & Recommendations
description: Complete assessment of current Kimball star schema design vs best practices with remediation roadmap
type: project
---

# Skytrax Reviews Data Warehouse - Kimball Star Schema Analysis

## Executive Summary

The skytrax_reviews_transformation project has a **structurally sound star schema foundation** with a fact table (`fct_review`) and four conformed dimensions. However, there are **significant best-practice violations** in staging architecture, grain clarity, surrogate key design, and modeling patterns that should be addressed.

**Severity Levels**: Critical (design violations), Major (maintenance issues), Minor (style/naming).

---

## 1. CURRENT ARCHITECTURE OVERVIEW

### Project Structure

```
models/
├── staging/
│   ├── stg__skytrax_reviews.sql (1 file)
│   ├── stg__skytrax_schema.yml
│   └── stg__skytrax_source.yml
└── marts/
    ├── dim_aircraft.sql
    ├── dim_customer.sql
    ├── dim_date.sql
    ├── dim_location.sql
    ├── fct_review.sql
    ├── fct_review_enriched.sql
    └── marts_schema.yml
```

### Data Source

- **Source**: SKYTRAX_REVIEWS_DB.RAW.AIRLINE_REVIEWS
- **Raw columns**: review_id, customer_name, nationality, origin_city, origin_airport, destination_city, destination_airport, transit_city, transit_airport, aircraft, rating, comments, date_submitted, date_flown, airline_name, verify, seat_type, type_of_traveller, seat_comfort, cabin_staff_service, food_and_beverages, inflight_entertainment, ground_service, wifi_and_connectivity, value_for_money, recommended, updated_at

### Current Star Schema

**Fact Table**: `fct_review` (grain: one row per airline review)
**Dimensions**: dim_customer, dim_date (2 role-playing instances), dim_location (3 role-playing instances), dim_aircraft

---

## 2. CRITICAL ISSUES - KIMBALL VIOLATIONS

### 2.1 **STAGING ARCHITECTURE COMPLETELY MISSING** [CRITICAL]

**Current State**: Only ONE staging model (`stg__skytrax_reviews`) exists, which is essentially a direct passthrough with minimal transformation.

**Kimball Problem**:

- Staging should be 1:1 with source tables, performing **light normalization only**: type casting, renaming, deduplication, null handling
- Current `stg__skytrax_reviews` is used directly in multiple marts (dim_aircraft, dim_customer, dim_location, fct_review), creating tight coupling
- No intermediate layer for business logic transformations

**Impact**:

- Difficult to reuse transformations across dimensions
- Hard to debug which model owns which business rule
- Violates single responsibility principle
- Difficult to test and maintain

**Recommendation**: Create a proper staging layer with:

- `stg__skytrax_reviews.sql` - Pure source passthrough with type casting, null coalescing, column renaming
- Treat all dimensions as deriving from this single source

---

### 2.2 **MISSING INTERMEDIATE LAYER** [CRITICAL]

**Current State**: Marts directly reference staging models and perform complex transformations inline.

**Kimball Problem**:

- Complex business logic (e.g., location deduplication in `dim_location`, customer grouping in `dim_customer`) lives in dimension models
- No separation between "what is a dimension?" and "how do I calculate it?"

**Recommendation**: Create `models/intermediate/` layer with models like:

- `int__distinct_locations.sql` - Unioning and deduplicating origin, destination, transit locations
- `int__customer_aggregates.sql` - Customer grouping and flight count calculation
- `int__aircraft_enrichment.sql` - Aircraft reference data enrichment

This allows dims to be thin, focused on surrogate key generation and business rules.

---

### 2.3 **SURROGATE KEY GENERATION INCORRECT** [CRITICAL]

**Current Problem in All Dimensions**:

```sql
row_number() over (order by <business_key>) as customer_id
```

**Kimball Violation**:

- `row_number()` is **non-deterministic** across runs if source ordering changes
- A legitimate Kimball dimension should generate stable surrogate keys from business keys
- Current approach violates idempotency: same input may produce different surrogate keys on re-run

**Impact**:

- Fact table foreign key joins may silently fail
- Historical lookups in BI tools become unreliable
- Incremental fact tables cannot correctly join to dimensions

**Recommended Fix**: Use `dbt_utils.generate_surrogate_key()` or explicit hash-based deterministic key:

```sql
cast(
    {{ dbt_utils.generate_surrogate_key(['customer_name', 'nationality']) }}
    as int
) as customer_id
```

Or explicit SQL hash:

```sql
cast(
    abs(
        strtohash(
            concat(coalesce(customer_name, ''), '||', coalesce(nationality, ''))
        )
    ) % 2147483647 as int
) as customer_id
```

---

### 2.4 **GRAIN AMBIGUITY & FACT TABLE FILTERING** [MAJOR]

**Current `fct_review`**:

- Declared grain: "one row per review"
- **BUT** includes WHERE clause filtering out records with null foreign keys (lines 109-124)

**Kimball Violation**:

- Fact tables should explicitly state grain in comments
- Filtering should be done upstream (in intermediate models), not in the fact table
- Current WHERE clause removes data rows, making the table less useful for exploratory analysis

**Impact**:

- Analysts can't distinguish between "no review" and "missing dimension join"
- Difficult to audit data quality
- Grain is implicit, not explicit

**Recommendation**:

```sql
-- Grain: one row per unique airline review
-- Business keys: (customer_name, nationality, date_submitted, airline_name, aircraft, origin_airport, destination_airport)
```

Move NULL-filtering logic to an intermediate model or document it as a design choice.

---

### 2.5 **DEGENERATE DIMENSIONS NOT RECOGNIZED** [MAJOR]

**Current Design**:

- `airline_name`, `seat_type`, `type_of_traveller`, `verified`, `recommended` are fact table attributes
- These are **degenerate dimensions** (low cardinality, not requiring a separate table)

**Kimball Best Practice**:

- Degenerate dimensions belong in fact tables (correct placement)
- **But** should be renamed/documented to reflect this: `degen_seat_type`, or at minimum clearly commented

**Issue**: Current naming doesn't distinguish these from measures or foreign keys, making the grain ambiguous.

**Recommendation**: Document in YAML or add prefix: `seat_type_degen` or add comment in model.

---

### 2.6 **ROLE-PLAYING DIMENSIONS NOT EXPLICIT** [MAJOR]

**Current Design**:

- `dim_date` is used twice (date_submitted, date_flown)
- `dim_location` is used three times (origin, destination, transit)

**Kimball Best Practice**:

- Role-playing dimensions are correct (avoids denormalization)
- **But** the schema should clearly document which roles exist

**Current Issue**: No documentation in YAML explaining that:

- `date_id` from `dim_date` maps to multiple foreign keys
- `location_id` from `dim_location` maps to multiple foreign keys
- BI tools may not understand the relationships

**Recommendation**: Add meta-documentation in `marts_schema.yml`:

```yaml
models:
  - name: dim_date
    meta:
      role_playing_dimensions:
        - date_submitted_id
        - date_flown_id
```

---

### 2.7 **MISSING AIRLINE DIMENSION** [MAJOR]

**Current Design**:

- `airline_name` is stored as denormalized text in the fact table
- No separate `dim_airline` dimension

**Kimball Violation**:

- `airline_name` is a distinct entity with properties (country, alliance, seat configurations, etc.)
- Storing it as text violates normalization and wastes space
- No way to add airline-level attributes (country, alliance, fleet size) without modifying fact table

**Impact**:

- Can't analyze by airline properties
- Difficult to aggregate by airline attribute
- Violates conformed dimension pattern

**Recommendation**: Create `dim_airline.sql` with:

- Surrogate key: `airline_id`
- Business key: `airline_code` or `airline_name`
- Attributes: `airline_name`, `airline_country` (if available from external source), `is_low_cost` (if relevant)

---

### 2.8 **DIMENSION CARDINALITY ISSUES** [MAJOR]

#### `dim_customer` - Weak Natural Key

```sql
-- Current: customer_name + nationality uniquely identify customer
```

**Problem**:

- "John Smith" + "USA" is NOT reliable as a unique customer identifier across the real world
- Multiple distinct people can have the same name/nationality
- No email, ID, or account number to disambiguate

**Impact**:

- Customer analysis is unreliable
- Same person reviews counted as multiple customers

**Recommendation**:

- If source data has no reliable customer ID, add a comment documenting this assumption
- Consider creating a `number_of_reviews` count instead of `number_of_flights` (latter is in source but not reliable without deduplication by customer)
- Add caveat in YAML: `meta: {note: "Customer disambiguation relies on name + nationality; not unique across world"}`

#### `dim_location` - Transit Nulls

```sql
-- Current: dim_location includes rows where transit_city='Unknown', transit_airport='Unknown'
```

**Problem**:

- Unknown locations are created for direct flights (no transit)
- These are placeholder data, not real locations
- Bloats dimension and complicates analysis ("Unknown" location queries)

**Recommendation**:

- Make `transit_location_id` truly nullable in fact table
- Don't create location records for unknown/missing values
- OR create a "No Transit" location explicitly: location_id=0, city='[No Transit]', airport='[No Transit]'

---

### 2.9 **SQL STYLE & LINTING VIOLATIONS** [MINOR - but pervasive]

#### Violations Found

1. **Missing LOWERCASE keywords**:
   - `select`, `from`, `where`, `join`, `on`, `group by` are correctly lowercase ✓
   - But `UNION` is uppercase in `dim_location.sql` (line 11, 18)

2. **No trailing commas** in select statements (all models)
   - Kimball best practice: always use trailing commas for maintainability

3. **Implicit column selection** in CTEs:
   - `dim_customer.sql` line 13: `group by 1,2` (position-based, not explicit)
   - Should be `group by customer_name, coalesce(nationality, 'Unknown')`

4. **`select *` in intermediate CTEs**:
   - `fct_review.sql` lines 4, 8: `select *` from staging is acceptable for passthrough
   - But CTEs like `with_customer`, `with_dates`, `with_locations` all use `select` with specific columns ✓

5. **Implicit aliases in joins**:
   - `dim_location.sql`: `from review` (alias 'review') used without explicit `as` keyword
   - Should be: `from {{ ref("stg__skytrax_reviews") }} as review`

6. **Missing qualifying column references**:
   - Some joins fail to qualify columns when ambiguous, e.g., in `dim_aircraft.sql`:

   ```sql
   on raw_aircraft.aircraft_model = mapped.model -- qualified ✓
   ```

   But in `fct_review.sql`, many columns aren't qualified across joins.

---

### 2.10 **DIMENSION TABLE CONTRACTS & STABILITY** [MINOR]

**Current State**: All fact and dim tables have `config.meta.contracts.enabled: true` in YAML.

**Issue**: No actual contract definition (Snowflake/dbt feature for enforcing schema stability).

**Recommendation**: If using dbt 1.8+, add explicit contracts:

```yaml
models:
  - name: dim_customer
    config:
      contract:
        enforced: true
    columns:
      - name: customer_id
        data_type: integer
```

---

## 3. MISSING MODELS & ARCHITECTURE GAPS

### 3.1 Missing `dim_airline`

Already documented above (Section 2.7).

### 3.2 Missing Intermediate Aggregation Models

**Gap**: No `int_*` models exist to support fact table construction.

**Examples of missing int models**:

- `int__distinct_locations.sql` - Location deduplication logic
- `int__aircraft_enrichment.sql` - Aircraft reference data lookup
- `int__customer_base.sql` - Customer grouping and aggregation

---

### 3.3 Missing Factless Fact Table

**Gap**: If analysts want to analyze "what reviews were submitted for each date/airline combo without text", they'd need to use the full fact table.

**Recommendation**: Consider `fct_review_metrics` (grain: one row per airline per date) or simply document that `fct_review` is the single fact table.

---

### 3.4 Missing Slowly Changing Dimension (SCD) Type 2 Pattern

**Issue**: `dim_customer` and `dim_aircraft` have no historical tracking.

**Example**: If aircraft seat capacity changes in reality, the dimension doesn't track this over time.

**Recommendation**: If historical dimension attributes are important:

- Add `valid_from_date`, `valid_to_date`, `is_current` columns
- Implement SCD Type 2 logic
- Or document that dimensions are assumed to be static/slowly changing with no historical tracking needed

---

## 4. YAML DOCUMENTATION ISSUES

### 4.1 Missing Documentation for Key Concepts

- No grain definition for fact tables (implicit only)
- No conformed dimension documentation
- No explanation of role-playing dimensions
- No primary/foreign key lineage diagram

### 4.2 Inconsistent Test Severity

- Some tests use `severity: warn` (e.g., `customer_name` not_null)
- Some use default (error)
- No documented rationale

### 4.3 Incomplete Source Definition

- Source freshness defined (1 day error, 12 hour warn)
- But no column-level freshness tests
- No data profiling documentation

---

## 5. DESIGN DECISIONS REQUIRING CLARITY

### 5.1 Two Fact Tables (`fct_review` vs `fct_review_enriched`)

**Current**: `fct_review` is the base; `fct_review_enriched` adds calculated columns (average_rating, rating_band).

**Kimball Best Practice**: Usually, you'd have ONE fact table and either:

- Include calculated measures directly in the fact table
- OR create a separate fact-like table with aggregated metrics

**Current Approach**: Having both increases maintenance burden.

**Recommendation**: Consolidate into single `fct_review` with average_rating and rating_band, or explicitly document why two tables are needed.

### 5.2 Timestamp Handling

**Current**: Two timestamp columns in fact table:

- `el_updated_at` - pipeline load timestamp
- `t_updated_at` - transformation load timestamp

**Kimball Issue**: Fact tables should have **event timestamp** (when the review was submitted) plus **load timestamp** for auditing.

**Current columns are misnamed**:

- Should be `review_submitted_at`, `review_flown_at` (event dates)
- Plus `loaded_at` (pipeline audit timestamp)

**Recommendation**: Rename for clarity:

- `review_submitted_at` (already in dim_date, but keep for grain)
- `review_flown_at` (already in dim_date)
- `review_loaded_at` (pipeline audit)

---

## 6. DATA QUALITY & VALIDATION GAPS

### 6.1 Weak Primary Key in `dim_customer`

- No NOT NULL test on the composite business key (customer_name + nationality)
- `customer_name` has `warn_if: ">0"` for nulls (should be stricter)

### 6.2 Missing Business Rule Tests

No tests for:

- Total rating within range (must be average of sub-ratings)
- Recommended boolean must align with average_rating > 2.5 (or per business rule)
- Aircraft model must exist in known list (though aircraft_id null-filtering partially handles this)

### 6.3 Dimension Grain Tests Missing

No explicit test that:

- Each `dim_customer` row is unique by (customer_name, nationality)
- Each `dim_location` row is unique by (city, airport)
- Each `dim_aircraft` row is unique by aircraft_model

---

## 7. PERFORMANCE & SCALABILITY CONCERNS

### 7.1 Missing Incremental Materialization

**Current**: All models are either `view` (staging) or `table` (marts).

**Issue**: As data grows, `fct_review` will become slow to rebuild.

**Recommendation**: Make `fct_review` incremental on `el_updated_at` or `date_submitted`:

```yaml
models:
  - name: fct_review
    config:
      materialized: incremental
      unique_key: review_id
      on_schema_change: sync_all_columns
```

### 7.2 Dimension Rebuilds

- Dimensions currently rebuild fully every run
- With incremental facts, consider incremental dimensions (SCD Type 2)

### 7.3 Missing Indexing Strategy

- No discussion of indexes on surrogate/natural keys
- No mention of clustering or partitioning strategy

---

## 8. RECOMMENDED REDESIGN ROADMAP

### Phase 1: CRITICAL FIXES (Foundation)

**Priority**: Must-do before expanding warehouse

1. **Implement Deterministic Surrogate Keys**
   - Replace `row_number()` with `dbt_utils.generate_surrogate_key()`
   - All dimension models: dim_customer, dim_aircraft, dim_location

2. **Introduce Intermediate Layer**
   - Create `models/intermediate/` directory
   - Move location deduplication to `int__distinct_locations.sql`
   - Move customer grouping to `int__customer_aggregates.sql`

3. **Document Grain Explicitly**
   - Add grain comment to all fact/agg models
   - Update YAML with explicit grain definition

4. **Create `dim_airline` Dimension**
   - Move `airline_name` from denormalized fact column to foreign key
   - Add `airline_id` foreign key to fct_review

### Phase 2: MAJOR IMPROVEMENTS (Quality)

**Priority**: 1-2 sprints to complete

1. **Fix Fact Table Structure**
   - Consolidate `fct_review` and `fct_review_enriched` (choose one)
   - Add `review_id` as explicit surrogate key (not derived from staging)
   - Clarify timestamp columns: review_submitted_at, review_flown_at, loaded_at

2. **Handle Null Locations Properly**
   - Make `transit_location_id` nullable (no "Unknown" location for direct flights)
   - OR create explicit "No Transit" location (location_id=0)

3. **Strengthen SQL Style & Linting**
   - Add trailing commas to all SELECT statements
   - Uppercase UNION → union
   - Explicit aliases on all table references
   - Replace `group by 1,2` with explicit column names

4. **Enhance YAML Documentation**
   - Add grain definition for all fact tables
   - Document role-playing dimensions explicitly
   - Add relationship diagrams in model descriptions
   - Define conformed dimension strategy

### Phase 3: OPTIMIZATION (Scalability)

**Priority**: After Phase 1-2, before production scale

1. **Implement Incremental Materialization**
   - Make `fct_review` incremental on `el_updated_at`
   - Define unique key and on_schema_change strategy

2. **Add Data Quality Tests**
    - Grain tests (uniqueness of primary keys at declared grain)
    - Cross-dimensional consistency tests
    - Business rule tests (e.g., recommended vs average_rating correlation)

3. **SCD Strategy** (if needed)
    - Document whether dimensions need Type 2 tracking
    - If yes, implement slowly changing dimension pattern

---

## 9. RECOMMENDED NEW PROJECT STRUCTURE

```
models/
├── staging/
│   ├── stg__skytrax_reviews.sql         # Pure passthrough with type casting
│   ├── stg__skytrax_schema.yml
│   └── stg__skytrax_source.yml
├── intermediate/
│   ├── int__distinct_locations.sql      # Location deduplication
│   ├── int__customer_aggregates.sql     # Customer grouping
│   ├── int__aircraft_enrichment.sql     # Aircraft reference data
│   └── _int__skytrax__models.yml
└── marts/
    ├── dim_airline.sql                  # NEW: Airline dimension
    ├── dim_aircraft.sql                 # REFACTORED: thin surrogate key gen
    ├── dim_customer.sql                 # REFACTORED: from int_customer_aggregates
    ├── dim_date.sql                     # UNCHANGED: utility dimension
    ├── dim_location.sql                 # REFACTORED: from int_distinct_locations
    ├── fct_review.sql                   # REFACTORED: consolidates enrichment, deterministic keys
    ├── _dim__skytrax__models.yml        # NEW: Separate dim documentation
    └── _fct__skytrax__models.yml        # NEW: Separate fact documentation
```

---

## 10. QUICK WINS (30-minute implementations)

1. **Fix SQL Casing**: `UNION` → `union` in dim_location.sql (1 min)
2. **Add Grain Comments**: Add 2-line grain definition to fct_review, fct_review_enriched (5 min)
3. **Document Role-Playing Dims**: Add meta section to marts_schema.yml (5 min)
4. **Fix Group By**: Replace `group by 1,2` with explicit columns in dim_customer (2 min)
5. **Add Explicit Aliases**: Add `as` to all table references in dim_location (3 min)
6. **Qualify Columns**: Add table aliases to ambiguous column references (5 min)
7. **Add Trailing Commas**: Add trailing commas to all SELECT statements (5 min)

---

## CONCLUSION

The skytrax_reviews_transformation project has a **solid conceptual foundation** with a correct star schema topology (fact + 4 dimensions, role-playing handled correctly). However, it violates Kimball best practices in critical areas:

1. **Surrogate key generation** is non-deterministic (breaks idempotency)
2. **No staging layer** (only passthrough model)
3. **No intermediate layer** (business logic in dimensions)
4. **Grain undefined** (fact table filtering makes grain ambiguous)
5. **Missing airline dimension** (stored as denormalized text)
6. **SQL style** inconsistencies (minor but pervasive)

**Estimated effort to fix**:

- Quick wins: 30 minutes
- Phase 1 (Critical): 1-2 weeks
- Phase 2 (Major): 2-3 weeks
- Phase 3 (Optional/Optimization): 1-2 weeks

**Next Step**: Prioritize Phase 1 critical fixes before scaling fact table or adding new use cases.
