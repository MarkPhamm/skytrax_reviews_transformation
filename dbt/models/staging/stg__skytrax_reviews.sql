{{ config(
    materialized='view',
) }}

-- stg__skytrax_reviews.sql
-- Staging model for raw Skytrax reviews
-- 1:1 with source table with minimal transformations
-- Grain: one row per review from source

select
    row_number() over(order by date_submitted) as review_id,
    *,
from {{ source('SKYTRAX_REVIEWS', 'AIRLINE_REVIEWS') }}
