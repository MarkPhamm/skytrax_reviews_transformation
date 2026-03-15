{% macro clone_prod_to_staging() %}
    {#
        Clone all production tables into the staging schema using
        Snowflake zero-copy cloning.  Run with:
            dbt run-operation clone_prod_to_staging --target staging
    #}
    {% set prod_schemas = ['SOURCE', 'INTERMEDIATE', 'MARTS'] %}

    {% for schema in prod_schemas %}
        {% set show_sql %}
            show tables in schema {{ target.database }}.{{ schema }}
        {% endset %}

        {% set results = run_query(show_sql) %}

        {% if results and results.rows | length > 0 %}
            {% for row in results %}
                {% set table_name = row[1] %}
                {% set clone_sql %}
                    create or replace table {{ target.database }}.{{ target.schema }}.{{ table_name }}
                    clone {{ target.database }}.{{ schema }}.{{ table_name }}
                {% endset %}
                {{ log("Cloning " ~ schema ~ "." ~ table_name ~ " → " ~ target.schema ~ "." ~ table_name, info=true) }}
                {% do run_query(clone_sql) %}
            {% endfor %}
        {% endif %}
    {% endfor %}

    {{ log("Done — all production tables cloned to " ~ target.schema, info=true) }}
{% endmacro %}
