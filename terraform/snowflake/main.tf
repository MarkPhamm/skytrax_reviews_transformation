# =============================================================================
# Snowflake RBAC & Infrastructure
# =============================================================================
# This file sets up the Snowflake objects needed for the Skytrax Reviews dbt
# project: a warehouse, database, schemas, roles, users, and grants.
#
# Role hierarchy:
#   ACCOUNTADMIN
#     -> SKYTRAX_ADMIN        (full control over the project database)
#       -> SKYTRAX_TRANSFORMER (read/write on production schemas for CI/CD)
#       -> SKYTRAX_ANALYST     (read-only on marts + write on own dev schema)
# =============================================================================

# -----------------------------------------------------------------------------
# Warehouse
# -----------------------------------------------------------------------------
# A dedicated warehouse for this project. Auto-suspend keeps costs low
# when nobody is running queries.

locals {
  warehouse_sizes = ["XSMALL", "SMALL", "MEDIUM", "LARGE", "XLARGE"]
}

resource "snowflake_warehouse" "compute" {
  for_each       = toset(local.warehouse_sizes)
  name           = "SKYTRAX_COMPUTE_${each.value}"
  warehouse_size = each.value
  auto_suspend   = var.warehouse_auto_suspend
  auto_resume    = true

  min_cluster_count = 1
  max_cluster_count = 1

  comment = "Skytrax ${each.value} warehouse. Managed by Terraform."
}

# -----------------------------------------------------------------------------
# Database & Schemas
# -----------------------------------------------------------------------------
# The database matches what dbt expects in profiles.yml.
# Production schemas: RAW, STAGING, MARTS
# Per-user dev schemas: DEV_MINH, DEV_GINA, DEV_VICIENT

resource "snowflake_database" "skytrax" {
  name    = var.database_name
  comment = "Skytrax airline reviews data warehouse. Managed by Terraform."
}

resource "snowflake_schema" "raw" {
  database = snowflake_database.skytrax.name
  name     = "RAW"
  comment  = "Raw seed data loaded by dbt seeds"
}

resource "snowflake_schema" "source" {
  database = snowflake_database.skytrax.name
  name     = "SOURCE"
  comment  = "Production staging/intermediate models -- cleaned and standardized views"
}

resource "snowflake_schema" "intermediate" {
  database = snowflake_database.skytrax.name
  name     = "INTERMEDIATE"
  comment  = "Production intermediate models -- business logic transformations"
}

resource "snowflake_schema" "staging" {
  database = snowflake_database.skytrax.name
  name     = "STAGING"
  comment  = "CI scratch schema -- used only during PR checks"
}

resource "snowflake_schema" "marts" {
  database = snowflake_database.skytrax.name
  name     = "MARTS"
  comment  = "Mart models -- business-ready tables for BI tools"
}

resource "snowflake_schema" "dev_minh" {
  database = snowflake_database.skytrax.name
  name     = "DEV_MINH"
  comment  = "Development schema for Minh (accountadmin)"
}

resource "snowflake_schema" "dev_gina" {
  database = snowflake_database.skytrax.name
  name     = "DEV_GINA"
  comment  = "Development schema for Gina"
}

resource "snowflake_schema" "dev_vicient" {
  database = snowflake_database.skytrax.name
  name     = "DEV_VICIENT"
  comment  = "Development schema for Vicient"
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
  comment = "Read/write access on production schemas for dbt CI/CD"
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
  for_each          = toset(local.warehouse_sizes)
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute[each.value].name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_wh_usage" {
  for_each          = toset(local.warehouse_sizes)
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute[each.value].name
  }
}

resource "snowflake_grant_privileges_to_account_role" "admin_wh_all" {
  for_each          = toset(local.warehouse_sizes)
  account_role_name = snowflake_account_role.admin.name
  privileges        = ["USAGE", "OPERATE", "MODIFY", "MONITOR"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute[each.value].name
  }
}

# -----------------------------------------------------------------------------
# Grants -- Database
# -----------------------------------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "transformer_db" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE SCHEMA"]
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
# Grants -- Schemas (TRANSFORMER: production schemas read/write)
# -----------------------------------------------------------------------------

locals {
  # Production schemas the transformer role needs read/write access to
  prod_schemas = {
    raw     = snowflake_schema.raw.name
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
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_schema_usage" {
  for_each          = local.prod_schemas
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]
  on_schema {
    schema_name = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
  }
}

