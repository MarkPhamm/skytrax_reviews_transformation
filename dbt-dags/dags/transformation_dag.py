import os
from datetime import datetime

from cosmos import DbtDag, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping
from airflow.utils.trigger_rule import TriggerRule


# Default arguments that will apply to all tasks created by cosmos
default_args = {
    'depends_on_past': False,
    'retries': 0,
    'trigger_rule': TriggerRule.ALL_DONE  # Run even if upstream tasks fail
}

profile_config = ProfileConfig(
    profile_name="ba_transformation",
    target_name="prod",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snowflake_default",
        profile_args={
            "database": "SKYTRAX_REVIEWS_DB",
            "schema": "SOURCE",
            "warehouse": "SKYTRAX_COMPUTE_MEDIUM",
            "role": "SKYTRAX_TRANSFORMER"
        }
    )
)

dbt_transformation_dag = DbtDag(
    project_config=ProjectConfig("/usr/local/airflow/dags/dbt"),
    operator_args={
        "install_deps": True,
    },
    profile_config=profile_config,
    execution_config=ExecutionConfig(dbt_executable_path=f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt",),
    default_args=default_args,
    schedule="0 19 * * 2",  # Run at 2pm CST (19:00 UTC) on Tuesday
    start_date=datetime(2025, 8, 1),
    catchup=False,
    dag_id="skytrax_dbt_transformation",
    description="Production dbt transformation -- runs all models via PROD_DBT user",
    tags=['dbt', 'transformation', 'prod']
)