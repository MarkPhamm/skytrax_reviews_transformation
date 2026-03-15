# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
# All sensitive values are marked as sensitive so Terraform redacts them
# from plan/apply output. Provide values via terraform.tfvars (never committed)
# or environment variables (TF_VAR_<name>).
# -----------------------------------------------------------------------------

# --- Snowflake Connection ---

variable "snowflake_organization_name" {
  description = "Snowflake organization name (the part before the account name in your URL)"
  type        = string
}

variable "snowflake_account_name" {
  description = "Snowflake account name (e.g., 'xy12345' from xy12345.snowflakecomputing.com)"
  type        = string
}

variable "snowflake_admin_user" {
  description = "Admin user for Terraform to authenticate with Snowflake"
  type        = string
}

variable "snowflake_admin_password" {
  description = "Password for the Snowflake admin user"
  type        = string
  sensitive   = true
}

# --- Users ---

variable "transformer_user_password" {
  description = "Password for the TRANSFORMER service account (used by dbt CI/CD)"
  type        = string
  sensitive   = true
}

variable "analyst_user_password" {
  description = "Password for the ANALYST user (used by BI tools)"
  type        = string
  sensitive   = true
}

# --- Database ---

variable "database_name" {
  description = "Name of the Snowflake database for this project"
  type        = string
  default     = "SKYTRAX_REVIEWS_DB"
}

# --- Warehouse ---

variable "warehouse_size" {
  description = "Size of the compute warehouse (XSMALL, SMALL, MEDIUM, etc.)"
  type        = string
  default     = "XSMALL"
}

variable "warehouse_auto_suspend" {
  description = "Seconds of inactivity before the warehouse auto-suspends (saves credits)"
  type        = number
  default     = 60
}
