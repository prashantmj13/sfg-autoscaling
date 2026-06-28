# sfg-autoscaling

Terraform module that provisions a GCP Regional Managed Instance Group (MIG) with CPU-based autoscaling. Designed as a generic, reusable compute layer — the startup script can be the built-in SFG installer or any custom script supplied by the caller.

## Resources Created

| Resource | Description |
|---|---|
| `google_service_account` | Dedicated non-default service account for VMs |
| `google_project_iam_member` | Binds logging, monitoring, and storage viewer roles to the SA |
| `google_compute_instance_template` | Shielded VM template with security controls applied |
| `google_compute_region_instance_group_manager` | Regional MIG spread across all zones in the region |
| `google_compute_region_autoscaler` | CPU-based autoscaler |
| `google_compute_health_check` | HTTPS auto-healing health check |
| `google_compute_firewall` (×3) | Allow LB health check probes, allow internal CIDRs, deny-all |

## Security Controls Applied

| Control | Implementation |
|---|---|
| Instances not using default service account | Dedicated SA created; `service_account.email` set explicitly |
| Block project-wide SSH keys | `metadata.block-project-ssh-keys = TRUE` |
| OS Login enabled | `metadata.enable-oslogin = TRUE` |
| Serial port disabled | `metadata.serial-port-enable = FALSE` |
| No public IP | No `access_config {}` block in `network_interface` |
| Shielded VM | `enable_secure_boot`, `enable_vtpm`, `enable_integrity_monitoring` all default `true` |
| CMEK disk encryption | Optional — set `kms_key` to enable; omit for Google-managed encryption |

## Usage

### With built-in SFG startup script

```hcl
module "autoscaling" {
  source = "github.com/prashantmj13/sfg-autoscaling?ref=v1.0.0"

  project_id         = "my-project"
  region             = "us-central1"
  network            = "projects/host/global/networks/shared-vpc"
  subnetwork         = "projects/host/regions/us-central1/subnetworks/app-subnet"
  gcs_bucket         = "sfg-installers"
  gcs_installer_path = "sfg/sfg-installer-6.2.zip"
}
```

### With a custom startup script (used by wrapper modules)

```hcl
module "autoscaling" {
  source = "github.com/prashantmj13/sfg-autoscaling?ref=v1.0.0"

  project_id  = "my-project"
  region      = "us-central1"
  network     = "projects/host/global/networks/shared-vpc"
  subnetwork  = "projects/host/regions/us-central1/subnetworks/app-subnet"

  startup_script = templatefile("${path.module}/my_startup.sh.tpl", {
    some_var = "value"
  })
}
```

When `startup_script` is set, `gcs_bucket` and `gcs_installer_path` are not required.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.5.0 |
| google provider | >= 5.0.0, < 6.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| project_id | GCP project ID | string | — | yes |
| region | GCP region | string | — | yes |
| network | VPC network self-link | string | — | yes |
| subnetwork | Subnetwork self-link | string | — | yes |
| name_prefix | Resource name prefix | string | `"sfg"` | no |
| machine_type | Compute Engine machine type | string | `"n2-standard-4"` | no |
| boot_disk_image | Boot disk image | string | `debian-12` | no |
| boot_disk_size_gb | Boot disk size in GB | number | `100` | no |
| boot_disk_type | Disk type (`pd-ssd` or `pd-balanced`) | string | `"pd-ssd"` | no |
| kms_key | Cloud KMS CryptoKey version self-link for CMEK. `null` uses Google-managed encryption | string | `null` | no |
| min_replicas | Minimum MIG instance count | number | `2` | no |
| max_replicas | Maximum MIG instance count | number | `10` | no |
| cpu_utilization_target | Autoscaler CPU target (0.0–1.0) | number | `0.60` | no |
| cooldown_period | Autoscaler cooldown in seconds | number | `300` | no |
| gcs_bucket | GCS bucket with SFG installer. Not needed when `startup_script` is set | string | `""` | no |
| gcs_installer_path | Object path to SFG installer ZIP. Not needed when `startup_script` is set | string | `""` | no |
| startup_script | Custom startup script. Overrides the built-in SFG installer script when set | string | `null` | no |
| sfg_install_dir | SFG install path on VM (built-in script only) | string | `"/opt/sfg"` | no |
| sfg_port | TCP port the application listens on | number | `8443` | no |
| health_check_request_path | HTTPS path for auto-healing health check | string | `"/health"` | no |
| service_account_id | Service account ID (6–30 chars) | string | `"sfg-vm-sa"` | no |
| additional_sa_roles | Extra IAM roles to bind to the SA | list(string) | `[]` | no |
| internal_cidr_ranges | VPC CIDRs allowed inbound to the application port | list(string) | `[]` | no |
| enable_secure_boot | Shielded VM: Secure Boot | bool | `true` | no |
| enable_vtpm | Shielded VM: vTPM | bool | `true` | no |
| enable_integrity_monitoring | Shielded VM: Integrity Monitoring | bool | `true` | no |
| enable_confidential_vm | Confidential Computing (requires N2D machine type) | bool | `false` | no |
| auto_healing_initial_delay_sec | Seconds before auto-healing begins after instance start | number | `300` | no |
| labels | Additional resource labels | map(string) | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| instance_group_url | MIG instance group URL — pass to `sfg-load-balancer` as `instance_group_url` |
| instance_group_manager_id | MIG manager resource ID |
| service_account_email | VM service account email |
| instance_template_id | Current instance template self-link |
| health_check_id | Auto-healing health check self-link |
| named_port | Named port object `{ name, port }` |
| network_tag | Network tag on VM instances — use to target additional firewall rules |

## Startup Script

The built-in startup script (`startup_script.sh.tpl`) runs when `startup_script` is not set:

1. Installs Java 11 JDK and Google Cloud CLI
2. Downloads the SFG installer ZIP from GCS using `gcloud storage cp`
3. Runs silent install to `sfg_install_dir`
4. Writes `sandbox.cfg` with the instance's own name, IP, and port (pulled from GCE metadata)
5. Starts the SFG service

Logs: `/var/log/sfg-startup.log` and `/var/log/sfg-install.log`

To inject a different startup script (e.g. for a perimeter server), set the `startup_script` variable with the rendered script content.

## Versioning

```hcl
source = "github.com/prashantmj13/sfg-autoscaling?ref=v1.0.0"
```
