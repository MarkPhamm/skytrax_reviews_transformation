-- Singular test: the staging dedup + incremental merge must guarantee exactly
-- one fact row per review_id. Duplicates here mean either the dedup natural
-- key or the incremental unique_key has drifted.

select
    review_id,
    count(*) as row_count,
from {{ ref('fct_review') }}
group by review_id
having count(*) > 1
