{{ config(severity='warn') }}

-- Spirit Airlines operates an all-Airbus (A320-family) fleet. Reviewer free-text
-- aircraft fields can invent impossible types (Boeing 747, Embraer, etc.); this
-- warn-severity singular test quarantines Spirit + non-Airbus/non-Unknown
-- manufacturer mappings so they surface in CI without failing the build.
-- Root cause is usually free-text noise, not a dim join bug — inspect rows
-- before treating failures as a transform defect.

select
    f.review_id,
    f.review_key,
    a.airline_name,
    ac.aircraft_model,
    ac.aircraft_manufacturer,
from {{ ref('fct_review') }} as f
inner join {{ ref('dim_airline') }} as a
    on f.airline_id = a.airline_id
inner join {{ ref('dim_aircraft') }} as ac
    on f.aircraft_id = ac.aircraft_id
where lower(a.airline_name) like '%spirit%'
    and coalesce(ac.aircraft_manufacturer, 'Unknown') not in ('Airbus', 'Unknown')
