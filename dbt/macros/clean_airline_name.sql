{% macro clean_airline_name(column_name) %}
{#-
    Normalize airline names from the scrape:
    - strip trailing review-count artifacts (e.g. "Frontier Airlines3843 Reviews")
    - lowercase + trim
    - coalesce null/empty to 'unknown'
-#}
coalesce(
    nullif(
        lower(
            trim(
                regexp_replace(
                    coalesce({{ column_name }}, 'unknown'),
                    '\\d*\\s*reviews?.*$',
                    '',
                    1,
                    1,
                    'i'
                )
            )
        ),
        ''
    ),
    'unknown'
)
{% endmacro %}
