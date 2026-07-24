{% macro apply_pii_mask(columns) %}
{#-
    Post-hook: attach the PII_HASH_MASK masking policy (managed in this repo's
    terraform/snowflake/masking_policies.tf) to each given column. The policy
    returns the real value for SKYTRAX_ADMIN/SKYTRAX_TRANSFORMER and a SHA-256
    hash for every other role (e.g. SKYTRAX_ANALYST). Re-applied on every run
    because table materializations drop column-level policies on rebuild.
-#}
    alter table {{ this }} modify
    {%- for column in columns %}
        column {{ column }} set masking policy {{ target.database }}.marts.pii_hash_mask
        {{- "," if not loop.last }}
    {%- endfor %}
{% endmacro %}
