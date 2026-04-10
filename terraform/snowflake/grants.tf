# -----------------------------------------------------------------------------
# Grants -- Warehouse
# -----------------------------------------------------------------------------

# Grant USAGE and OPERATE privileges on all warehouses to the transformer role
resource "snowflake_grant_privileges_to_account_role" "transformer_wh_usage" {
  for_each          = toset(local.warehouse_sizes)
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute[each.value].name
  }
}

# Grant USAGE privilege on all warehouses to the analyst role
resource "snowflake_grant_privileges_to_account_role" "analyst_wh_usage" {
  for_each          = toset(local.warehouse_sizes)
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute[each.value].name
  }
}

# Grant all privileges on all warehouses to the admin role
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

# Grant USAGE and CREATE SCHEMA privileges on the database to the transformer role
resource "snowflake_grant_privileges_to_account_role" "transformer_db" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE SCHEMA"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.skytrax.name
  }
}

# Grant USAGE privilege on the database to the analyst role
resource "snowflake_grant_privileges_to_account_role" "analyst_db" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.skytrax.name
  }
}

# Grant all privileges on the database to the admin role
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
