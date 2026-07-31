import os
import subprocess
import tempfile
from datetime import datetime, timedelta

from airflow.decorators import dag, task
from airflow.hooks.base import BaseHook

DBT_PROJECT_DIR = "/usr/local/airflow/dags/dbt"
DBT_EXECUTABLE = f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt"

# Source tests + singular tests tagged load_audit (see dbt/tests/assert_load_audit_*.sql
# and models/staging/stg__skytrax_source.yml → LOAD_AUDIT).
LOAD_AUDIT_SELECT = "tag:load_audit source:SKYTRAX_REVIEWS.LOAD_AUDIT"


def _notify_failure(context):
    """Log a clear failure line. Wire Slack/email here when a webhook is available."""
    ti = context.get("task_instance") or context.get("ti")
    dag_id = getattr(ti, "dag_id", "unknown_dag")
    task_id = getattr(ti, "task_id", "unknown_task")
    exception = context.get("exception")
    print(f"[skytrax_load_audit] FAILED {dag_id}.{task_id}: {exception!r}")


def _dbt_env(scratch: str) -> dict:
    """Build env with Snowflake creds from the Airflow connection + writable scratch dirs."""
    conn = BaseHook.get_connection("snowflake_default")
    return {
        **os.environ,
        "DBT_LOG_PATH": f"{scratch}/logs",
        "DBT_TARGET_PATH": f"{scratch}/target",
        "SNOWFLAKE_ACCOUNT": conn.extra_dejson["account"],
        "SNOWFLAKE_USER": conn.login,
        "SNOWFLAKE_PASSWORD": conn.password,
        "SNOWFLAKE_ROLE": conn.extra_dejson.get("role", "SKYTRAX_TRANSFORMER"),
        "SNOWFLAKE_SCHEMA": conn.schema or "SOURCE",
    }


def _run_dbt(args: list[str], *, packages_path: str, env: dict) -> None:
    # Project mount is read-only; packages must land in a writable path.
    # Cosmos DAGs get this via install_deps=True — this DAG shells out directly.
    cmd = [
        DBT_EXECUTABLE,
        *args,
        "--project-dir",
        DBT_PROJECT_DIR,
        "--profiles-dir",
        DBT_PROJECT_DIR,
        "--packages-install-path",
        packages_path,
        "--target",
        "prod",
        "--quiet",
    ]
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, env=env, cwd=DBT_PROJECT_DIR)
    if result.returncode != 0:
        raise RuntimeError(f"dbt {' '.join(args)} exited with code {result.returncode}")


def _prepare_dbt() -> tuple[str, dict]:
    """Writable scratch + installed packages (elementary overrides the test materialization)."""
    scratch = tempfile.mkdtemp(prefix="dbt_load_audit_")
    packages_path = f"{scratch}/dbt_packages"
    env = _dbt_env(scratch)
    _run_dbt(["deps"], packages_path=packages_path, env=env)
    return packages_path, env


@dag(
    dag_id="skytrax_load_audit",
    description=(
        "Daily dbt checks on RAW.LOAD_AUDIT — freshness + reconciliation "
        "(errors, row counts, recent activity)"
    ),
    schedule="0 14 * * *",  # 09:00 CDT / 14:00 UTC daily — after overnight EL
    start_date=datetime(2025, 8, 1),
    catchup=False,
    tags=["dbt", "load_audit", "data_quality", "prod"],
    default_args={
        "depends_on_past": False,
        "retries": 1,
        "retry_delay": timedelta(minutes=5),
        "on_failure_callback": _notify_failure,
    },
)
def skytrax_load_audit():

    @task
    def source_freshness():
        """Fail if LOAD_AUDIT.load_ts is stale (warn 3d / error 7d)."""
        packages_path, env = _prepare_dbt()
        _run_dbt(
            ["source", "freshness", "--select", "source:SKYTRAX_REVIEWS.LOAD_AUDIT"],
            packages_path=packages_path,
            env=env,
        )

    @task
    def test_load_audit():
        """Run LOAD_AUDIT schema tests + singular reconciliation tests."""
        packages_path, env = _prepare_dbt()
        _run_dbt(
            ["test", "--select", LOAD_AUDIT_SELECT],
            packages_path=packages_path,
            env=env,
        )

    source_freshness() >> test_load_audit()


skytrax_load_audit()
