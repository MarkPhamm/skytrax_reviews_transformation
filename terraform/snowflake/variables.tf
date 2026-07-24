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

variable "monthly_credit_quota" {
  description = "Monthly credit cap enforced by the shared resource monitor across all project warehouses"
  type        = number
  default     = 10
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

# --- Service Account Key-Pair Auth (optional, additive) ---
# When set, the RSA public key is attached to the service user so it can also
# authenticate with a private key. Password auth keeps working until the
# password is removed in a separate, deliberate step.
# See docs/keypair-auth.md for the full rollout procedure.

variable "prod_dbt_rsa_public_key" {
  description = "RSA public key for PROD_DBT key-pair auth (PEM body without header/footer). Null = password auth only."
  type        = string
  default     = null
}

variable "cicd_rsa_public_key" {
  description = "RSA public key for DBT_CICD key-pair auth (PEM body without header/footer). Null = password auth only."
  type        = string
  default     = null
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
