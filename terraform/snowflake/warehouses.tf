# -----------------------------------------------------------------------------
# Warehouses
# -----------------------------------------------------------------------------
# A dedicated set of warehouses for this project. Auto-suspend keeps costs low
# when nobody is running queries. Creating 5 warehouses of increasing size.
# -----------------------------------------------------------------------------

resource "snowflake_warehouse" "compute" {
  for_each       = toset(local.warehouse_sizes)
  name           = "SKYTRAX_COMPUTE_${each.value}"
  warehouse_size = each.value
  auto_suspend   = var.warehouse_auto_suspend
  auto_resume    = true

  min_cluster_count = 1
  max_cluster_count = 1

  comment = "Skytrax ${each.value} warehouse. Managed by Terraform."
}
