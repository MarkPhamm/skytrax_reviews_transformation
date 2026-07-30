import os
from datetime import datetime

from cosmos import DbtDag, ProjectConfig, ProfileConfig, ExecutionConfig, RenderConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping


def _notify_failure(context):
    """Log a clear failure line. Wire Slack/email here when a webhook is available."""
    ti = context.get("task_instance") or context.get("ti")
    dag_id = getattr(ti, "dag_id", "unknown_dag")
    task_id = getattr(ti, "task_id", "unknown_task")
    exception = context.get("exception")
    print(f"[skytrax_dbt_transformation] FAILED {dag_id}.{task_id}: {exception!r}")


# retries=2: transient Snowflake / network blips should not red the whole DAG.
# No TriggerRule.ALL_DONE — a failed upstream must fail the DAG, not silently
# continue into a partial marts refresh.
default_args = {
    "depends_on_past": False,
    "retries": 2,
    "on_failure_callback": _notify_failure,
}

profile_config = ProfileConfig(
    profile_name="skytrax_transformation",
    target_name="prod",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snowflake_default",
        profile_args={
            "database": "SKYTRAX_REVIEWS_DB",
            "schema": "SOURCE",
            "warehouse": "SKYTRAX_COMPUTE_MEDIUM",
            "role": "SKYTRAX_TRANSFORMER",
        },
    ),
)

dbt_transformation_dag = DbtDag(
    project_config=ProjectConfig("/usr/local/airflow/dags/dbt"),
    operator_args={
        "install_deps": True,
    },
    profile_config=profile_config,
    execution_config=ExecutionConfig(
        dbt_executable_path=f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt",
    ),
    # Elementary package models are bootstrapped once via `dbt run -s elementary`
    # (see docs/observability.md). Hooks still write artifacts during each run;
    # keeping ~30 Elementary models in this DAG only clutters the graph.
    render_config=RenderConfig(
        exclude=["package:elementary"],
    ),
    default_args=default_args,
    schedule="0 19 * * *",  # Daily at 3pm EDT (19:00 UTC)
    start_date=datetime(2025, 8, 1),
    catchup=False,
    dag_id="skytrax_dbt_transformation",
    description="Production dbt transformation -- runs all models via PROD_DBT user",
    tags=["dbt", "transformation", "prod"],
)
