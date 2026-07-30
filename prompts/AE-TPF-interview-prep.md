# AE - TPF Interview — Prep Summary

Source: `AE - TPF Interview - Prepare for Technical Interview Round (TPF) (Send-to-Candidate) - v2.1`

## What this is

An evidence-based technical interview for the **Analytics Engineering - Technical Progression Framework (AE-TPF)**. You bring your own project/work; there's no assigned task. The work must demonstrate 5 core skills on a required tech stack, live, within the time budget.

## Format: Show → Why → What-if

For each of the 5 core areas:

- **Show** — where/how it's implemented (code, models, tests, BI, PRs, diagrams)
- **Why** — the reasoning (trade-offs, alternatives, constraints)
- **What-if** — adapt live to a small change or new requirement

If a topic wasn't pre-built, you can implement a small example live (time-boxed).

## Project scope

An end-to-end data solution solving a business problem via **one meaningful, quantifiable metric** (Profit, Cost, Revenue, LTV, ROAS, etc.). Must be fully functional and demo-ready. Balance **depth** (complex logic) vs **breadth** (covers all 5 areas). Ideally your own work — team/assigned work is accepted but limits how much end-to-end ownership you can show.

## Required tech stack

- **Transformation**: dbt Core or dbt Cloud
- **Data Warehouse**: cloud DWH (Snowflake, BigQuery, Databricks)
- **BI/Analytics**: BI tool (Omni, Sigma, Power BI, Looker) connected directly to warehouse models

## 5 core evaluation areas

1. **Data Modeling & Architecture** — a modeling approach (Dimensional, Data Vault, 3NF) with clear layered structure (e.g. Medallion).
2. **Data Transformation** — dbt transformations including **at least one incremental model**; ELT/ETL best practices (dedup, macros, advanced dbt techniques).
3. **Data Governance (Quality & Security)** — live data quality checks (dbt test(s) or warehouse-native); sensitive-data handling (masking, hashing, access control).
4. **Data Insight** — final metric(s) shown via BI dashboard/semantic layer; explain the SQL logic (joins/aggregations/filters) and business impact.
5. **DataOps** — git branching strategy, CI/CD pipeline, release process.

## Practical checklist

- Navigable repo/project
- Working dbt project you can run live (`dbt run`/`dbt test` etc.)
- Live access to your warehouse and BI tool/dashboard
- A prepared demo plan with timing per section
- Evidence for Data Modeling (ERD/docs) and DataOps (CI/CD config, run logs, branching walkthrough)

## Confidentiality

No live secrets/passwords/tokens on screen. Use sanitized configs and non-sensitive data. If something can't be shown, explain the control + provide alternative evidence (diagram, redacted screenshot).

## Timing (≤ 1.5h total)

- 5 min: overview/intro
- 75 min: walkthrough, 15 min/topic × 5 topics (recommended order: Modeling → Transformation → Governance → Insight → DataOps)
- 10 min: Q&A
- ~5 min per sub-topic, up to 3 sub-topics per area, each scored 0–3, averaged across areas
- You control pacing — okay to ask to move on or linger on strengths

## AI usage policy

- **Strictly prohibited during the live interview** (no ChatGPT/Claude/Copilot/Cursor/Claude Code/etc., no AI-generated live answers or code).
- **Fully allowed before the interview** — prep, docs, and building the project with AI assistance is fine. You just have to present and defend it yourself, live, without AI in the room.

> **PDF inconsistency (v2.1):** one section allows AI-assisted IDE autocomplete / inline syntax during live coding; a later “Prohibited AI usage” list bans IDE-integrated AI autocomplete and inline suggestions. **Rehearse the conservative rule: no AI tooling live** (turn off Copilot/Cursor/Claude Code; plain editor only). Do not rely on the exception.

## Skytrax evidence map (quick)

| Pillar | Primary repo | Open first |
| --- | --- | --- |
| Modeling | `skytrax_reviews_transformation` | ERD `data_model/`, dbt docs lineage, deck Modeling slides |
| Transformation | `skytrax_reviews_transformation` | `fct_review` incremental, macros, `dbt run`/`test` |
| Governance | EL + transformation | EL quarantine/`LOAD_AUDIT`; marts `PII_HASH_MASK` A/B; dbt tests/freshness |
| Insight | Mode dashboards + MetricFlow | Delta / Frontier / Spirit PDFs; `mf query` on `avg_rating` / `pct_recommended` |
| DataOps | transformation (+ EL CI) | `.github/workflows/`, OIDC slide, branching walkthrough |

Demo crib: [`skytrax_reviews/docs/demo-runbook.md`](../skytrax_reviews/docs/demo-runbook.md).

## Assessment principles

- Judged on understanding, implementing, justifying, and extending live.
- Depth (seniority signal) and breadth (coverage) weighted equally.
- Success = balancing complexity, functionality, and clear communication in the time given.
