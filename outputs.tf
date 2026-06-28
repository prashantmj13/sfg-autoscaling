output "instance_group_url" {
  description = "Self-link URL of the MIG instance group. Pass this to the sfg-load-balancer module as instance_group_url."
  value       = google_compute_region_instance_group_manager.sfg.instance_group
}

output "instance_group_manager_id" {
  description = "Terraform resource ID of the regional MIG manager."
  value       = google_compute_region_instance_group_manager.sfg.id
}

output "service_account_email" {
  description = "Email of the dedicated SFG VM service account."
  value       = google_service_account.sfg_vm.email
}

output "instance_template_id" {
  description = "Self-link of the current instance template."
  value       = google_compute_instance_template.sfg.id
}

output "health_check_id" {
  description = "Self-link of the internal auto-healing health check."
  value       = google_compute_health_check.sfg_internal.id
}

output "named_port" {
  description = "Named port object for referencing in backend service configuration."
  value = {
    name = "sfg-https"
    port = var.sfg_port
  }
}

output "network_tag" {
  description = "Network tag applied to SFG VM instances. Use to target additional firewall rules."
  value       = "${local.resource_prefix}-vm"
}
