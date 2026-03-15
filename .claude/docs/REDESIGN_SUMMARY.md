# Skytrax Reviews Transformation - Kimball Star Schema Redesign Summary

## Current vs. Recommended Architecture

### CURRENT STRUCTURE

```
staging/
  └─ stg__skytrax_reviews.sql (direct passthrough, minimal transformation)
       ↓ (used by all 6 mart models)
marts/
  ├─ dim_customer (row_number() surrogate key) 🔴
  ├─ dim_aircraft (row_number() surrogate key) 🔴
  ├─ dim_location (row_number() surrogate key) 🔴
  ├─ dim_date (utility dimension, generated)
  ├─ fct_review (fact table, 1 row per review)
  └─ fct_review_enriched (duplicate fact table)
```

### RECOMMENDED STRUCTURE

```
staging/
  └─ stg__skytrax_reviews.sql (pure passthrough with type casting)
       ↓
intermediate/
  ├─ int__distinct_locations.sql (union + dedup)
  ├─ int__customer_aggregates.sql (grouping + flight counts)
  ├─ int__aircraft_enrichment.sql (reference data lookup)
  └─ int__airline_base.sql (airline lookup/dedup)
       ↓
marts/
  ├─ dim_airline.sql (NEW) ✅
  ├─ dim_aircraft.sql (surrogate key from hash) ✅
  ├─ dim_customer.sql (surrogate key from hash) ✅
  ├─ dim_location.sql (surrogate key from hash) ✅
  ├─ dim_date.sql (unchanged)
  └─ fct_review.sql (consolidated, 1 row per review) ✅
```

---

## 10 KEY ISSUES FOUND

| # | Issue | Severity | Impact | Quick Fix? |
|---|-------|----------|--------|-----------|
| 1 | Non-deterministic surrogate keys (`row_number()`) | 🔴 CRITICAL | Breaks idempotency, BI joins fail on re-runs | Phase 1 |
| 2 | Missing intermediate layer | 🔴 CRITICAL | Business logic scattered, hard to test/reuse | Phase 1 |
| 3 | No staging architecture | 🔴 CRITICAL | Tight coupling, violates 1:1 staging pattern | Phase 1 |
| 4 | Fact table grain undefined | 🟠 MAJOR | Ambiguous structure, filtering in fact table | Phase 2 |
| 5 | Missing `dim_airline` dimension | 🟠 MAJOR | Denormalized text in fact table, can't add attributes | Phase 2 |
| 6 | Two fact tables (`fct_review` + `fct_review_enriched`) | 🟠 MAJOR | Maintenance burden, redundancy | Phase 2 |
| 7 | Null location handling (Unknown locations) | 🟠 MAJOR | Bloats dimension, complicates transit analysis | Phase 2 |
| 8 | Weak customer natural key | 🟠 MAJOR | Name + nationality not unique, misleading analysis | Design Doc |
| 9 | SQL style violations | 🟡 MINOR | No trailing commas, implicit aliases, case issues | Quick Win |
| 10 | Missing role-playing dimension docs | 🟡 MINOR | Unclear that date & location are reused | Quick Win |

---

## QUICK WINS (30 minutes)

✅ **Low effort, immediate payoff:**

1. **Add grain comments** (5 min)

   ```sql
   -- Grain: One row per unique airline review
   -- Natural key: (customer_name, nationality, date_submitted, airline, aircraft, origin, destination)
   ```

2. **Fix SQL casing** (2 min)
   - `UNION` → `union` in dim_location.sql

3. **Add explicit aliases** (5 min)
   - All `from review` → `from {{ ref("stg__skytrax_reviews") }} as review`

4. **Replace group by position** (2 min)
   - `group by 1,2` → `group by customer_name, coalesce(nationality, 'Unknown')`

5. **Add trailing commas** (5 min)
   - All SELECT lists

6. **Document role-playing dims** (5 min)
   - Add to marts_schema.yml explaining dim_date and dim_location reuse

---

## PHASE 1: CRITICAL FIXES (1-2 weeks)

**Goal**: Fix foundation before scaling

### 1.1 Implement Deterministic Surrogate Keys

**All dimension files** (dim_aircraft, dim_customer, dim_location):

```sql
-- OLD
row_number() over (order by aircraft_model) as aircraft_id

-- NEW
cast(
    {{ dbt_utils.generate_surrogate_key(['aircraft_model']) }}
    as int
) as aircraft_id
```