# Grant SELECT, INSERT, UPDATE, DELETE on all current and future tables in each schema
resource "snowflake_grant_privileges_to_account_role" "transformer_future_tables" {
  for_each          = local.prod_schemas
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
  for_each          = local.prod_schemas
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
# Grants -- Ownership (TRANSFORMER: owns all tables/views in prod schemas)
# -----------------------------------------------------------------------------
# dbt uses CREATE OR REPLACE which requires OWNERSHIP on existing objects.
# Transfer ownership of all current and future tables/views to the transformer
# role so CI/CD and production deploys can rebuild models.

resource "snowflake_grant_ownership" "transformer_tables" {
  for_each          = local.prod_schemas
  account_role_name = snowflake_account_role.transformer.name
  on {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
    }
  }
  outbound_privileges = "COPY"
}

resource "snowflake_grant_ownership" "transformer_views" {
  for_each          = local.prod_schemas
  account_role_name = snowflake_account_role.transformer.name
  on {
    all {
      object_type_plural = "VIEWS"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
    }
  }
  outbound_privileges = "COPY"
}

resource "snowflake_grant_ownership" "transformer_future_tables" {
  for_each          = local.prod_schemas
  account_role_name = snowflake_account_role.transformer.name
  on {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
    }
  }
  outbound_privileges = "COPY"
}

resource "snowflake_grant_ownership" "transformer_future_views" {
  for_each          = local.prod_schemas
  account_role_name = snowflake_account_role.transformer.name
  on {
    future {
      object_type_plural = "VIEWS"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
    }
  }
  outbound_privileges = "COPY"
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
# Grants -- Dev Schemas (per-user read/write for local dbt development)
# -----------------------------------------------------------------------------
# Each analyst gets full read/write on their own dev schema so they can run
# dbt locally with --target dev.

resource "snowflake_grant_privileges_to_account_role" "analyst_dev_schema_usage" {
  for_each          = local.dev_schemas
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]
  on_schema {
    schema_name = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_dev_future_tables" {
  for_each          = local.dev_schemas
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_dev_future_views" {
  for_each          = local.dev_schemas
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "VIEWS"
      in_schema          = "\"${snowflake_database.skytrax.name}\".\"${each.value}\""
    }
  }
}

# -----------------------------------------------------------------------------
# Users
# -----------------------------------------------------------------------------

resource "snowflake_user" "prod_dbt" {
  name              = "PROD_DBT"
  login_name        = "PROD_DBT"
  password          = var.prod_dbt_password
  default_warehouse = snowflake_warehouse.compute["XSMALL"].name
  default_role      = snowflake_account_role.transformer.name
  default_namespace = "${snowflake_database.skytrax.name}.STAGING"
  comment           = "Production dbt service account. Managed by Terraform."
}

resource "snowflake_user" "cicd" {
  name              = "DBT_CICD"
  login_name        = "DBT_CICD"
  password          = var.cicd_user_password
  default_warehouse = snowflake_warehouse.compute["XSMALL"].name
  default_role      = snowflake_account_role.transformer.name
  default_namespace = "${snowflake_database.skytrax.name}.STAGING"
  comment           = "Service account for GitHub Actions CI/CD pipelines. Managed by Terraform."
}

resource "snowflake_user" "gina_analyst" {
  name              = "GINA_ANALYST"
  login_name        = "GINA_ANALYST"
  password          = var.gina_analyst_password
  default_warehouse = snowflake_warehouse.compute["XSMALL"].name
  default_role      = snowflake_account_role.analyst.name
  default_namespace = "${snowflake_database.skytrax.name}.${snowflake_schema.dev_gina.name}"
  comment           = "Analyst account for Gina. Managed by Terraform."
}

resource "snowflake_user" "vicient_analyst" {
  name              = "VICIENT_ANALYST"
  login_name        = "VICIENT_ANALYST"
  password          = var.vicient_analyst_password
  default_warehouse = snowflake_warehouse.compute["XSMALL"].name
  default_role      = snowflake_account_role.analyst.name
  default_namespace = "${snowflake_database.skytrax.name}.${snowflake_schema.dev_vicient.name}"
  comment           = "Analyst account for Vicient. Managed by Terraform."
}

# --- Assign roles to users ---

resource "snowflake_grant_account_role" "transformer_to_prod_dbt" {
  role_name = snowflake_account_role.transformer.name
  user_name = snowflake_user.prod_dbt.name
}

resource "snowflake_grant_account_role" "transformer_to_cicd" {
  role_name = snowflake_account_role.transformer.name
  user_name = snowflake_user.cicd.name
}

resource "snowflake_grant_account_role" "analyst_to_gina" {
  role_name = snowflake_account_role.analyst.name
  user_name = snowflake_user.gina_analyst.name
}

resource "snowflake_grant_account_role" "analyst_to_vicient" {
  role_name = snowflake_account_role.analyst.name
  user_name = snowflake_user.vicient_analyst.name
}
