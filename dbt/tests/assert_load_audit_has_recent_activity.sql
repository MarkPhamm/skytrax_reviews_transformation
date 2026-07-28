{{ config(
    tags=['load_audit'],
    severity='warn',
) }}

-- Warn when LOAD_AUDIT has had no rows for 3+ days. EL runs on a laptop-local
-- Airflow instance, so short gaps are expected; this surfaces longer outages
-- without paging. Pair with source freshness on load_ts for the hard error.

select 1 as missing_recent_load
where not exists (
    select 1
    from {{ source('SKYTRAX_REVIEWS', 'LOAD_AUDIT') }}
    where load_ts >= dateadd('day', -3, current_timestamp())
)
