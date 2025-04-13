-- models/fct_review.sql

with source_data as (
    select * 
    from {{ ref("stg_airlinequality__reviews") }}
),

base as (
    select 
        row_number() over (order by date_submitted, customer_name) as review_id,
        customer_name,
        nationality,
        date_submitted,
        date_flown,
        coalesce(origin_city, 'Unknown') as origin_city,
        coalesce(origin_airport, 'Unknown') as origin_airport,
        coalesce(destination_city, 'Unknown') as destination_city,
        coalesce(destination_airport, 'Unknown') as destination_airport,
        coalesce(transit_city, 'Unknown') as transit_city,
        coalesce(transit_airport, 'Unknown') as transit_airport,
        coalesce(aircraft, 'Unknown') as aircraft_model,
        verify as verified,
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
        review as review_text
    from source_data
),

with_customer as (
    select 
        b.*,
        dc.customer_id
    from base b
    left join {{ ref('dim_customer') }} dc
        on b.customer_name = dc.customer_name and b.nationality = dc.nationality
),

with_dates as (
    select 
        wc.*,
        ds.date_id as date_submitted_id,
        df.date_id as date_flown_id
    from with_customer wc
    left join {{ ref('dim_date') }} ds on wc.date_submitted = ds.date_id
    left join {{ ref('dim_date') }} df on wc.date_flown = df.date_id
),

with_locations as (
    select 
        wd.*,
        lo_origin.location_id as origin_location_id,
        lo_dest.location_id as destination_location_id,
        lo_transit.location_id as transit_location_id
    from with_dates wd
    left join {{ ref('dim_location') }} lo_origin 
        on wd.origin_city = lo_origin.city and wd.origin_airport = lo_origin.airport
    left join {{ ref('dim_location') }} lo_dest 
        on wd.destination_city = lo_dest.city and wd.destination_airport = lo_dest.airport
    left join {{ ref('dim_location') }} lo_transit 
        on wd.transit_city = lo_transit.city and wd.transit_airport = lo_transit.airport
),

with_aircraft as (
    select 
        wl.*,
        da.aircraft_id
    from with_locations wl
    left join {{ ref('dim_aircraft') }} da
        on wl.aircraft_model = da.aircraft_model
)

select
    review_id,
    customer_id,
    date_submitted_id,
    date_flown_id,
    origin_location_id,
    destination_location_id,
    transit_location_id,
    aircraft_id,
    verified,
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
    review_text
from with_aircraft
