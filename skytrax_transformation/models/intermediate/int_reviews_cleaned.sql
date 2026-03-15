{{ config(
    materialized='view',
) }}

-- int_reviews_cleaned.sql
-- Intermediate layer: clean and normalize staging data
-- Grain: one row per review submission
-- All business logic and nullability handling centralized here

with source_data as (

    select
        *,
    from {{ ref('stg__skytrax_reviews') }}

),

cleaned as (

    select
        review_id,
        coalesce(customer_name, 'unknown') as customer_name,
        coalesce(nationality, 'unknown') as nationality,
        date_submitted,
        date_flown,
        coalesce(airline_name, 'unknown') as airline_name,
        coalesce(origin_city, 'unknown') as origin_city,
        coalesce(origin_airport, 'unknown') as origin_airport,
        coalesce(destination_city, 'unknown') as destination_city,
        coalesce(destination_airport, 'unknown') as destination_airport,
        coalesce(transit_city, 'unknown') as transit_city,
        coalesce(transit_airport, 'unknown') as transit_airport,
        coalesce(aircraft, 'unknown') as aircraft_model,
        verify as is_verified,
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
        updated_at,
    from source_data

)

select
    *,
from cleaned
