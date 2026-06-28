# sfg-autoscaling

Terraform module for deploying IBM Sterling File Gateway (SFG) on GCP using a CIS Level 2-compliant Regional Managed Instance Group (MIG) with autoscaling.

## Features

- Regional MIG spread across all zones in the region (HA)
- CPU-based autoscaling with configurable min/max replicas
- CIS Level 2 Shielded VM (Secure Boot, vTPM, Integrity Monitoring)
- CMEK boot disk encryption (CIS 4.7)
- No public IP on instances (CIS 4.9)
- OS Login enabled, project-wide SSH keys blocked (CIS 4.3, 4.4)
- Serial port access disabled (CIS 4.5)
- Dedicated non-default service account (CIS 4.1)
- Firewall rules with full logging (CIS 3.8)
- Startup script: installs Java 11, downloads SFG from GCS, configures and starts SFG

## Usage

```hcl
module "sfg_asg" {
  source = "github.com/org/sfg-autoscaling?ref=v1.0.0"

  project_id         = "my-project"
  region             = "us-central1"
  network            = "projects/host/global/networks/shared-vpc"
  subnetwork         = "projects/host/regions/us-central1/subnetworks/app-subnet"
  kms_key            = "projects/my-project/locations/us-central1/keyRings/sfg-kr/cryptoKeys/sfg-key/cryptoKeyVersions/1"
  gcs_bucket         = "sfg-installers"
  gcs_installer_path = "sfg/sfg-installer-6.2.zip"
  min_replicas       = 2
  max_replicas       = 10
}
```

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
| kms_key | Cloud KMS CryptoKey version self-link | string | — | yes |
| gcs_bucket | GCS bucket with SFG installer | string | — | yes |
| gcs_installer_path | Object path to SFG installer ZIP | string | — | yes |
| name_prefix | Resource name prefix | string | "sfg" | no |
| machine_type | Compute Engine machine type | string | "n2-standard-4" | no |
| boot_disk_image | Boot disk image | string | debian-12 | no |
| boot_disk_size_gb | Boot disk size in GB | number | 100 | no |
| boot_disk_type | Disk type (pd-ssd or pd-balanced) | string | "pd-ssd" | no |
| min_replicas | Minimum MIG size | number | 2 | no |
| max_replicas | Maximum MIG size | number | 10 | no |
| cpu_utilization_target | Autoscaler CPU target (0.0–1.0) | number | 0.60 | no |
| cooldown_period | Autoscaler cooldown in seconds | number | 300 | no |
| sfg_port | SFG application port | number | 8443 | no |
| sfg_install_dir | SFG install path on VM | string | "/opt/sfg" | no |
| service_account_id | SA account ID | string | "sfg-vm-sa" | no |
| additional_sa_roles | Extra IAM roles for the SA | list(string) | [] | no |
| internal_cidr_ranges | VPC CIDRs allowed to reach SFG port | list(string) | [] | no |
| enable_secure_boot | Shielded VM Secure Boot | bool | true | no |
| enable_vtpm | Shielded VM vTPM | bool | true | no |
| enable_integrity_monitoring | Shielded VM integrity monitoring | bool | true | no |
| enable_confidential_vm | Confidential Computing (requires N2D) | bool | false | no |
| auto_healing_initial_delay_sec | Seconds before auto-healing starts | number | 300 | no |
| health_check_request_path | Health check HTTP path | string | "/health" | no |
| labels | Additional resource labels | map(string) | {} | no |

## Outputs

| Name | Description |
|---|---|
| instance_group_url | MIG instance group URL — pass to sfg-load-balancer |
| instance_group_manager_id | MIG manager resource ID |
| service_account_email | SFG VM service account email |
| instance_template_id | Current instance template self-link |
| health_check_id | Auto-healing health check self-link |
| named_port | Named port object (name + port number) |
| network_tag | Network tag on SFG VM instances |

## CIS Level 2 Controls

| CIS Benchmark | Control | Implementation |
|---|---|---|
| 4.1 | Non-default service account | Dedicated SA; not compute default |
| 4.3 | Block project-wide SSH keys | `block-project-ssh-keys = TRUE` |
| 4.4 | Enable OS Login | `enable-oslogin = TRUE` |
| 4.5 | Disable serial port | `serial-port-enable = FALSE` |
| 4.7 | CMEK disk encryption | `disk_encryption_key.kms_key_self_link` |
| 4.8 | Shielded VM | Secure Boot + vTPM + Integrity Monitoring |
| 4.9 | No public IP | No `access_config {}` in network_interface |
| 3.8 | Firewall logging | `log_config.metadata = INCLUDE_ALL_METADATA` |

## Versioning

Pin to a tag in the `source` URL:

```hcl
source = "github.com/org/sfg-autoscaling?ref=v1.0.0"
```

Run `terraform init -upgrade` after bumping the ref.

## Startup Script

The startup script (`startup_script.sh.tpl`) is rendered via `templatefile()` at plan time. It:

1. Installs Java 11 JDK and Google Cloud CLI
2. Reads instance name, zone, and private IP from the GCE metadata server
3. Downloads the SFG installer ZIP from GCS using `gcloud storage cp`
4. Runs a silent install
5. Writes `sandbox.cfg` with instance-specific values
6. Starts the SFG service

Logs are written to `/var/log/sfg-startup.log`. If startup fails, `set -euo pipefail` ensures the script exits non-zero, GCP health checks fail, and auto-healing replaces the instance.
