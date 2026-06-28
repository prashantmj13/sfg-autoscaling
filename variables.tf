variable "project_id" {
  type        = string
  description = "GCP project ID where resources are deployed."
}

variable "region" {
  type        = string
  description = "GCP region for the regional MIG and autoscaler (e.g. us-central1)."
}

variable "name_prefix" {
  type        = string
  description = "Short identifier prepended to every resource name. Must be lowercase alphanumeric with hyphens."
  default     = "sfg"
}

variable "network" {
  type        = string
  description = "Self-link or fully-qualified URL of the VPC network."
}

variable "subnetwork" {
  type        = string
  description = "Self-link or fully-qualified URL of the subnetwork."
}

variable "internal_cidr_ranges" {
  type        = list(string)
  description = "VPC CIDR ranges allowed inbound to SFG application ports (from LB proxy or internal callers)."
  default     = []
}

variable "machine_type" {
  type        = string
  description = "Compute Engine machine type for SFG VMs."
  default     = "n2-standard-4"
}

variable "boot_disk_image" {
  type        = string
  description = "Compute Engine image for the boot disk."
  default     = "projects/debian-cloud/global/images/family/debian-12"
}

variable "boot_disk_size_gb" {
  type        = number
  description = "Size of the boot disk in GB."
  default     = 100
}

variable "boot_disk_type" {
  type        = string
  description = "Persistent disk type: pd-ssd or pd-balanced."
  default     = "pd-ssd"
}

variable "kms_key" {
  type        = string
  description = "Full self-link of the Cloud KMS CryptoKey version for boot disk encryption. CIS 4.7: CMEK required."
}

variable "min_replicas" {
  type        = number
  description = "Minimum number of instances in the MIG."
  default     = 2
}

variable "max_replicas" {
  type        = number
  description = "Maximum number of instances the autoscaler can scale to."
  default     = 10
}

variable "cpu_utilization_target" {
  type        = number
  description = "Target CPU utilization (0.0–1.0) for the autoscaler."
  default     = 0.60
}

variable "cooldown_period" {
  type        = number
  description = "Seconds after a scale event before another can begin."
  default     = 300
}

variable "gcs_bucket" {
  type        = string
  description = "GCS bucket name containing the SFG installer and license files."
}

variable "gcs_installer_path" {
  type        = string
  description = "Object path within gcs_bucket for the SFG installer ZIP (e.g. sfg/sfg-installer-6.2.zip)."
}

variable "sfg_install_dir" {
  type        = string
  description = "Absolute path on the VM where SFG will be installed."
  default     = "/opt/sfg"
}

variable "sfg_port" {
  type        = number
  description = "TCP port SFG listens on (used in firewall rules and health check)."
  default     = 8443
}

variable "health_check_request_path" {
  type        = string
  description = "HTTPS request path for the auto-healing health check."
  default     = "/health"
}

variable "service_account_id" {
  type        = string
  description = "Account ID for the dedicated SFG service account (6–30 chars, lowercase alphanumeric/hyphens)."
  default     = "sfg-vm-sa"
}

variable "additional_sa_roles" {
  type        = list(string)
  description = "Additional IAM roles to grant to the SFG service account beyond the default set."
  default     = []
}

variable "enable_secure_boot" {
  type        = bool
  description = "CIS 4.8: Enable Secure Boot on Shielded VMs."
  default     = true
}

variable "enable_vtpm" {
  type        = bool
  description = "CIS 4.8: Enable vTPM on Shielded VMs."
  default     = true
}

variable "enable_integrity_monitoring" {
  type        = bool
  description = "CIS 4.8: Enable integrity monitoring on Shielded VMs."
  default     = true
}

variable "enable_confidential_vm" {
  type        = bool
  description = "Enable Confidential Computing. Requires N2D machine type and compatible image."
  default     = false
}

variable "auto_healing_initial_delay_sec" {
  type        = number
  description = "Seconds to wait after instance start before auto-healing health checks begin."
  default     = 300
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to all resources. Merged with module-managed CIS tracking labels."
  default     = {}
}
