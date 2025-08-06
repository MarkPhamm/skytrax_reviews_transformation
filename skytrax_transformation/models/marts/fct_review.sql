-- models/fct_review.sql

with source_data as (
    select * 
    from {{ ref("stg__skytrax_reviews") }}
),

base as (
    select 
        row_number() over (order by date_submitted, customer_name) as review_id,
        coalesce(customer_name, 'Unknown') as customer_name,
        coalesce(nationality, 'Unknown') as nationality,
        date_submitted,
        date_flown,
        airline_name as airline,
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
        review as review_text,
        convert_timezone('America/Los_Angeles', 'UTC', updated_at)::timestamp_ntz as el_updated_at,
        convert_timezone('America/Los_Angeles', 'UTC', current_timestamp())::timestamp_ntz as t_updated_at
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
        coalesce(ds.date_id, to_date('2015-01-01', 'YYYY-MM-DD')) as date_submitted_id,
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
    airline,
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
    review_text,
    el_updated_at,
    t_updated_at
from with_aircraft
where 1=1
    -- Remove rows with null foreign keys (failed joins)
    and customer_id is not null
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
