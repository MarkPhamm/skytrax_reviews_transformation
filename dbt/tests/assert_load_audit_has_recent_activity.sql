{{ config(
    tags=['load_audit'],
    severity='warn',
) }}

-- Warn when LOAD_AUDIT has had no rows for 3+ days. EL runs on a laptop-local
-- Airflow instance, so short gaps are expected; this surfaces longer outages
-- without paging. Pair with source freshness on load_ts for the hard error.

select 'missing_recent_load' as failure_reason,
from (
    select count(*) as recent_load_count,
    from {{ source('SKYTRAX_REVIEWS', 'LOAD_AUDIT') }}
    where load_ts >= dateadd('day', -3, current_timestamp())
) as recent
where recent_load_count = 0
