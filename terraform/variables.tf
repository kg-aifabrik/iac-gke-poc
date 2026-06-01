variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Region for the regional cluster (multi-AZ)."
}

variable "zones" {
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
  description = "Zones used for node pools."
}

variable "cluster_name" {
  type    = string
  default = "poc"
}

variable "authorized_ipv4" {
  type        = string
  description = "Operator public IP in CIDR form, allowed to reach the public control-plane endpoint."
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}
