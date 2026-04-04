# -----------------------------------------------------------------------------
# Roles
# -----------------------------------------------------------------------------
# Three project-scoped roles with increasing levels of access.
# SKYTRAX_ADMIN: full control over the project database
# SKYTRAX_TRANSFORMER: read/write access on production schemas for dbt CI/CD
# SKYTRAX_ANALYST: read-only access to marts schema for BI tools
# -----------------------------------------------------------------------------

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
