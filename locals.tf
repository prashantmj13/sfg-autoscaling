locals {
  resource_prefix = "${var.name_prefix}-sfg"

  common_labels = merge(var.labels, {
    managed_by    = "terraform"
    module        = "sfg-autoscaling"
    cis_compliant = "level2"
  })

  base_sa_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/storage.objectViewer",
  ]

  all_sa_roles = distinct(concat(local.base_sa_roles, var.additional_sa_roles))

  # GCP load balancer health check probe source ranges (must be allowed for LB to work)
  hc_source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}
