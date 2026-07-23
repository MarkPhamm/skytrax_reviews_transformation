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
| `marts` | MARTS | table / incremental | star schema: `fct_review` + 5 conformed dims + `fct_review_enriched` BI view |

Key design points:

- **Incremental fact** — `fct_review` merges on `review_key` using the source
  `updated_at` high-water mark with a lookback window
  (`--vars '{incremental_lookback_days: N}'`, default 3). Backfill with
  `dbt run -s fct_review --full-refresh`.
- **Contract** — `fct_review` has an enforced dbt contract (column names + types).
- **Governance** — `dim_customer.customer_name`/`nationality` are tagged PII via
  post-hook; the tag's Snowflake masking policy (Terraform-managed in the
  extract-load repo) masks values for roles without `PII_READER`.
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
  build/test only `state:modified` (+ downstream).
- `deploy_main.yml` — deploy on merge to `main` + weekly cron: `dbt build
  --select state:modified+ --defer --favor-state` against the prod manifest on
  S3, then publish dbt docs to CloudFront.
- `.pre-commit-config.yaml` (repo root) mirrors the lint gates locally.
