provider "google" {
  project = var.project_id
  region  = var.region
}

module "sfg_asg" {
  source = "github.com/org/sfg-autoscaling?ref=v1.0.0"

  project_id  = var.project_id
  region      = var.region
  name_prefix = "myapp"

  network    = "projects/${var.host_project_id}/global/networks/shared-vpc"
  subnetwork = "projects/${var.host_project_id}/regions/${var.region}/subnetworks/app-subnet"

  kms_key            = var.kms_key
  gcs_bucket         = var.gcs_bucket
  gcs_installer_path = "sfg/sfg-installer-6.2.zip"

  min_replicas = 2
  max_replicas = 10

  internal_cidr_ranges = ["10.0.0.0/8"]

  labels = {
    env  = "production"
    team = "platform"
  }
}

output "instance_group_url" {
  value = module.sfg_asg.instance_group_url
}

output "service_account_email" {
  value = module.sfg_asg.service_account_email
}
