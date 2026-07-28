{{ config(
    tags=['load_audit'],
    severity='error',
) }}

-- Fail if any load in the last 7 days reported rejected rows or a failed /
-- partial COPY INTO status. The EL task should already raise on this; this
-- test is the warehouse-side backstop for silent under-loads.

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
    first_error,
from {{ source('SKYTRAX_REVIEWS', 'LOAD_AUDIT') }}
where load_ts >= dateadd('day', -7, current_timestamp())
    and (
        coalesce(errors_seen, 0) > 0
        or status in ('LOAD_FAILED', 'PARTIALLY_LOADED')
    )
