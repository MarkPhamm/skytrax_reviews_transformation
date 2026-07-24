{{ config(
    materialized='view',
) }}

-- fct_review_enriched.sql
-- Thin presentation view over fct_review for BI consumption (Mode dashboards).
-- Denormalizes the airline name so dashboard queries can filter by airline
-- without repeating the dim join.
-- Grain: identical to fct_review (one row per review submission).

with fct as (

    select
        *,
    from {{ ref('fct_review') }}

),

airlines as (

    select
        *,
    from {{ ref('dim_airline') }}

)

select
    fct.*,
    airlines.airline_name as airline,
from fct
left join airlines
    on fct.airline_id = airlines.airline_id
