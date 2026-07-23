# -----------------------------------------------------------------------------
# Database & Schemas
# -----------------------------------------------------------------------------
# The database matches what dbt expects in profiles.yml.
# Production schemas: RAW, SOURCE, INTERMEDIATE, STAGING, MARTS
# Per-user dev schemas: DEV_MINH, DEV_GINA, DEV_VICIENT
# -----------------------------------------------------------------------------

# Note: the database itself is created by the extract-load process, not
# Terraform. Schemas below reference it by name via var.database_name.

# Creating the raw schema
resource "snowflake_schema" "raw" {
  database = var.database_name
  name     = "RAW"
  comment  = "Raw seed data loaded by dbt seeds"
}

# Creating the source schema
resource "snowflake_schema" "source" {
  database = var.database_name
  name     = "SOURCE"
  comment  = "Production staging/intermediate models -- cleaned and standardized views"
}

# Creating the intermediate schema
resource "snowflake_schema" "intermediate" {
  database = var.database_name
  name     = "INTERMEDIATE"
  comment  = "Production intermediate models -- business logic transformations"
}

# Creating the staging schema
resource "snowflake_schema" "staging" {
  database = var.database_name
  name     = "STAGING"
  comment  = "CI scratch schema -- used only during PR checks"
}

# Creating the marts schema
resource "snowflake_schema" "marts" {
  database = var.database_name
  name     = "MARTS"
  comment  = "Mart models -- business-ready tables for BI tools"
}

# Creating the dev_minh schema
resource "snowflake_schema" "dev_minh" {
  database = var.database_name
  name     = "DEV_MINH"
  comment  = "Development schema for Minh (accountadmin)"
}

# Creating the dev_gina schema
resource "snowflake_schema" "dev_gina" {
  database = var.database_name
  name     = "DEV_GINA"
  comment  = "Development schema for Gina"
}

# Creating the dev_vicient schema
resource "snowflake_schema" "dev_vicient" {
  database = var.database_name
  name     = "DEV_VICIENT"
  comment  = "Development schema for Vicient"
}

# Creating the dev_derek schema
resource "snowflake_schema" "dev_derek" {
  database = var.database_name
  name     = "DEV_DEREK"
  comment  = "Development schema for Derek"
}

# --- [NEW ANALYST] Step 2/5: Add a dev schema ---
# resource "snowflake_schema" "dev_alex" {
#   database = var.database_name
#   name     = "DEV_ALEX"
#   comment  = "Development schema for Alex"
# }
