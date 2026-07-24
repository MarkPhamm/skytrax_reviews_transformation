# Observability (Elementary)

This project uses the [Elementary](https://docs.elementary-data.com/) dbt
package for warehouse-side observability: test results, run artifacts, and
optional anomaly detection.

## Package setup

Pinned in `dbt/packages.yml` as `elementary-data/elementary` **0.19.4**
(compatible with dbt-core 1.10.x).

Project wiring (`dbt/dbt_project.yml`):

- `models.elementary.+schema: elementary` — Elementary models land in their
  own schema (verbatim `elementary` on prod via `generate_schema_name`).
- `flags.require_explicit_package_overrides_for_builtin_materializations: false`
  plus `macros/elementary_materialization.sql` — required so Elementary can
  override the Snowflake test materialization.
- The Elementary package registers its own `on-run-start` / `on-run-end`
  hooks; we do **not** duplicate `upload_dbt_artifacts()` locally.

Bootstrap once per environment after `dbt deps`:

```bash
cd dbt
dbt deps
dbt run --select elementary
```

## Anomaly tests

`fct_review` has an `elementary.volume_anomalies` test (severity **warn**)
bucketed by day on `source_updated_at`. It needs a few successful runs of
history before it becomes meaningful; warn severity keeps it from blocking
deploys while the baseline builds.

## `edr report`

The Elementary CLI (`elementary-data` in `requirements.txt`) renders an HTML
observability report from the warehouse Elementary schema:

```bash
# After dbt build/test has populated elementary tables:
edr report \
  --profiles-dir ./dbt \
  --profile-target prod \
  --file-path ./edr_report
```

CD should publish this beside dbt docs (see the TODO step in
`.github/workflows/deploy_main.yml` and the note in `docs/cicd.md`).
