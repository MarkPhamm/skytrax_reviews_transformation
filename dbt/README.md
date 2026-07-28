# Skytrax Reviews — dbt Project

Transforms raw Skytrax airline reviews (loaded to Snowflake by the
[extract-load pipeline](https://github.com/MarkPhamm/skytrax_reviews_extract_load))
into a Kimball star schema consumed by the
[Spirit Airlines dashboard](https://github.com/MiaTran1112/spirit_airlines_dashboard) (Mode).

## Architecture

Three layers (see `../data_model/schema.png` for the ERD):

| Layer | Schema | Materialization | Purpose |
|---|---|---|---|
| `staging` | SOURCE | view | 1:1 with source; dedup on the natural key; deterministic `review_id` hash |
| `intermediate` | INTERMEDIATE | view | cleaning, null handling, renames |
| `marts` | MARTS | table / incremental | star schema: `fct_review` + 5 conformed dims |

Key design points:

- **Incremental fact** — `fct_review` merges on `review_id` using the source
  `updated_at` high-water mark with a lookback window
  (`--vars '{incremental_lookback_days: N}'`, default 3). Backfill with
  `dbt run -s fct_review --full-refresh`.
- **Contract** — `fct_review` has an enforced dbt contract (column names + types).
- **Governance** — `dim_customer.customer_name`/`nationality` get the
  `PII_HASH_MASK` masking policy attached via post-hook
  (`terraform/snowflake/masking_policies.tf`). `SKYTRAX_ADMIN`/
  `SKYTRAX_TRANSFORMER` see real values; every other role (e.g.
  `SKYTRAX_ANALYST`) sees a SHA-256 hash.
- **Snapshot** — `snap_skytrax_reviews` keeps SCD2 history of review changes.
- **Exposure** — the Mode dashboard is declared in `models/marts/exposures.yml`
  and shows up in dbt docs lineage.

## Running locally

```bash
export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=... SNOWFLAKE_PASSWORD=... \
       SNOWFLAKE_ROLE=... SNOWFLAKE_SCHEMA=<your_dev_schema>
dbt deps
dbt build                       # run + test everything (dev target)
dbt test --select fct_review    # schema tests + unit tests + singular tests
dbt source freshness            # loaded_at-based freshness gate
```

Targets: `dev` (default), `staging` (CI), `prod` (deploy) — see `profiles.yml`.

## Testing strategy

- **Generic tests**: unique/not_null on all keys, relationships on every FK,
  accepted_values on categoricals, `dbt_expectations` range checks on ratings.
- **Unit test**: `test_fct_review_rating_enrichment` mocks all inputs and
  asserts the `average_rating`/`rating_band` derivation.
- **Singular test**: `tests/assert_fct_review_one_row_per_review_id.sql`
  guards the dedup + merge-key invariant.
- **Source freshness**: warn 12h / error 1d on `RAW.AIRLINE_REVIEWS.updated_at`.

## CI/CD

- `pr_checks.yml` — Slim CI: sqlfluff, compile, `dbt clone` prod → staging,
  then build/test `state:modified+`/`state:new+` (the `+` matters — see below).
  Staging runs changed models twice: incremental (MERGE into cloned prod),
  then `--full-refresh` before tests.
- `deploy_main.yml` — deploy on merge to `main` + weekly cron: `dbt build
  --select state:modified+ --defer --favor-state` against the prod manifest on
  S3, then publish dbt docs to CloudFront.
- `.pre-commit-config.yaml` (repo root) mirrors the lint gates locally.

### Gotcha: breaking changes to an existing incremental model

`state:modified` alone only selects models whose *own* file changed — not
their downstream dependents. That's a problem combined with `dbt clone`:
`dbt clone` zero-copies **tables** verbatim (freezing whatever schema/data
production currently has), and only rebuilds **views** fresh. So if you
change an upstream model's output type (e.g. `stg__skytrax_reviews.review_id`
from an int to a hash), any *unmodified* downstream table
(`int_reviews_cleaned`, `fct_review`, ...) still gets cloned from production
as-is — silently reintroducing the old, incompatible type in staging.

This is why the selector uses `state:modified+`/`state:new+` (trailing `+`):
it pulls unmodified downstream dependents into the same build, and
`--full-refresh` forces them to actually rebuild from current code rather
than merge into a stale clone.

That covers staging. **Production still needs a manual one-time
full-refresh** whenever a change like this ships, because `deploy_main.yml`
never full-refreshes (it would defeat the point of incremental builds) and
because an incremental model's contract check only validates SQL types, not
whether they're compatible with the type already sitting in the live table
— so the type mismatch only surfaces as a DML failure (`Numeric value ...
is not recognized`) once dbt tries to merge new data into the old column:

```bash
cd dbt
source cred_prod.txt     # or however you export SNOWFLAKE_* for PROD_DBT
dbt run --select fct_review --target prod --full-refresh --profiles-dir ./
```

Verify with `describe table SKYTRAX_REVIEWS_DB.MARTS.FCT_REVIEW;` before
re-running/re-triggering the deploy — a stale local checkout will silently
full-refresh using the *old* model code and look like it worked without
actually fixing anything.
