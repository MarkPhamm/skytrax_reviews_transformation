# Skytrax Star Schema - Visual Guide

## CURRENT STAR SCHEMA (as-is)

```
                         dim_date (2 roles)
                        /        \
                       /          \
        date_submitted_id      date_flown_id
                   |               |
                   |               |
   ┌──────────────────────────────────────────┐
   │         fct_review                        │
   │  (1 row per airline review)               │
   ├──────────────────────────────────────────┤
   │ PK: review_id                             │
   │ FK: customer_id ──────────> dim_customer  │
   │ FK: date_submitted_id ────> dim_date      │
   │ FK: date_flown_id ────────> dim_date      │
   │ FK: origin_location_id ───> dim_location  │
   │ FK: destination_location_id > dim_location│
   │ FK: transit_location_id ──> dim_location  │
   │ FK: aircraft_id ──────────> dim_aircraft  │
   │                                            │
   │ Degenerate Dims:                          │
   │ - airline_name (DENORMALIZED TEXT) 🔴    │
   │ - seat_type                               │
   │ - type_of_traveller                       │
   │ - verified                                │
   │ - recommended                             │
   │                                            │
   │ Measures:                                 │
   │ - seat_comfort                            │
   │ - cabin_staff_service                     │
   │ - food_and_beverages                      │
   │ - inflight_entertainment                  │
   │ - ground_service                          │
   │ - wifi_and_connectivity                   │
   │ - value_for_money                         │
   │                                            │
   │ Audit Timestamps:                         │
   │ - el_updated_at (pipeline)                │
   │ - t_updated_at (dbt)                      │
   └──────────────────────────────────────────┘
        |              |         |         |
        |              |         |         |
   dim_customer   dim_location  dim_aircraft
   (PK: surrogate  (PK: surrogate (PK: surrogate
    row_number())   row_number())  row_number())


ROLE-PLAYING DIMENSIONS (✓ Correct, but undocumented):
  - dim_date serves as both date_submitted and date_flown
  - dim_location serves as origin, destination, AND transit
  - This is a proper Kimball pattern; no separate tables needed


OPTIONAL ENRICHMENT LAYER:
  fct_review_enriched (duplicates fct_review + adds):
    - average_rating (calculated from 7 sub-ratings)
    - rating_band (categorized from average_rating)
```

---

## ISSUES IN CURRENT DESIGN

### Issue 1: NON-DETERMINISTIC SURROGATE KEYS 🔴 CRITICAL

**Current Code**:

```sql
row_number() over (order by customer_name, nationality) as customer_id
```

**Problem**:

```
Run 1: Input = [(Alice, USA), (Alice, USA), (Bob, Canada)]
       Output: customer_id = [1, 1, 2]  ✓ Correct

Run 2: Same input, but order changes in stg model
       If rows come in different order:
       Output: customer_id = [2, 2, 1]  ✗ WRONG!

       Now fct_review.customer_id=1 doesn't join to dim_customer.customer_id=1
       Silent failure in BI tools!
```

**Root Cause**: `row_number()` depends on row execution order, not data content.

**Impact on BI**:

```
BI Query: SELECT * FROM fct_review WHERE customer_id = 1

Before re-run: Returns Alice's reviews
After re-run: Returns Bob's reviews (same customer_id, different person!)
```

---

### Issue 2: Missing `dim_airline` 🟠 MAJOR

**Current State**:

```
fct_review.airline = "British Airways"   (text, denormalized)
```

**Problem**:

- Can't add airline attributes (country, alliance, seat configs)
- Text storage is wasteful (repeated "British Airways" thousands of times)
- Can't enforce airline reference integrity
- BI users can't filter by airline properties

**Recommended**:

```
fct_review.airline_id (FK) ──────────> dim_airline
                                       ├─ airline_id (PK)
                                       ├─ airline_name
                                       ├─ airline_country
                                       ├─ alliance (Star, OneWorld, SkyTeam, etc.)
                                       └─ is_low_cost (T/F)
```

---

### Issue 3: Null Location Handling 🟠 MAJOR

**Current State**:

```
Direct flight (no transit):
  transit_city = NULL
  transit_airport = NULL

Gets coalesced to:
  transit_city = 'Unknown'
  transit_airport = 'Unknown'

Creates location record:
  location_id = 999, city = 'Unknown', airport = 'Unknown'

In fct_review:
  transit_location_id = 999
```

**Problem**:

```
SELECT * FROM dim_location WHERE city = 'Unknown'
  → Returns 1 row
  → But might be mixing "no transit" + "missing data" + "genuine unknowns"
  → Complicates analysis
```

**Recommended**:

```
Option A: Keep transit_location_id nullable
  - Direct flights have NULL
  - BI tools easily filter: WHERE transit_location_id IS NULL

Option B: Create explicit "No Transit" location (location_id = 0)
  - More explicit, but adds a dimension row
  - Easier for some BI tools that struggle with NULLs
```

