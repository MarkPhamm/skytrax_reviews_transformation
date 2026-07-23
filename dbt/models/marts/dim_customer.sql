{{ config(
    materialized='table',
    post_hook="alter table {{ this }} modify column customer_name set masking policy {{ target.database }}.marts.pii_hash_mask",
) }}

-- dim_customer.sql
-- Customer dimension table
-- Grain: one row per unique (customer_name, nationality) combination
-- Surrogate key: generated using dbt_utils for deterministic, idempotent key generation

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
