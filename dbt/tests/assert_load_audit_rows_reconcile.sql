{{ config(
    tags=['load_audit'],
    severity='error',
) }}

-- Successful LOADED files must reconcile: every parsed row should land.
-- SKIPPED re-runs are ignored (0/0 or informational COPY rows).

select
    load_ts,
    category,
    review_date,
    s3_key,
    target_table,
    status,
    rows_parsed,
    rows_loaded,
    errors_seen,
from {{ source('SKYTRAX_REVIEWS', 'LOAD_AUDIT') }}
where load_ts >= dateadd('day', -7, current_timestamp())
    and status = 'LOADED'
    and rows_parsed != rows_loaded