---

### Issue 4: Weak Customer Natural Key 🟠 MAJOR

**Current Key**: (customer_name, nationality)

**Problem**:

```
Two distinct people:
  1. John Smith from USA
  2. Another John Smith from USA

dim_customer sees both as SAME CUSTOMER:
  customer_id = 42, customer_name = 'John Smith', nationality = 'USA'

Analysis result: John Smith from USA has 2,000 reviews
  But they're from 2 different people!
```

**Why This Matters**:

```
Analyst Query: "Which customers have 100+ reviews?"
  → Includes "John Smith USA" with 2,000 (actually 2 people)

Loyalty Analysis: "Calculate repeat customer rate"
  → Inflated, because multiple people counted as one
```

**Fix**:

- Add caveat in YAML: `meta: {uniqueness: "name+nationality not globally unique"}`
- Consider adding pseudo-ID if source system doesn't have one
- Document assumption in model description

---

## RECOMMENDED REDESIGN (Future State)

### Layer 1: STAGING (Pure Passthrough)

```
stg__skytrax_reviews
├─ review_id (cast to int)
├─ customer_name (cast to string)
├─ nationality (cast to string)
├─ date_submitted (cast to date)
├─ date_flown (cast to date)
├─ airline_name (cast to string)
├─ origin_city, origin_airport
├─ destination_city, destination_airport
├─ transit_city, transit_airport
├─ aircraft (cast to string)
├─ [7 rating columns] (cast to numeric)
├─ verified (cast to boolean)
├─ recommended (cast to boolean)
├─ review (cast to string)
└─ [timestamps]

Goal: Type correctness, null-safe, 1:1 with source
```

### Layer 2: INTERMEDIATE (Business Logic)

```
int__distinct_locations (union + dedup)
├─ UNION origin locations
├─ UNION destination locations
├─ UNION transit locations
└─ DISTINCT (city, airport) pairs
   → Input to dim_location

int__customer_aggregates (grouping)
├─ GROUP BY customer_name, nationality
├─ COUNT(*) as review_count
└─ Output: (customer_name, nationality, review_count)
   → Input to dim_customer

int__aircraft_enrichment (dedup)
├─ DISTINCT aircraft_model
├─ [Reference data join, if available]
└─ Output: (aircraft_model, manufacturer, capacity)
   → Input to dim_aircraft

int__airline_base (dedup)
├─ DISTINCT airline_name
└─ Output: (airline_name, [country, alliance, etc.])
   → Input to dim_airline
```

### Layer 3: DIMENSIONS (Surrogate Key Generation)

```
dim_customer
├─ PK: customer_id (deterministic hash from name+nationality)
├─ customer_name
├─ nationality
├─ review_count
└─ Metadata:
     - Valid from: 2015-01-01 (no SCD)
     - Natural key: (customer_name, nationality)
     - Uniqueness: Weak (caveat in doc)

dim_airline (NEW)
├─ PK: airline_id (deterministic hash from airline_name)
├─ airline_name
├─ airline_country (optional)
├─ alliance (optional: Star, OneWorld, SkyTeam, etc.)
└─ is_low_cost (optional: boolean)

dim_location
├─ PK: location_id (deterministic hash from city+airport)
├─ city
├─ airport
└─ Note: No "Unknown" location (explicit nulls if needed)

dim_aircraft
├─ PK: aircraft_id (deterministic hash from aircraft_model)
├─ aircraft_model
├─ aircraft_manufacturer
└─ seat_capacity

dim_date (UNCHANGED)
├─ PK: date_id (calendar date)
├─ [Full temporal attributes]
└─ Note: Used in 2 roles (submitted, flown)
```

### Layer 4: FACTS (Single, Consolidated Table)

```
fct_review (CONSOLIDATED)
├─ PK: review_id (surrogate, deterministic hash)
├─ FKs:
│  ├─ customer_id ────────> dim_customer.customer_id
│  ├─ airline_id ────────> dim_airline.airline_id (NEW)
│  ├─ date_submitted_id ────> dim_date.date_id
│  ├─ date_flown_id ────────> dim_date.date_id
│  ├─ origin_location_id ───> dim_location.location_id
│  ├─ destination_location_id > dim_location.location_id
│  └─ aircraft_id ──────────> dim_aircraft.aircraft_id
├─ Optional FK:
│  └─ transit_location_id ──> dim_location.location_id (NULL for direct flights)
│
├─ Degenerate Dimensions:
│  ├─ seat_type
│  └─ type_of_traveller
│
├─ Measures:
│  ├─ seat_comfort (1-5)
│  ├─ cabin_staff_service (1-5)
│  ├─ food_and_beverages (1-5)
│  ├─ inflight_entertainment (1-5)
│  ├─ ground_service (1-5)
│  ├─ wifi_and_connectivity (1-5)
│  ├─ value_for_money (1-5)
│  ├─ average_rating (calculated, 1-5)
│  ├─ verified (boolean)
│  └─ recommended (boolean)
│
├─ Dimensions:
│  └─ rating_band (bad/medium/good, derived from average_rating)
│
├─ Audit Columns:
│  ├─ review_loaded_at (when EL pipeline loaded it)
│  └─ review_transformed_at (when dbt processed it)
│
└─ Grain: ONE ROW PER AIRLINE REVIEW
   Natural Key: (customer_name, nationality, date_submitted, airline_name, aircraft, origin, destination)
```

