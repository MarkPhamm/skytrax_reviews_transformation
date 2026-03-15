{{ config(
    materialized='table',
) }}

-- fct_review.sql
-- Review fact table with enrichments (average ratings and rating bands)
-- Grain: one row per review submission
-- Surrogate key: generated using dbt_utils for deterministic, idempotent key generation
-- All measures and dimensions are foreign keys to conformed dimensions

with base as (

    select
        *,
    from {{ ref('int_reviews_cleaned') }}

),

with_customer as (

    select
        b.*,
        dc.customer_id,
    from base as b
    left join {{ ref('dim_customer') }} as dc
        on b.customer_name = dc.customer_name
        and b.nationality = dc.nationality

),

with_airline as (

    select
        wc.*,
        da.airline_id,
    from with_customer as wc
    left join {{ ref('dim_airline') }} as da
        on wc.airline_name = da.airline_name

),

with_dates as (

    select
        wa.*,
        ds.date_id as date_submitted_id,
        df.date_id as date_flown_id,
    from with_airline as wa
    left join {{ ref('dim_date') }} as ds
        on wa.date_submitted = ds.date_id
    left join {{ ref('dim_date') }} as df
        on wa.date_flown = df.date_id

),

with_locations as (

    select
        wd.*,
        lo_origin.location_id as origin_location_id,
        lo_dest.location_id as destination_location_id,
        lo_transit.location_id as transit_location_id,
    from with_dates as wd
    left join {{ ref('dim_location') }} as lo_origin
        on wd.origin_city = lo_origin.city
        and wd.origin_airport = lo_origin.airport
    left join {{ ref('dim_location') }} as lo_dest
        on wd.destination_city = lo_dest.city
        and wd.destination_airport = lo_dest.airport
    left join {{ ref('dim_location') }} as lo_transit
        on wd.transit_city = lo_transit.city
        and wd.transit_airport = lo_transit.airport

),

with_aircraft as (

    select
        wl.*,
        da.aircraft_id,
    from with_locations as wl
    left join {{ ref('dim_aircraft') }} as da
        on wl.aircraft_model = da.aircraft_model

),

with_ratings as (

    select
        wa.*,
        round(
            (
                coalesce(seat_comfort, 0) +
                coalesce(cabin_staff_service, 0) +
                coalesce(food_and_beverages, 0) +
                coalesce(inflight_entertainment, 0) +
                coalesce(ground_service, 0) +
                coalesce(wifi_and_connectivity, 0) +
                coalesce(value_for_money, 0)
            )
            /
            nullif(
                (seat_comfort is not null)::int +
                (cabin_staff_service is not null)::int +
                (food_and_beverages is not null)::int +
                (inflight_entertainment is not null)::int +
                (ground_service is not null)::int +
                (wifi_and_connectivity is not null)::int +
                (value_for_money is not null)::int,
                0
            ),
            2
        ) as average_rating,
    from with_aircraft as wa

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['review_id', 'customer_name', 'date_submitted']) }} as review_key,
        customer_id,
        airline_id,
        date_submitted_id,
        date_flown_id,
        origin_location_id,
        destination_location_id,
        transit_location_id,
        aircraft_id,
        review_id,
        is_verified,
        seat_type,
        type_of_traveller,
        seat_comfort,
        cabin_staff_service,
        food_and_beverages,
        inflight_entertainment,
        ground_service,
        wifi_and_connectivity,
        value_for_money,
        recommended,
        average_rating,
        case
            when average_rating is null then 'unknown'
            when average_rating < 2 then 'bad'
            when average_rating < 4 then 'medium'
            else 'good'
        end as rating_band,
        review_text,
        updated_at as source_updated_at,
        current_timestamp() as dbt_loaded_at,
    from with_ratings
    where
        -- Remove rows with null foreign keys (failed joins)
        customer_id is not null
        and airline_id is not null
        and date_submitted_id is not null
        and origin_location_id is not null
        and destination_location_id is not null
        and transit_location_id is not null
        and aircraft_id is not null
        -- Remove rows with invalid rating values (must be between 1-5, or allow null)
        and (seat_comfort is null or (seat_comfort >= 1 and seat_comfort <= 5))
        and (cabin_staff_service is null or (cabin_staff_service >= 1 and cabin_staff_service <= 5))
        and (food_and_beverages is null or (food_and_beverages >= 1 and food_and_beverages <= 5))
        and (inflight_entertainment is null or (inflight_entertainment >= 1 and inflight_entertainment <= 5))
        and (ground_service is null or (ground_service >= 1 and ground_service <= 5))
        and (wifi_and_connectivity is null or (wifi_and_connectivity >= 1 and wifi_and_connectivity <= 5))
        and (value_for_money is null or (value_for_money >= 1 and value_for_money <= 5))

)

select
    *,
from final
