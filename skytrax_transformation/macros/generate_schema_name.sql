{% macro generate_schema_name(custom_schema_name, node) %}
    {%- if target.name == 'staging' -%}
        {{ target.schema }}
    {%- elif custom_schema_name is not none -%}
        {{ custom_schema_name }}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}
{% endmacro %}