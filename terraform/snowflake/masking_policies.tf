# -----------------------------------------------------------------------------
# Masking Policies -- PII
# -----------------------------------------------------------------------------
# Hashes PII values for every role except ADMIN and TRANSFORMER (the roles
# that build/own the data). SKYTRAX_ANALYST -- and anyone else -- gets a
# SHA2 hash instead of the plaintext value.
#
# dbt attaches this to specific columns via a post-hook (see
# dbt/models/marts/dim_customer.sql) because dbt's CREATE OR REPLACE TABLE
# would otherwise wipe out a policy assigned directly on the column.
# -----------------------------------------------------------------------------

resource "snowflake_masking_policy" "pii_hash" {
  name     = "PII_HASH_MASK"
  database = var.database_name
  schema   = snowflake_schema.marts.name

  argument {
    name = "VAL"
    type = "VARCHAR"
  }
  return_data_type = "VARCHAR(16777216)"

  body = <<-EOT
    case
      when is_role_in_session('${snowflake_account_role.admin.name}')
        or is_role_in_session('${snowflake_account_role.transformer.name}')
      then val
      else sha2(val, 256)
    end
  EOT

  comment = "Hashes PII for any role other than admin/transformer."
}

# TRANSFORMER needs APPLY to attach this policy to columns via dbt post-hooks.
resource "snowflake_grant_privileges_to_account_role" "transformer_pii_hash_apply" {
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["APPLY"]
  on_schema_object {
    object_type = "MASKING POLICY"
    object_name = "\"${var.database_name}\".\"${snowflake_schema.marts.name}\".\"${snowflake_masking_policy.pii_hash.name}\""
  }
}
