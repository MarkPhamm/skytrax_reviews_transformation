# =============================================================================
# Snowflake RBAC & Infrastructure -- Shared Locals
# =============================================================================
# Role hierarchy:
#   ACCOUNTADMIN
#     -> SKYTRAX_ADMIN        (full control over the project database)
#       -> SKYTRAX_TRANSFORMER (read/write on production schemas for CI/CD)
#       -> SKYTRAX_ANALYST     (read-only on marts + write on own dev schema)
# =============================================================================

locals {
  warehouse_sizes = ["XSMALL", "SMALL", "MEDIUM", "LARGE", "XLARGE"]

  # Production schemas the transformer role needs read/write access to
  prod_schemas = {
    raw          = snowflake_schema.raw.name
    source       = snowflake_schema.source.name
    intermediate = snowflake_schema.intermediate.name
    staging      = snowflake_schema.staging.name
    marts        = snowflake_schema.marts.name
  }

  # Per-user dev schemas
  dev_schemas = {
    minh    = snowflake_schema.dev_minh.name
    gina    = snowflake_schema.dev_gina.name
    vicient = snowflake_schema.dev_vicient.name
    derek   = snowflake_schema.dev_derek.name
    # --- [NEW ANALYST] Step 3/5: Add to dev_schemas map ---
    # alex    = snowflake_schema.dev_alex.name
  }
}
