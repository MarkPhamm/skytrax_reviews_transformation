---
name: SQL Linting Rules for Skytrax Project
description: SQLFluff and dbt style guide rules in effect for this project
type: reference
---

## SQLFluff Configuration

Configuration file: `/Users/minh.pham/personal/project/skytrax_reviews_transformation/setup.cfg`

### Core Settings

- **Dialect**: `redshift` (Snowflake target)
- **Templater**: `dbt`
- **Max line length**: 140 characters
- **Indent unit**: space (4 spaces per tab)
- **Runaway limit**: 10
- **Excluded rules**: RF04 (keyword reservation), ST06 (column ordering)

### Keyword Capitalization

```ini
[sqlfluff:rules:capitalisation.keywords]
capitalisation_policy = lower
```

**Rule**: All SQL keywords must be **lowercase**

```sql
-- GOOD
select col1, col2,
from my_table
where col1 > 0

-- BAD
SELECT col1, col2
FROM my_table
WHERE col1 > 0
```

### Identifier Capitalization

```ini
[sqlfluff:rules:capitalisation.identifiers]
extended_capitalisation_policy = lower
```

**Rule**: Table names, column names, CTE names must be **lowercase**

```sql
-- GOOD
with my_cte as (
    select
        column_name,
        another_column,
    from my_table
)

-- BAD
with MyCTE as (
    select
        ColumnName,
        AnotherColumn
    from MyTable
)
```

### Function Capitalization

```ini
[sqlfluff:rules:capitalisation.functions]
capitalisation_policy = lower
extended_capitalisation_policy = lower
```

**Rule**: All function names must be **lowercase**

```sql
-- GOOD
select
    row_number() over (...) as rn,
    coalesce(col1, 'unknown') as col1,
    round(average, 2) as avg_rounded,

-- BAD
select
    ROW_NUMBER() OVER (...) AS rn,
    COALESCE(col1, 'Unknown') AS col1,
    ROUND(average, 2) AS avg_rounded,
```

### Literal Capitalization

```ini
[sqlfluff:rules:capitalisation.literals]
capitalisation_policy = lower
```

**Rule**: String literals should be **lowercase** (except proper nouns)

```sql
-- GOOD
where status = 'unknown'
where airline_name = 'united'

-- BAD
where status = 'Unknown'
where airline_name = 'UNITED'
```

### Casting Style

```ini
[sqlfluff:rules:convention.casting_style]
preferred_type_casting_style = shorthand
```

**Rule**: Use **`::`** for casting, NOT `cast()`

```sql
-- GOOD
col1::integer,
updated_at::timestamp,
is_active::boolean,

-- BAD
cast(col1 as integer),
cast(updated_at as timestamp),
cast(is_active as boolean),
```

### Trailing Commas

```ini
[sqlfluff:layout:type:comma]
spacing_before = touch
line_position = trailing
```

**Rule**: Trailing commas required in select lists and CTEs

```sql
-- GOOD
select
    col1,
    col2,
    col3,
from my_table

with cte1 as (
    select col1,
),

cte2 as (
    select col2,
)

-- BAD
select
    col1
    , col2
    , col3
from my_table
```

### Column Aliasing

```ini
[sqlfluff:rules:aliasing.column]
aliasing = explicit
```

**Rule**: All columns must have explicit aliases with `as` keyword

```sql
-- GOOD
select
    col1 as column_one,
    col2 as column_two,
    count(*) as row_count,

-- BAD
select
    col1 column_one,
    col2 column_two,
    count(*) row_count,
```

### Table Aliasing

```ini
[sqlfluff:rules:aliasing.table]
aliasing = implicit
```

**Rule**: Table aliases don't need to be the exact table name (can be short)

```sql
-- GOOD
from my_long_table_name as t
from another_table as at
left join dim_customer as dc

-- ACCEPTABLE (implicit aliases)
from my_long_table_name
left join another_table
```

### Expression Aliasing

```ini
[sqlfluff:rules:aliasing.expression]
allow_scalar = False
```

**Rule**: Aggregate functions must have explicit aliases

```sql
-- GOOD
select
    count(*) as record_count,
    sum(amount) as total_amount,
    avg(price) as average_price,

-- BAD
select
    count(*),
    sum(amount),
    avg(price),
```

### Group By / Order By Style

```ini
[sqlfluff:rules:ambiguous.column_references]
group_by_and_order_by_style = consistent
```

**Rule**: No positional GROUP BY or ORDER BY; use column names

```sql
-- GOOD
select
    customer_id,
    count(*) as orders,
from orders
group by
    customer_id
order by
    orders desc

-- BAD
select
    customer_id,
    count(*) as orders,
from orders
group by 1
order by 2 desc
```

## dbt Style Guide Rules

### CTE vs Subqueries

**Rule**: Always use **CTEs over subqueries** for readability

```sql
-- GOOD
with cleaned_data as (
    select col1, col2,
    from raw_table
    where col1 is not null
),

final as (
    select
        cd.*,
        dim.dimension_id,
    from cleaned_data as cd
    left join dim_table as dim using (key)
)

select * from final

-- BAD
select
    raw.col1,
    raw.col2,
    dim.dimension_id,
from (
    select col1, col2
    from raw_table
    where col1 is not null
) as raw
left join dim_table as dim on raw.key = dim.key
```

### Column Naming Conventions

- **Primary keys**: `{table}_id` (e.g., `customer_id`)
- **Surrogate keys**: `{table}_key` (e.g., `review_key`)
- **Foreign keys**: `{dimension}_{table}_id` (e.g., `customer_id`, `airline_id`)
- **Boolean columns**: prefix with `is_` or `has_` (e.g., `is_verified`, `has_attachment`)
- **Timestamps**: suffix with `_at` (e.g., `created_at`, `updated_at`)
- **Dates**: suffix with `_date` (e.g., `birth_date`, `submission_date`)
- **Numeric measures**: context-specific (e.g., `total_amount`, `average_rating`, `seat_count`)

### No SELECT *

**Rule**: Never use `select *` in production models (except ephemeral intermediate CTEs)

```sql
-- ACCEPTABLE (ephemeral intermediate)
with raw_data as (
    select *,
    from source_table
)

-- GOOD
select
    col1,
    col2,
    col3,
from raw_data

-- BAD
select *
from my_table
```

### Qualify All Column References

**Rule**: When joins are present, qualify all columns with table/CTE aliases

```sql
-- GOOD
select
    c.customer_id,
    c.customer_name,
    o.order_id,
    o.order_date,
from customers as c
left join orders as o on c.customer_id = o.customer_id

-- BAD
select
    customer_id,
    customer_name,
    order_id,
    order_date,
from customers
left join orders on customer_id = customer_id
```

### Comment Guidelines

- Use `--` for inline comments
- Place multi-line comments above the relevant code block
- Grain documentation required at model top (fact and dimension tables)

Example:

```sql
-- dim_customer.sql
-- Customer dimension table
-- Grain: one row per unique (customer_name, nationality) combination
```

## Related Resources

- SQLFluff docs: <https://docs.sqlfluff.com/>
- dbt style guide: <https://github.com/dbt-labs/dbt-labs-style-guide>