**Why**: row_number() breaks idempotency; identical input can produce different keys on re-run.

### 1.2 Create Intermediate Layer

**New files** (`models/intermediate/`):

- `int__distinct_locations.sql` - Union + dedup origin/dest/transit
- `int__customer_aggregates.sql` - Group by customer, count flights
- `int__aircraft_enrichment.sql` - Join aircraft to reference data (if available)

**Why**: Separates "what is a dimension" from "how do I derive it"; allows reuse, easier testing.

### 1.3 Refactor Dimensions

**All dim files** now reference intermediate models:

```sql
-- OLD
with review as (
    select * from {{ ref("stg__skytrax_reviews") }}
)

-- NEW
with customer_base as (
    select * from {{ ref("int__customer_aggregates") }}
)
```

### 1.4 Document Grain Explicitly

**fct_review.sql**:

```sql
{{
  config(
    meta={
      grain: "one row per unique airline review",
      natural_key: ["customer_name", "nationality", "date_submitted", "airline"],
    }
  )
}}

with source_data as (
    select * from {{ ref("stg__skytrax_reviews") }}
),
...
```

---

## PHASE 2: MAJOR IMPROVEMENTS (2-3 weeks)

**Goal**: Fix structural issues and improve maintainability

### 2.1 Create `dim_airline` Dimension

**New file** (`models/marts/dim_airline.sql`):

```sql
with distinct_airlines as (
    select distinct coalesce(airline_name, 'Unknown') as airline_name
    from {{ ref("stg__skytrax_reviews") }}
),

final as (
    select
        cast(
            {{ dbt_utils.generate_surrogate_key(['airline_name']) }}
            as int
        ) as airline_id,
        airline_name,
        -- Add attributes here: airline_country, is_low_cost, fleet_size, etc.
    from distinct_airlines
)

select * from final
```

**Update fct_review**:

- Replace `airline` column with `airline_id` foreign key
- Update relationship test in YAML

### 2.2 Consolidate Fact Tables

**Decision**: Keep `fct_review`, delete `fct_review_enriched`

**Add calculated columns directly**:

```sql
-- In fct_review final select:
round(
    (coalesce(seat_comfort, 0) + ... + coalesce(value_for_money, 0))
    / nullif(
        (seat_comfort is not null)::int + ... + (value_for_money is not null)::int
    , 0)
, 2) as average_rating,

case
    when average_rating is null then 'Unknown'
    when average_rating < 2 then 'bad'
    when average_rating < 4 then 'medium'
    else 'good'
end as rating_band,
```

### 2.3 Fix Null Location Handling

**Option A** (recommended): Make transit truly nullable

```sql
-- In fct_review
left join {{ ref('dim_location') }} lo_transit
    on case
        when wd.transit_city = 'Unknown' then null
        else lo_transit.location_id
    end
```

**Option B**: Create explicit "No Transit" location

```sql
-- In dim_location, prepend:
select -1 as location_id, '[No Transit]' as city, '[No Transit]' as airport
union all
select 0 as location_id, '[Unknown]' as city, '[Unknown]' as airport
union all
-- rest of locations
```

### 2.4 Rename Timestamp Columns

```sql
-- Old → New
el_updated_at → review_loaded_at     (when EL pipeline processed it)
t_updated_at → review_transformed_at (when dbt processed it)
```

**Why**: Clearer semantics; distinguishes event timestamps (via dim_date FK) from audit timestamps.

### 2.5 Fix `dim_customer` Documentation

```yaml
- name: dim_customer
  description: |
    Customer dimension derived from reviews.

    WARNING: Customer identification is weak. This dimension uses (customer_name, nationality)
    as a natural key, which is NOT guaranteed to be globally unique. Multiple distinct
    individuals may share the same name and nationality. Consider this limitation when
    analyzing customer repeat behavior or loyalty metrics.
  meta:
    natural_key: ["customer_name", "nationality"]
    uniqueness_caveat: "Name + nationality not globally unique"
```

---

## PHASE 3: OPTIMIZATION (1-2 weeks, optional)

**Goal**: Prepare for production scale and analytics velocity

### 3.1 Implement Incremental Fact Table

```yaml
models:
  - name: fct_review
    config:
      materialized: incremental
      unique_key: review_id
      on_schema_change: sync_all_columns
      incremental_strategy: merge
```

**SQL**:

