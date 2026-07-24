import os
import shlex
import subprocess
from datetime import datetime, timedelta

from airflow.decorators import dag, task
from airflow.models.param import Param

DBT_PROJECT_DIR = "/usr/local/airflow/dags/dbt"
DBT_EXECUTABLE = f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt"

# Only allow real dbt subcommands so arbitrary shell can't be submitted
ALLOWED_SUBCOMMANDS = {
    "run", "test", "build", "seed", "snapshot", "compile",
    "ls", "list", "source", "run-operation", "show", "parse", "debug",
}


@dag(
    dag_id="skytrax_dbt_command",
    description="Run an ad-hoc dbt command against prod (submit via trigger config)",
    schedule=None,  # manual trigger only
    start_date=datetime(2025, 8, 1),
    catchup=False,
    tags=["dbt", "adhoc", "prod"],
    default_args={
        "retries": 1,
        "retry_delay": timedelta(seconds=10),
    },
    params={
        "dbt_command": Param(
            "run -s fct_review",
            type="string",
            description="dbt arguments without the leading 'dbt', e.g. 'test -s dim_date' or 'run -s fct_review --full-refresh'",
        ),
    },
)
def skytrax_dbt_command():

    @task
    def run_dbt_command(params: dict):
        import tempfile

        from airflow.hooks.base import BaseHook

        args = shlex.split(params["dbt_command"])
        if not args or args[0] not in ALLOWED_SUBCOMMANDS:
            raise ValueError(
                f"First argument must be a dbt subcommand ({sorted(ALLOWED_SUBCOMMANDS)}), got: {args[:1]}"
            )

        conn = BaseHook.get_connection("snowflake_default")
        # The dbt project dir is mounted read-only; send logs/target to a tmp dir
        scratch = tempfile.mkdtemp(prefix="dbt_command_")
        env = {
            **os.environ,
            "DBT_LOG_PATH": f"{scratch}/logs",
            "DBT_TARGET_PATH": f"{scratch}/target",
            "SNOWFLAKE_ACCOUNT": conn.extra_dejson["account"],
            "SNOWFLAKE_USER": conn.login,
            "SNOWFLAKE_PASSWORD": conn.password,
            "SNOWFLAKE_ROLE": conn.extra_dejson["role"],
            "SNOWFLAKE_SCHEMA": conn.schema,
        }

        cmd = [
            DBT_EXECUTABLE, *args,
            "--project-dir", DBT_PROJECT_DIR,
            "--profiles-dir", DBT_PROJECT_DIR,
            "--target", "prod",
        ]
        print(f"Running: dbt {' '.join(args)} (target=prod)")
        result = subprocess.run(cmd, env=env, cwd=DBT_PROJECT_DIR)
        if result.returncode != 0:
            raise RuntimeError(f"dbt exited with code {result.returncode}")

    run_dbt_command()


skytrax_dbt_command()