---

## ROLE-PLAYING DIMENSION ILLUSTRATION

### dim_date (2 roles)

```
         ┌──────────────────────────────────────┐
         │         dim_date                      │
         ├──────────────────────────────────────┤
         │ PK: date_id = 2015-01-01             │
         │ day_of_week = 1 (Monday)             │
         │ cal_month = 1                        │
         │ cal_year = 2015                      │
         │ is_weekend = FALSE                   │
         └──────────────────────────────────────┘
                    △        △
                   /          \
                  /            \
    date_submitted_id    date_flown_id
           |                   |
           |                   |
     (Review submitted   (Flight actually
      on Jan 1, 2015)     occurred Jan 1)
```

**Why This Is Correct**:

- ONE physical table (dim_date)
- Multiple logical uses (submitted, flown)
- Saves space vs. creating dim_date_submitted and dim_date_flown
- Standard Kimball pattern ✓

---

### dim_location (3 roles)

```
         ┌──────────────────────────────────────┐
         │         dim_location                  │
         ├──────────────────────────────────────┤
         │ PK: location_id = 100                │
         │ city = 'London'                      │
         │ airport = 'LHR'                      │
         └──────────────────────────────────────┘
                    △      △      △
                   /       |       \
                  /        |        \
    origin_location_id     |     transit_location_id
           |               |               |
           |               |               |
         (Flight       (Transfer     (Stopover)
          starts       point)
          here)
```

**Why This Is Correct**:

- ONE physical table (dim_location)
- Reused for 3 different purposes
- Avoids redundant data duplication
- Standard Kimball pattern ✓

---

## MEASURES vs DIMENSIONS vs DEGENERATE DIMENSIONS

### In fct_review

| Column | Type | Role |
|--------|------|------|
| `review_id` | Surrogate Key | PK, grain identifier |
| `customer_id` | Foreign Key | Points to dim_customer |
| `airline_id` | Foreign Key | Points to dim_airline (NEW) |
| `date_submitted_id` | Foreign Key | Role-plays with dim_date |
| `date_flown_id` | Foreign Key | Role-plays with dim_date |
| `origin_location_id` | Foreign Key | Role-plays with dim_location |
| `seat_comfort` | Measure | Rating (1-5) |
| `verified` | Degenerate Dim | Low cardinality (T/F) |
| `seat_type` | Degenerate Dim | Low cardinality (few values) |
| `average_rating` | Calculated Measure | Derived from 7 sub-ratings |

**Rule of Thumb**:

- **Measure**: Numeric, additive (can SUM, AVG), atomic unit of analysis
- **Dimension**: Descriptive context, foreign key pointing elsewhere
- **Degenerate Dimension**: Descriptive, low cardinality, stored in fact (no separate table)
- **Surrogate Key**: Uniquely identifies row in fact/dimension

---

## SUMMARY TABLE: BEFORE vs. AFTER

| Aspect | BEFORE (Current) | AFTER (Recommended) |
|--------|------------------|-------------------|
| **Surrogate Keys** | `row_number()` ❌ | `generate_surrogate_key()` ✅ |
| **Staging Layer** | Minimal ❌ | Full typed passthrough ✅ |
| **Intermediate Layer** | None ❌ | 4+ int_ models ✅ |
| **dim_airline** | Denormalized text ❌ | Separate dimension ✅ |
| **Fact Tables** | 2 (fct_review + enriched) ❌ | 1 (consolidated) ✅ |
| **Grain Documented** | Implicit ❌ | Explicit comment ✅ |
| **Null Locations** | Coalesced to 'Unknown' ⚠️ | Truly nullable ✅ |
| **SQL Style** | Mixed case, implicit aliases ⚠️ | Consistent, explicit ✅ |
| **Idempotent** | No (non-deterministic keys) ❌ | Yes (deterministic) ✅ |
| **Role-Playing Dims** | Correct but undocumented ⚠️ | Correct + documented ✅ |

---

**Diagram created**: 2026-03-14
**Ready for**: Stakeholder review, engineering kickoff, Phase 1 planning
