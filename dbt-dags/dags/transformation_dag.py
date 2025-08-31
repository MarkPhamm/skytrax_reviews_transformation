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
    target_name="dev",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snowflake_default",
        profile_args={
            "database": "SKYTRAX_REVIEWS_DB",
            "schema": "MARTS",
            "warehouse": "COMPUTE_WH",
            "role": "ACCOUNTADMIN"
        }
    )
)

dbt_transformation_dag = DbtDag(
    project_config=ProjectConfig("/usr/local/airflow/dags/dbt/skytrax_transformation"),
    operator_args={
        "install_deps": True,
        "select": "tag:!one_time_run"  # Exclude one-time run models from regular scheduled runs
    },
    profile_config=profile_config,
    execution_config=ExecutionConfig(dbt_executable_path=f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt",),
    default_args=default_args,  # Apply trigger rules to all tasks
    schedule="0 19 * * 2",  # Run at 2pm CST (19:00 UTC) on Tuesday
    start_date=datetime(2025, 8, 1),
    catchup=False,
    dag_id="dbt_skytrax_transformation",
    description="DBT transformation with continue-on-failure enabled",
    tags=['dbt', 'transformation', 'resilient']
)