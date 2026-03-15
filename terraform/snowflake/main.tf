# =============================================================================
# Snowflake RBAC & Infrastructure
# =============================================================================
# This file sets up the Snowflake objects needed for the Skytrax Reviews dbt
# project: a warehouse, database, schemas, roles, users, and grants.
#
# Role hierarchy:
#   ACCOUNTADMIN
#     -> SKYTRAX_ADMIN        (full control over the project database)
#       -> SKYTRAX_TRANSFORMER (read/write for dbt CI/CD)
#       -> SKYTRAX_ANALYST     (read-only on marts for BI tools)
# =============================================================================

# -----------------------------------------------------------------------------
# Warehouse
# -----------------------------------------------------------------------------
# A dedicated warehouse for this project. Auto-suspend keeps costs low
# when nobody is running queries.

resource "snowflake_warehouse" "compute" {
  name           = "SKYTRAX_COMPUTE_WH"
  warehouse_size = var.warehouse_size
  auto_suspend   = var.warehouse_auto_suspend
  auto_resume    = true

  # Only allow 1 cluster -- keeps things simple and cheap for a learning project
  min_cluster_count = 1
  max_cluster_count = 1

  comment = "Warehouse for Skytrax Reviews dbt project. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Database & Schemas
# -----------------------------------------------------------------------------
# The database matches what dbt expects in profiles.yml.
# Schemas match the dbt_project.yml configuration (RAW, STAGING, MARTS, DEV).

resource "snowflake_database" "skytrax" {
  name    = var.database_name
  comment = "Skytrax airline reviews data warehouse. Managed by Terraform."
}

resource "snowflake_schema" "raw" {
  database = snowflake_database.skytrax.name
  name     = "RAW"
  comment  = "Raw seed data loaded by dbt seeds"
}

resource "snowflake_schema" "staging" {
  database = snowflake_database.skytrax.name
  name     = "STAGING"
  comment  = "Staging models -- cleaned and standardized views"
}

resource "snowflake_schema" "marts" {
  database = snowflake_database.skytrax.name
  name     = "MARTS"
  comment  = "Mart models -- business-ready tables for BI tools"
}

resource "snowflake_schema" "dev" {
  database = snowflake_database.skytrax.name
  name     = "DEV"
  comment  = "Development schema for local dbt runs"
}

# -----------------------------------------------------------------------------
# Roles
# -----------------------------------------------------------------------------
# Three project-scoped roles with increasing levels of access.

resource "snowflake_account_role" "admin" {
  name    = "SKYTRAX_ADMIN"
  comment = "Full admin access to the Skytrax project database"
}

resource "snowflake_account_role" "transformer" {
  name    = "SKYTRAX_TRANSFORMER"
  comment = "Read/write access for dbt CI/CD pipelines"
}

resource "snowflake_account_role" "analyst" {
  name    = "SKYTRAX_ANALYST"
  comment = "Read-only access to marts schema for BI tools"
}

# --- Role Hierarchy ---
# ADMIN inherits both TRANSFORMER and ANALYST so admins can do everything.

resource "snowflake_grant_account_role" "admin_inherits_transformer" {
  role_name        = snowflake_account_role.transformer.name
  parent_role_name = snowflake_account_role.admin.name
}

resource "snowflake_grant_account_role" "admin_inherits_analyst" {
  role_name        = snowflake_account_role.analyst.name
  parent_role_name = snowflake_account_role.admin.name
}

# Wire ADMIN up to SYSADMIN so it follows Snowflake best practices
resource "snowflake_grant_account_role" "sysadmin_inherits_admin" {
  role_name        = snowflake_account_role.admin.name
  parent_role_name = "SYSADMIN"
}

# -----------------------------------------------------------------------------
# Grants -- Warehouse
# -----------------------------------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "transformer_wh_usage" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_wh_usage" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "admin_wh_all" {
  account_role_name = snowflake_account_role.admin.name
  privileges        = ["USAGE", "OPERATE", "MODIFY", "MONITOR"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute.name
  }
}

# -----------------------------------------------------------------------------
# Grants -- Database
# -----------------------------------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "transformer_db" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.skytrax.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_db" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.skytrax.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "admin_db" {
  account_role_name = snowflake_account_role.admin.name
  all_privileges    = true
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.skytrax.name
  }
}

# -----------------------------------------------------------------------------
# Grants -- Schemas (TRANSFORMER: all schemas read/write)
# -----------------------------------------------------------------------------

locals {
  # All schemas the transformer role needs read/write access to
  rw_schemas = {
    raw     = snowflake_schema.raw.name
    staging = snowflake_schema.staging.name
    marts   = snowflake_schema.marts.name
    dev     = snowflake_schema.dev.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_schema_usage" {
  for_each          = local.rw_schemas
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]
  on_schema {
    schema_name = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
  }
}

# Grant SELECT, INSERT, UPDATE, DELETE on all current and future tables in each schema
resource "snowflake_grant_privileges_to_account_role" "transformer_future_tables" {
  for_each          = local.rw_schemas
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_future_views" {
  for_each          = local.rw_schemas
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "VIEWS"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
    }
  }
}

# -----------------------------------------------------------------------------
# Grants -- Schemas (ANALYST: read-only on MARTS)
# -----------------------------------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "analyst_marts_usage" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${snowflake_database.skytrax.name}\".\"${snowflake_schema.marts.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_marts_future_tables" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${snowflake_schema.marts.name}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_marts_future_views" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "VIEWS"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${snowflake_schema.marts.name}\""
    }
  }
}

# -----------------------------------------------------------------------------
# Users
# -----------------------------------------------------------------------------

resource "snowflake_user" "transformer" {
  name              = "DBT_TRANSFORMER"
  login_name        = "DBT_TRANSFORMER"
  password          = var.transformer_user_password
  default_warehouse = snowflake_warehouse.compute.name
  default_role      = snowflake_account_role.transformer.name
  default_namespace = "${snowflake_database.skytrax.name}.DEV"
  comment           = "Service account for dbt CI/CD. Managed by Terraform."
}

resource "snowflake_user" "analyst" {
  name              = "SKYTRAX_ANALYST"
  login_name        = "SKYTRAX_ANALYST"
  password          = var.analyst_user_password
  default_warehouse = snowflake_warehouse.compute.name
  default_role      = snowflake_account_role.analyst.name
  default_namespace = "${snowflake_database.skytrax.name}.MARTS"
  comment           = "Read-only analyst account for BI tools. Managed by Terraform."
}

# --- Assign roles to users ---

resource "snowflake_grant_account_role" "transformer_to_user" {
  role_name = snowflake_account_role.transformer.name
  user_name = snowflake_user.transformer.name
}

resource "snowflake_grant_account_role" "analyst_to_user" {
  role_name = snowflake_account_role.analyst.name
  user_name = snowflake_user.analyst.name
}
