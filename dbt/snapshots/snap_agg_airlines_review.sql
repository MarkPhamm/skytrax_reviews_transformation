{% snapshot snap_agg_airlines_review %}

{{
    config(
        schema='SNAPSHOTS',
        unique_key='airline_id',
        strategy='check',
        check_cols=[
            'review_count',
            'distinct_review_count',
            'verified_review_count',
            'recommended_review_count',
            'layover_review_count',
            'good_rating_count',
            'medium_rating_count',
            'bad_rating_count',
            'unknown_rating_count',
            'avg_rating',
            'avg_seat_comfort',
            'avg_cabin_staff_service',
            'avg_food_and_beverages',
            'avg_inflight_entertainment',
            'avg_ground_service',
            'avg_wifi_and_connectivity',
            'avg_value_for_money',
            'pct_recommended',
            'pct_verified',
            'first_review_date',
            'last_review_date',
            'latest_source_updated_at',
        ],
    )
}}

-- SCD Type 2 history of airline-level review aggregates.
-- A new version opens when counts, averages, or recommendation rates change
-- (e.g. new reviews land or existing reviews are edited upstream).
-- dbt_loaded_at is excluded from check_cols so a no-op rebuild does not
-- invent a false change.

select
    airline_id,
    airline_name,
    review_count,
    distinct_review_count,
    verified_review_count,
    recommended_review_count,
    layover_review_count,
    good_rating_count,
    medium_rating_count,
    bad_rating_count,
    unknown_rating_count,
    avg_rating,
    avg_seat_comfort,
    avg_cabin_staff_service,
    avg_food_and_beverages,
    avg_inflight_entertainment,
    avg_ground_service,
    avg_wifi_and_connectivity,
    avg_value_for_money,
    pct_recommended,
    pct_verified,
    first_review_date,
    last_review_date,
    latest_source_updated_at,
from {{ ref('agg_airlines_review') }}

{% endsnapshot %}
