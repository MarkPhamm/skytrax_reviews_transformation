{#
  Required by elementary-data/elementary on Snowflake so anomaly / table
  tests can materialize failure artifacts. See:
  https://docs.elementary-data.com/oss/quickstart/quickstart-cli-package
#}
{% materialization test, adapter='snowflake' %}
    {{ return(elementary.materialization_test_snowflake()) }}
{% endmaterialization %}
