variable "project_id" {
  type = string
}

variable "host_project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "kms_key" {
  type        = string
  description = "Full self-link of the Cloud KMS CryptoKey version for disk encryption."
}

variable "gcs_bucket" {
  type        = string
  description = "GCS bucket containing the SFG installer."
}
