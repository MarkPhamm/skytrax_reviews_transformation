{{ config(
    materialized='view',
) }}

-- stg__skytrax_reviews.sql
-- Staging model for raw Skytrax reviews
-- Grain: one row per review (deduplicated on the natural key)
-- Dedup: re-scrapes can land the same review multiple times with a newer
-- updated_at; keep only the latest copy per natural key.
-- review_id: deterministic hash of the natural key (stable across runs),
-- which makes downstream incremental merges idempotent.

with source_data as (

    select
        *,
    from {{ source('SKYTRAX_REVIEWS', 'AIRLINE_REVIEWS') }}

),

deduped as (

    select
        *,
    from source_data
    qualify
        row_number() over (
            partition by customer_name, nationality, airline_name, date_submitted, review
            order by updated_at desc
        ) = 1

)

select
    {{ dbt_utils.generate_surrogate_key([
        'customer_name',
        'nationality',
        'airline_name',
        'date_submitted',
        'review',
    ]) }} as review_id,
    *,
from deduped
