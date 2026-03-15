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

output "warehouse_names" {
  description = "Map of warehouse size to name"
  value       = { for size, wh in snowflake_warehouse.compute : size => wh.name }
}

output "prod_dbt_user" {
  description = "Username for the production dbt service account"
  value       = snowflake_user.prod_dbt.name
}

output "cicd_user" {
  description = "Username for the CI/CD service account"
  value       = snowflake_user.cicd.name
}

output "transformer_role" {
  description = "Role name used by production dbt and CI/CD accounts"
  value       = snowflake_account_role.transformer.name
}

output "gina_analyst_user" {
  description = "Username for Gina's analyst account"
  value       = snowflake_user.gina_analyst.name
}

output "vicient_analyst_user" {
  description = "Username for Vicient's analyst account"
  value       = snowflake_user.vicient_analyst.name
}

output "analyst_role" {
  description = "Role name used by analyst accounts"
  value       = snowflake_account_role.analyst.name
}

output "schemas" {
  description = "Map of schema names created in the database"
  value = {
    raw         = snowflake_schema.raw.name
    staging     = snowflake_schema.staging.name
    marts       = snowflake_schema.marts.name
    dev_minh    = snowflake_schema.dev_minh.name
    dev_gina    = snowflake_schema.dev_gina.name
    dev_vicient = snowflake_schema.dev_vicient.name
  }
}
