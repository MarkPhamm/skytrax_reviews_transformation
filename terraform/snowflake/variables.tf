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

# --- Database ---

variable "database_name" {
  description = "Name of the Snowflake database for this project"
  type        = string
  default     = "SKYTRAX_REVIEWS_DB"
}

# --- Warehouse ---

variable "warehouse_auto_suspend" {
  description = "Seconds of inactivity before the warehouse auto-suspends (saves credits)"
  type        = number
  default     = 60
}

# --- User Passwords ---

variable "prod_dbt_password" {
  description = "Password for the PROD_DBT service account (production dbt runs)"
  type        = string
  sensitive   = true
}

variable "cicd_user_password" {
  description = "Password for the DBT_CICD service account (used by GitHub Actions)"
  type        = string
  sensitive   = true
}

variable "gina_analyst_password" {
  description = "Password for GINA_ANALYST user"
  type        = string
  sensitive   = true
}

variable "vicient_analyst_password" {
  description = "Password for VICIENT_ANALYST user"
  type        = string
  sensitive   = true
}

variable "derek_analyst_password" {
  description = "Password for DEREK_ANALYST user"
  type        = string
  sensitive   = true
}

# --- [NEW ANALYST] Step 1/5: Add a password variable ---
# variable "alex_analyst_password" {
#   description = "Password for ALEX_ANALYST user"
#   type        = string
#   sensitive   = true
# }
