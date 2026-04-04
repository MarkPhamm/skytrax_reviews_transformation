# -----------------------------------------------------------------------------
# Database & Schemas
# -----------------------------------------------------------------------------
# The database matches what dbt expects in profiles.yml.
# Production schemas: RAW, SOURCE, INTERMEDIATE, STAGING, MARTS
# Per-user dev schemas: DEV_MINH, DEV_GINA, DEV_VICIENT
# -----------------------------------------------------------------------------

# Creating the database
resource "snowflake_database" "skytrax" {
  name    = var.database_name
  comment = "Skytrax airline reviews data warehouse. Managed by Terraform."
}

# Creating the raw schema
resource "snowflake_schema" "raw" {
  database = snowflake_database.skytrax.name
  name     = "RAW"
  comment  = "Raw seed data loaded by dbt seeds"
}

# Creating the source schema
resource "snowflake_schema" "source" {
  database = snowflake_database.skytrax.name
  name     = "SOURCE"
  comment  = "Production staging/intermediate models -- cleaned and standardized views"
}

# Creating the intermediate schema
resource "snowflake_schema" "intermediate" {
  database = snowflake_database.skytrax.name
  name     = "INTERMEDIATE"
  comment  = "Production intermediate models -- business logic transformations"
}

# Creating the staging schema
resource "snowflake_schema" "staging" {
  database = snowflake_database.skytrax.name
  name     = "STAGING"
  comment  = "CI scratch schema -- used only during PR checks"
}

# Creating the marts schema
resource "snowflake_schema" "marts" {
  database = snowflake_database.skytrax.name
  name     = "MARTS"
  comment  = "Mart models -- business-ready tables for BI tools"
}

# Creating the dev_minh schema
resource "snowflake_schema" "dev_minh" {
  database = snowflake_database.skytrax.name
  name     = "DEV_MINH"
  comment  = "Development schema for Minh (accountadmin)"
}

# Creating the dev_gina schema
resource "snowflake_schema" "dev_gina" {
  database = snowflake_database.skytrax.name
  name     = "DEV_GINA"
  comment  = "Development schema for Gina"
}

# Creating the dev_vicient schema
resource "snowflake_schema" "dev_vicient" {
  database = snowflake_database.skytrax.name
  name     = "DEV_VICIENT"
  comment  = "Development schema for Vicient"
}

# Creating the dev_derek schema
resource "snowflake_schema" "dev_derek" {
  database = snowflake_database.skytrax.name
  name     = "DEV_DEREK"
  comment  = "Development schema for Derek"
}

# --- [NEW ANALYST] Step 2/5: Add a dev schema ---
# resource "snowflake_schema" "dev_alex" {
#   database = snowflake_database.skytrax.name
#   name     = "DEV_ALEX"
#   comment  = "Development schema for Alex"
# }
