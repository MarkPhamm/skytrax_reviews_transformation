{% macro gdpr_erase(review_id=none, customer_name=none) %}
{#-
    Demo GDPR erasure helper. Hard-deletes matching rows from fct_review and
    the SCD2 snapshot; never deletes shared dim rows (customer/airline/etc.
    may still be referenced by other reviews).

    Also appends erased review_id(s) to the warehouse table backing the
    gdpr_erased_reviews seed (create via `dbt seed` first) so rebuilds can
    exclude them once a staging filter is wired.

    Usage:
      dbt run-operation gdpr_erase --args '{review_id: "abc123"}'
      dbt run-operation gdpr_erase --args '{customer_name: "Jane Doe"}'
-#}
    {% if review_id is none and customer_name is none %}
        {{ exceptions.raise_compiler_error(
            "gdpr_erase requires review_id or customer_name (or both)."
        ) }}
    {% endif %}

    {% set fct = ref('fct_review') %}
    {% set snap = ref('snap_skytrax_reviews') %}
    {% set cust = ref('dim_customer') %}
    {% set erased = ref('gdpr_erased_reviews') %}

    {% set select_ids %}
        select f.review_id
        from {{ fct }} as f
        {% if customer_name is not none %}
        left join {{ cust }} as c
            on f.customer_id = c.customer_id
        {% endif %}
        where 1 = 1
        {% if review_id is not none %}
            and f.review_id = '{{ review_id }}'
        {% endif %}
        {% if customer_name is not none %}
            and c.customer_name = '{{ customer_name }}'
        {% endif %}
    {% endset %}

    {% set ids_result = run_query(select_ids) %}
    {% if execute %}
        {% set id_list = ids_result.columns[0].values() %}
        {% if id_list | length == 0 %}
            {{ log("gdpr_erase: no matching review_id(s) found; nothing to do.", info=True) }}
            {% do return(none) %}
        {% endif %}

        {{ log("gdpr_erase: erasing " ~ (id_list | length) ~ " review(s).", info=True) }}

        {% set id_csv = "'" ~ (id_list | join("','")) ~ "'" %}

        {% set delete_fct %}
            delete from {{ fct }}
            where review_id in ({{ id_csv }})
        {% endset %}
        {% do run_query(delete_fct) %}
        {{ log("gdpr_erase: deleted from fct_review.", info=True) }}

        {% set delete_snap %}
            delete from {{ snap }}
            where review_id in ({{ id_csv }})
        {% endset %}
        {% do run_query(delete_snap) %}
        {{ log("gdpr_erase: deleted from snap_skytrax_reviews.", info=True) }}

        {% set insert_erased %}
            insert into {{ erased }} (review_id)
            select review_id
            from (
                {% for rid in id_list %}
                select '{{ rid }}' as review_id
                {% if not loop.last %}union all{% endif %}
                {% endfor %}
            ) as incoming
            where review_id not in (
                select review_id from {{ erased }} where review_id is not null
            )
        {% endset %}
        {% do run_query(insert_erased) %}
        {{ log(
            "gdpr_erase: logged review_id(s) to gdpr_erased_reviews. "
            ~ "Also add them to dbt/seeds/gdpr_erased_reviews.csv for git.",
            info=True
        ) }}
    {% endif %}
{% endmacro %}
