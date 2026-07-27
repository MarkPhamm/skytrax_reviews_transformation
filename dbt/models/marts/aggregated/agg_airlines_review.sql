{{ config(
    materialized='table',
) }}

-- agg_airlines_review.sql
-- Airline-level review metrics rolled up from fct_review.
-- Grain: one row per airline with at least one fact review.
-- Snapshot via snap_agg_airlines_review to track how scores drift over time.

with reviews as (

    select
        *,
    from {{ ref('fct_review') }}

),

airlines as (

    select
        airline_id,
        airline_name,
    from {{ ref('dim_airline') }}

),

aggregated as (

    select
        r.airline_id,
        count(*) as review_count,
        count(distinct r.review_id) as distinct_review_count,
        sum(case when r.is_verified then 1 else 0 end) as verified_review_count,
        sum(case when r.recommended then 1 else 0 end) as recommended_review_count,
        sum(case when r.has_layover then 1 else 0 end) as layover_review_count,
        sum(case when r.rating_band = 'good' then 1 else 0 end) as good_rating_count,
        sum(case when r.rating_band = 'medium' then 1 else 0 end) as medium_rating_count,
        sum(case when r.rating_band = 'bad' then 1 else 0 end) as bad_rating_count,
        sum(case when r.rating_band = 'unknown' then 1 else 0 end) as unknown_rating_count,
        cast(round(avg(r.average_rating), 2) as number(38, 2)) as avg_rating,
        cast(round(avg(r.seat_comfort), 2) as number(38, 2)) as avg_seat_comfort,
        cast(round(avg(r.cabin_staff_service), 2) as number(38, 2)) as avg_cabin_staff_service,
        cast(round(avg(r.food_and_beverages), 2) as number(38, 2)) as avg_food_and_beverages,
        cast(round(avg(r.inflight_entertainment), 2) as number(38, 2)) as avg_inflight_entertainment,
        cast(round(avg(r.ground_service), 2) as number(38, 2)) as avg_ground_service,
        cast(round(avg(r.wifi_and_connectivity), 2) as number(38, 2)) as avg_wifi_and_connectivity,
        cast(round(avg(r.value_for_money), 2) as number(38, 2)) as avg_value_for_money,
        cast(
            round(avg(case when r.recommended then 1.0 else 0.0 end), 4)
            as number(38, 4)
        ) as pct_recommended,
        cast(
            round(avg(case when r.is_verified then 1.0 else 0.0 end), 4)
            as number(38, 4)
        ) as pct_verified,
        min(r.date_submitted_id) as first_review_date,
        max(r.date_submitted_id) as last_review_date,
        max(r.source_updated_at) as latest_source_updated_at,
    from reviews as r
    group by 1

),

final as (

    select
        agg.airline_id,
        a.airline_name,
        agg.review_count,
        agg.distinct_review_count,
        agg.verified_review_count,
        agg.recommended_review_count,
        agg.layover_review_count,
        agg.good_rating_count,
        agg.medium_rating_count,
        agg.bad_rating_count,
        agg.unknown_rating_count,
        agg.avg_rating,
        agg.avg_seat_comfort,
        agg.avg_cabin_staff_service,
        agg.avg_food_and_beverages,
        agg.avg_inflight_entertainment,
        agg.avg_ground_service,
        agg.avg_wifi_and_connectivity,
        agg.avg_value_for_money,
        agg.pct_recommended,
        agg.pct_verified,
        agg.first_review_date,
        agg.last_review_date,
        agg.latest_source_updated_at,
        current_timestamp() as dbt_loaded_at,
    from aggregated as agg
    inner join airlines as a
        on agg.airline_id = a.airline_id

)

select
    *,
from final
