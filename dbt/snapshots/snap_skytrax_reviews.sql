{% snapshot snap_skytrax_reviews %}

{{
    config(
        schema='SNAPSHOTS',
        unique_key='review_id',
        strategy='timestamp',
        updated_at='updated_at',
    )
}}

-- SCD Type 2 history of reviews as they arrive from the EL pipeline.
-- If a review is re-scraped with changed content (edited review, corrected
-- rating), the previous version is closed out (dbt_valid_to) and a new
-- version row opens — the marts always use the latest, the snapshot keeps
-- the full history for auditability.

select
    *,
from {{ ref('stg__skytrax_reviews') }}

{% endsnapshot %}
