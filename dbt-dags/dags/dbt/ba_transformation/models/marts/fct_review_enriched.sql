-- models/fct_review_enriched.sql
-- Adds average_rating + rating_band, with “Unknown” for null averages.
-- Timestamp columns remain last.

with base as (

    select *
    from {{ ref('fct_review') }}

), rated as (

    /* ---- compute average over only the non-null sub-ratings ---- */
    select
        base.*,

        round(
            (
                coalesce(seat_comfort,           0) +
                coalesce(cabin_staff_service,    0) +
                coalesce(food_and_beverages,     0) +
                coalesce(inflight_entertainment, 0) +
                coalesce(ground_service,         0) +
                coalesce(wifi_and_connectivity,  0) +
                coalesce(value_for_money,        0)
            )
            /
            nullif(
                (seat_comfort            is not null)::int +
                (cabin_staff_service     is not null)::int +
                (food_and_beverages      is not null)::int +
                (inflight_entertainment  is not null)::int +
                (ground_service          is not null)::int +
                (wifi_and_connectivity   is not null)::int +
                (value_for_money         is not null)::int
            , 0)
        , 2)                                    as average_rating

    from base
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
    average_rating,

    case
        when average_rating is null then 'Unknown'
        when average_rating < 2     then 'bad'
        when average_rating < 4     then 'medium'
        else                             'good'
    end                                  as rating_band,
    
    review_text,
    el_updated_at,
    t_updated_at
from rated
