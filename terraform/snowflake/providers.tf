# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
# The Snowflake provider authenticates using account-level credentials.
# These are passed in via variables so nothing sensitive lives in code.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 1.0"
    }
  }
}

provider "snowflake" {
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = var.snowflake_admin_user
  password          = var.snowflake_admin_password
  role              = "ACCOUNTADMIN" # We need ACCOUNTADMIN to create roles and grants
}
