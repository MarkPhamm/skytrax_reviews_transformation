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
    print(f"[skytrax_elementary] FAILED {dag_id}.{task_id}: {exception!r}")


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

# Elementary-only DAG. Kept separate from skytrax_dbt_transformation so the
# business-model graph stays readable. Schedule after the daily transform.
elementary_dag = DbtDag(
    project_config=ProjectConfig("/usr/local/airflow/dags/dbt"),
    operator_args={
        "install_deps": True,
    },
    profile_config=profile_config,
    execution_config=ExecutionConfig(
        dbt_executable_path=f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt",
    ),
    render_config=RenderConfig(
        select=["package:elementary"],
    ),
    default_args=default_args,
    schedule="0 20 * * *",  # 1h after skytrax_dbt_transformation (19:00 UTC daily)
    start_date=datetime(2025, 8, 1),
    catchup=False,
    dag_id="skytrax_elementary",
    description="Elementary observability models only (package:elementary)",
    tags=["dbt", "elementary", "observability", "prod"],
)
