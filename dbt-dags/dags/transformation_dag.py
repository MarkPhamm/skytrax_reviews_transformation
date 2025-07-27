import os
from datetime import datetime

from cosmos import DbtDag, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping


profile_config = ProfileConfig(
    profile_name="ba_transformation",
    target_name="dev",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snowflake_default",
        profile_args={
            "database": "BRITISH_AIRWAYS_DB",
            "schema": "MARTS",
            "warehouse": "COMPUTE_WH",
            "role": "ACCOUNTADMIN"  # Adjust this to your actual role
        }
    )
)

dbt_transformation_dag = DbtDag(
    project_config=ProjectConfig("/usr/local/airflow/dags/dbt/ba_transformation"),
    operator_args={
        "install_deps": True,
        "select": "tag:!one_time_run"  # Exclude one-time run models from regular scheduled runs
    },
    profile_config=profile_config,
    execution_config=ExecutionConfig(dbt_executable_path=f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt",),
    schedule_interval="0 19 * * 2",  # Run at 2pm CST (19:00 UTC) on Tuesday
    start_date=datetime(2023, 9, 10),
    catchup=False,
    dag_id="dbt_transformation",
)