# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
# These outputs are useful for configuring dbt profiles, CI/CD pipelines,
# and connecting BI tools.
# -----------------------------------------------------------------------------

output "database_name" {
  description = "Name of the Snowflake database"
  value       = snowflake_database.skytrax.name
}

output "warehouse_name" {
  description = "Name of the compute warehouse"
  value       = snowflake_warehouse.compute.name
}

output "transformer_user" {
  description = "Username for the dbt CI/CD service account"
  value       = snowflake_user.transformer.name
}

output "transformer_role" {
  description = "Role name used by the dbt CI/CD service account"
  value       = snowflake_account_role.transformer.name
}

output "analyst_user" {
  description = "Username for the read-only analyst account"
  value       = snowflake_user.analyst.name
}

output "analyst_role" {
  description = "Role name used by the analyst account"
  value       = snowflake_account_role.analyst.name
}

output "schemas" {
  description = "Map of schema names created in the database"
  value = {
    raw     = snowflake_schema.raw.name
    staging = snowflake_schema.staging.name
    marts   = snowflake_schema.marts.name
    dev     = snowflake_schema.dev.name
  }
}
