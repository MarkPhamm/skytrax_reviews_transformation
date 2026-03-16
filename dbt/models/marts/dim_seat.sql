{{ config(
    materialized='table',
) }}

-- dim_seat.sql
-- Seat dimension table
-- Grain: one row per unique (seat_type, type_of_traveller) combination
-- Surrogate key: generated using dbt_utils for deterministic, idempotent key generation

with reviews as (

    select
        *,
    from {{ ref('int_reviews_cleaned') }}

),

distinct_seats as (

    select distinct
        coalesce(seat_type, 'unknown') as seat_type,
        coalesce(type_of_traveller, 'unknown') as type_of_traveller,
    from reviews

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['seat_type', 'type_of_traveller']) }} as seat_id,
        seat_type,
        type_of_traveller,
    from distinct_seats

)

select
    *,
from final
