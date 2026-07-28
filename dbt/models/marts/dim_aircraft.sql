{{ config(
    materialized='table',
) }}

-- dim_aircraft.sql
-- Aircraft dimension table
-- Grain: one row per unique aircraft model from reviews
-- Surrogate key: generated using dbt_utils for deterministic, idempotent key generation

with reviews as (

    select
        *,
    from {{ ref('int_reviews_cleaned') }}

),

raw_aircraft as (

    select distinct aircraft_model,
    from reviews

),

mapped as (

    {{ aircraft_family_seed() }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['raw_aircraft.aircraft_model']) }} as aircraft_id,
        raw_aircraft.aircraft_model,
        {{ extract_aircraft_manufacturer('raw_aircraft.aircraft_model') }} as aircraft_manufacturer,
        mapped.capacity as seat_capacity,
    from raw_aircraft
    left join mapped
        on {{ fuzzy_match_aircraft_family('raw_aircraft.aircraft_model', 'mapped.model') }}
    qualify row_number() over (
        partition by raw_aircraft.aircraft_model
        order by length(mapped.model) desc nulls last
    ) = 1

)

select
    *,
from final
