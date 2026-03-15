{{ config(
    materialized='table',
) }}

-- dim_airline.sql
-- Airline dimension table
-- Grain: one row per unique airline
-- Surrogate key: generated using dbt_utils for deterministic, idempotent key generation

with reviews as (

    select
        *,
    from {{ ref('int_reviews_cleaned') }}

),

distinct_airlines as (

    select
        distinct airline_name,
    from reviews

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['airline_name']) }} as airline_id,
        airline_name,
    from distinct_airlines

)

select
    *,
from final