```sql
{% if execute and execute_macros_namespace.execute_macros %}
    {% if execute %}
        {% set max_updated_at = run_query(
            "select max(review_loaded_at) from " ~ this,
            fetch_result="max_updated_at"
        ) %}
    {% endif %}
{% endif %}

where el_updated_at > (
    select coalesce(max(review_loaded_at), '1900-01-01')
    from {{ this }}
)
```

### 3.2 Add Comprehensive Data Quality Tests

**New file** (`tests/assert_*`):

```sql
-- tests/assert_fct_review_grain_uniqueness.sql
select review_id, count(*)
from {{ ref('fct_review') }}
group by review_id
having count(*) > 1
-- Should return 0 rows

-- tests/assert_fct_review_no_orphaned_fks.sql
select *
from {{ ref('fct_review') }}
where customer_id not in (select customer_id from {{ ref('dim_customer') }})
   or aircraft_id not in (select aircraft_id from {{ ref('dim_aircraft') }})
   or airline_id not in (select airline_id from {{ ref('dim_airline') }})
-- Should return 0 rows
```

### 3.3 SCD Type 2 for Aircraft (optional)

If aircraft attributes (seat capacity) change in source:

```sql
-- Add columns to dim_aircraft
valid_from_date, valid_to_date, is_current

-- Implement logic to track attribute changes over time
```

---

## FILE CHECKLIST

### CRITICAL CHANGES (must do)

- [ ] Replace `row_number()` with `dbt_utils.generate_surrogate_key()` in all dims
- [ ] Create `models/intermediate/` directory with 3+ models
- [ ] Add grain comments to all fact tables
- [ ] Refactor dims to use intermediate models as sources

### MAJOR CHANGES (should do)

- [ ] Create `dim_airline.sql`
- [ ] Move airline_name from fct_review to FK
- [ ] Consolidate fct_review + fct_review_enriched
- [ ] Fix null location handling (transit)
- [ ] Update all YAML relationship tests

### QUALITY CHANGES (nice to have)

- [ ] Add trailing commas to all SELECT
- [ ] Fix SQL casing (UNION → union)
- [ ] Add explicit aliases (as keyword)
- [ ] Replace `group by 1,2` with explicit columns
- [ ] Add role-playing dimension meta docs

---

## SUCCESS CRITERIA

✅ **After Phase 1**:

- All surrogate keys are deterministic (same input → same key)
- Staging + intermediate + marts layering is clear
- Grain is explicitly documented
- All tests pass on re-runs (idempotent)

✅ **After Phase 2**:

- Schema is normalized (no denormalized airline text)
- Single fact table (no duplicates)
- NULL handling is explicit and documented
- YAML documentation is comprehensive

✅ **After Phase 3** (optional):

- Incremental fact table loads work correctly
- Data quality tests catch schema/domain issues
- Dimension history is tracked (if needed)

---

## ESTIMATED EFFORT

| Phase | Task | Duration |
|-------|------|----------|
| 0 | Quick wins (casing, comments, aliases) | 30 min |
| 1 | Critical fixes (keys, layers, grain) | 1 week |
| 2 | Major improvements (airline, consolidation, nulls) | 2 weeks |
| 3 | Optimization (incremental, tests, SCD) | 1 week |
| **Total** | | **4-5 weeks** |

---

## REFERENCES

- **Kimball Dimensional Modeling**: Ralph Kimball, Joy Mundy. *The Data Warehouse Toolkit*, 3rd ed.
- **dbt Best Practices**: <https://docs.getdbt.com/guides/best-practices>
- **dbt Style Guide**: <https://docs.getdbt.com/guides/style-guide>
- **Snowflake SQL**: <https://docs.snowflake.com/>

---

## QUESTIONS FOR STAKEHOLDERS

1. **Customer Uniqueness**: How are customers actually identified in the source system? Do we have account IDs, emails, or just names?
2. **Airline Attributes**: Do we need to track airline properties (country, alliance, fleet size)? Should dimensions be SCD Type 2?
3. **Fact Table Scope**: Are there other fact tables planned (e.g., flights, ratings aggregated by date/airline)?
4. **Incremental Loading**: Is the source system append-only (ideal for incremental), or do reviews get updated/deleted?
5. **BI Tool**: Which tool consumes this (Tableau, Looker, Power BI)? Any special constraints on model structure?

---

**Status**: Ready for Phase 1 implementation

**Next Step**: Review findings with stakeholders, prioritize phase order, assign ownership
