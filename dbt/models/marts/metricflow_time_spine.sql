-- Daily calendar spine required by MetricFlow / dbt Semantic Layer.
-- Range covers the Skytrax review window plus a short forward buffer.
{{
    config(
        materialized='table',
        tags=['marts', 'metricflow'],
    )
}}

with days as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2015-01-01' as date)",
        end_date="cast('2030-01-01' as date)"
    ) }}
)

select cast(date_day as date) as date_day
from days
