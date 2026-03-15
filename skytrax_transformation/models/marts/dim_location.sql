{{ config(
    materialized='table',
) }}

-- dim_location.sql
-- Location dimension table combining origin, destination, and transit airports
-- Grain: one row per unique (city, airport) combination
-- Surrogate key: generated using dbt_utils for deterministic, idempotent key generation

with reviews as (

    select
        *,
    from {{ ref('int_reviews_cleaned') }}

),

all_locations as (

    select
        origin_city as city,
        origin_airport as airport,
    from reviews

    union

    select
        destination_city as city,
        destination_airport as airport,
    from reviews

    union

    select
        transit_city as city,
        transit_airport as airport,
    from reviews

),

distinct_locations as (

    select
        distinct
        city,
        airport,
    from all_locations

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['city', 'airport']) }} as location_id,
        city,
        airport,
    from distinct_locations

)

select
    *,
from final
