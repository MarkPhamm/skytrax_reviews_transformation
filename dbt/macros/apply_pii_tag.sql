{% macro apply_pii_tag(columns) %}
{#-
    Post-hook: tag PII columns on the model's table with the governance tag
    SKYTRAX_REVIEWS_DB.RAW.PII (managed by Terraform in the extract-load repo).
    The tag carries a masking policy, so tagged columns are dynamically masked
    for any session lacking the PII_READER role. Re-applied on every run
    because table materializations drop column tags on rebuild.
-#}
    alter table {{ this }} modify
    {%- for column in columns %}
        column {{ column }} set tag skytrax_reviews_db.raw.pii = '{{ column }}'
        {{- "," if not loop.last }}
    {%- endfor %}
{% endmacro %}
