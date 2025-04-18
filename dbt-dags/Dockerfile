FROM quay.io/astronomer/astro-runtime:12.8.0

# Increase timeout to avoid DagBag import failure
ENV AIRFLOW__CORE__DAGBAG_IMPORT_TIMEOUT=300

# Set up dbt virtual environment
RUN python -m venv dbt_venv && \
    . dbt_venv/bin/activate && \
    pip install --no-cache-dir dbt-snowflake && \
    deactivate
