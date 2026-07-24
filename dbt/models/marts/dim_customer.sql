{{ config(
    materialized='table',
    post_hook="{{ apply_pii_mask(['customer_name', 'nationality']) }}",
) }}

-- dim_customer.sql
-- Customer dimension table
-- Grain: one row per unique (customer_name, nationality) combination
-- Surrogate key: generated using dbt_utils for deterministic, idempotent key generation
-- Governance: customer_name/nationality are masked post-run via PII_HASH_MASK
-- (terraform/snowflake/masking_policies.tf) -- SKYTRAX_ADMIN/SKYTRAX_TRANSFORMER
-- see real values, every other role (e.g. SKYTRAX_ANALYST) sees a SHA-256 hash.

with reviews as (

    select
        *,
    from {{ ref('int_reviews_cleaned') }}

),

customer_agg as (

    select
        customer_name,
        nationality,
        count(*) as number_of_flights,
    from reviews
    group by
        customer_name,
        nationality

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['customer_name', 'nationality']) }} as customer_id,
        customer_name,
        nationality,
        number_of_flights,
    from customer_agg

)

select
    *,
from final
