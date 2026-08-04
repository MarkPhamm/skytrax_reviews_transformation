# -----------------------------------------------------------------------------
# Warehouses
# -----------------------------------------------------------------------------
# A dedicated set of warehouses for this project. Auto-suspend keeps costs low
# when nobody is running queries. Creating 5 warehouses of increasing size.
# Every warehouse is wired to a shared monthly resource monitor (cost cap) and
# gets a per-size statement timeout: short where humans/CI iterate (XSMALL
# dev, SMALL CI) so runaway queries die fast, longer where full production
# builds run (MEDIUM prod, LARGE/XLARGE ad-hoc backfills).
# -----------------------------------------------------------------------------

locals {
  # statement_timeout_in_seconds per warehouse size
  warehouse_statement_timeouts = {
    XSMALL = 600  # local dev -- fail fast
    SMALL  = 900  # CI PR checks -- a hung query should not eat the quota
    MEDIUM = 3600 # prod deploys + Airflow full builds
    LARGE  = 3600 # ad-hoc heavy queries / backfills
    XLARGE = 3600 # ad-hoc heavy queries / backfills
  }
}

# Monthly credit cap across ALL project warehouses. Notifies at 50/75/90%,
# suspends new queries at 100%, and kills running queries at 110%.
resource "snowflake_resource_monitor" "skytrax_monthly" {
  name            = "SKYTRAX_MONTHLY_MONITOR"
  credit_quota    = var.monthly_credit_quota
  frequency       = "MONTHLY"
  start_timestamp = "IMMEDIATELY"

  notify_triggers           = [50, 75, 90]
  suspend_trigger           = 100
  suspend_immediate_trigger = 110
}

resource "snowflake_warehouse" "compute" {
  for_each       = toset(local.warehouse_sizes)
  name           = "SKYTRAX_COMPUTE_${each.value}"
  warehouse_size = each.value
  auto_suspend   = var.warehouse_auto_suspend
  auto_resume    = true

  min_cluster_count = 1
  max_cluster_count = 1

  resource_monitor             = snowflake_resource_monitor.skytrax_monthly.fully_qualified_name
  statement_timeout_in_seconds = local.warehouse_statement_timeouts[each.value]

  comment = "Skytrax ${each.value} warehouse. Managed by Terraform."
}
