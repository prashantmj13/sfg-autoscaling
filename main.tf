data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

# ── Service Account ───────────────────────────────────────────────────────────

resource "google_service_account" "sfg_vm" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "SFG VM Service Account"
  description  = "Dedicated non-default SA for SFG Compute instances. CIS 4.1: avoid default SA."
}

resource "google_project_iam_member" "sfg_vm_roles" {
  for_each = toset(local.all_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.sfg_vm.email}"
}

# ── Instance Template ─────────────────────────────────────────────────────────

resource "google_compute_instance_template" "sfg" {
  project      = var.project_id
  region       = var.region
  name_prefix  = "${local.resource_prefix}-tpl-"
  machine_type = var.machine_type
  labels       = local.common_labels

  tags = ["${local.resource_prefix}-vm", "sfg"]

  # CIS 4.1: dedicated non-default service account; cloud-platform scope required
  # for gcloud storage cp in the startup script
  service_account {
    email  = google_service_account.sfg_vm.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  disk {
    source_image = var.boot_disk_image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.boot_disk_size_gb
    disk_type    = var.boot_disk_type
    labels       = local.common_labels

    # CIS 4.7: CMEK disk encryption
    disk_encryption_key {
      kms_key_self_link = var.kms_key
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
    # CIS 4.9: no access_config block → no ephemeral public IP assigned
  }

  metadata = {
    enable-oslogin         = "TRUE"  # CIS 4.4: OS Login replaces SSH key management
    block-project-ssh-keys = "TRUE"  # CIS 4.3: block project-wide SSH keys
    serial-port-enable     = "FALSE" # CIS 4.5: disable serial port access

    startup-script = templatefile("${path.module}/startup_script.sh.tpl", {
      gcs_bucket         = var.gcs_bucket
      gcs_installer_path = var.gcs_installer_path
      sfg_install_dir    = var.sfg_install_dir
      sfg_port           = var.sfg_port
    })
  }

  # CIS 4.8: Shielded VM controls
  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = var.enable_vtpm
    enable_integrity_monitoring = var.enable_integrity_monitoring
  }

  dynamic "confidential_instance_config" {
    for_each = var.enable_confidential_vm ? [1] : []
    content {
      enable_confidential_compute = true
    }
  }

  # Required: MIG holds a reference to this template; create replacement before
  # destroying the old one so the MIG reference is never broken during updates.
  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto-healing Health Check ─────────────────────────────────────────────────

resource "google_compute_health_check" "sfg_internal" {
  project             = var.project_id
  name                = "${local.resource_prefix}-hc-internal"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  https_health_check {
    port         = var.sfg_port
    request_path = var.health_check_request_path
  }
}

# ── Regional Managed Instance Group ──────────────────────────────────────────

resource "google_compute_region_instance_group_manager" "sfg" {
  project            = var.project_id
  region             = var.region
  name               = "${local.resource_prefix}-mig"
  base_instance_name = local.resource_prefix

  distribution_policy_zones = data.google_compute_zones.available.names

  version {
    instance_template = google_compute_instance_template.sfg.id
  }

  named_port {
    name = "sfg-https"
    port = var.sfg_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.sfg_internal.id
    initial_delay_sec = var.auto_healing_initial_delay_sec
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 3
    max_unavailable_fixed = 0
  }
}

# ── Regional Autoscaler ───────────────────────────────────────────────────────

resource "google_compute_region_autoscaler" "sfg" {
  project = var.project_id
  region  = var.region
  name    = "${local.resource_prefix}-asc"
  target  = google_compute_region_instance_group_manager.sfg.id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = var.cooldown_period

    cpu_utilization {
      target = var.cpu_utilization_target
    }
  }
}

# ── Firewall Rules ────────────────────────────────────────────────────────────

# Allow GCP LB health check probes (required for LB to route traffic)
resource "google_compute_firewall" "sfg_allow_hc" {
  project   = var.project_id
  name      = "${local.resource_prefix}-allow-hc"
  network   = var.network
  priority  = 1000
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [tostring(var.sfg_port)]
  }

  source_ranges = local.hc_source_ranges
  target_tags   = ["${local.resource_prefix}-vm"]

  # CIS 3.8: firewall rule logging
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow internal VPC traffic to SFG port (from LB proxies and approved CIDRs)
resource "google_compute_firewall" "sfg_allow_internal" {
  count = length(var.internal_cidr_ranges) > 0 ? 1 : 0

  project   = var.project_id
  name      = "${local.resource_prefix}-allow-internal"
  network   = var.network
  priority  = 1000
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [tostring(var.sfg_port)]
  }

  source_ranges = var.internal_cidr_ranges
  target_tags   = ["${local.resource_prefix}-vm"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Explicit deny-all ingress for SFG instances (logged)
resource "google_compute_firewall" "sfg_deny_all" {
  project   = var.project_id
  name      = "${local.resource_prefix}-deny-all"
  network   = var.network
  priority  = 65534
  direction = "INGRESS"

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${local.resource_prefix}-vm"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
