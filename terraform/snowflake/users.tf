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

resource "snowflake_user" "derek_analyst" {
  name              = "DEREK_ANALYST"
  login_name        = "DEREK_ANALYST"
  password          = var.derek_analyst_password
  default_warehouse = snowflake_warehouse.compute["XSMALL"].name
  default_role      = snowflake_account_role.analyst.name
  default_namespace = "${snowflake_database.skytrax.name}.${snowflake_schema.dev_derek.name}"
  comment           = "Analyst account for Derek. Managed by Terraform."
}

# --- [NEW ANALYST] Step 4/5: Add the user ---
# resource "snowflake_user" "alex_analyst" {
#   name              = "ALEX_ANALYST"
#   login_name        = "ALEX_ANALYST"
#   password          = var.alex_analyst_password
#   default_warehouse = snowflake_warehouse.compute["XSMALL"].name
#   default_role      = snowflake_account_role.analyst.name
#   default_namespace = "${snowflake_database.skytrax.name}.${snowflake_schema.dev_alex.name}"
#   comment           = "Analyst account for Alex. Managed by Terraform."
# }

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

resource "snowflake_grant_account_role" "analyst_to_derek" {
  role_name = snowflake_account_role.analyst.name
  user_name = snowflake_user.derek_analyst.name
}

# --- [NEW ANALYST] Step 5/5: Assign the analyst role to the user ---
# resource "snowflake_grant_account_role" "analyst_to_alex" {
#   role_name = snowflake_account_role.analyst.name
#   user_name = snowflake_user.alex_analyst.name
# }
