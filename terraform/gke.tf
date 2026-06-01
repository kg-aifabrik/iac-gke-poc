# Minimal-privilege service account for nodes (no broad cloud roles; Workload Identity handles app auth).
resource "google_service_account" "nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE nodes (${var.cluster_name})"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region # regional => multi-AZ control plane (D3/HA)

  node_locations      = var.zones
  deletion_protection = false # POC: allow terraform destroy

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # Remove the default pool; we manage pools explicitly below.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = var.release_channel
  }

  # --- D7 GKE-native controls ---
  enable_shielded_nodes = true

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # public endpoint, restricted to authorized networks (POC)
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_ipv4
      display_name = "operator"
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  datapath_provider = "ADVANCED_DATAPATH" # Dataplane V2

  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.secrets.id
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE" # policy is audit-only (see binauthz.tf)
  }

  depends_on = [google_kms_crypto_key_iam_member.gke_secrets]
}

locals {
  node_common = {
    spot         = true
    image_type   = "COS_CONTAINERD"
    disk_size_gb = 50
    disk_type    = "pd-balanced"
  }
}

# 1) system pool — 1 zone, e2-small
resource "google_container_node_pool" "system" {
  provider       = google-beta
  name           = "system"
  cluster        = google_container_cluster.this.id
  node_locations = [var.zones[0]]

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  node_config {
    machine_type    = "e2-standard-2"
    spot            = local.node_common.spot
    image_type      = local.node_common.image_type
    disk_size_gb    = local.node_common.disk_size_gb
    disk_type       = local.node_common.disk_type
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    labels = { pool = "system" }
  }
}

# 2) general pool — 3 zones (multi-AZ workloads), e2-small
resource "google_container_node_pool" "general" {
  provider       = google-beta
  name           = "general"
  cluster        = google_container_cluster.this.id
  node_locations = var.zones

  autoscaling {
    min_node_count = 1
    max_node_count = 1
  }

  node_config {
    machine_type    = "e2-standard-2"
    spot            = local.node_common.spot
    image_type      = local.node_common.image_type
    disk_size_gb    = local.node_common.disk_size_gb
    disk_type       = local.node_common.disk_type
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    labels = { pool = "general", "data-class" = "non-sensitive" }
  }
}

# 3) confidential pool — AMD SEV (D1/D7), n2d, 1 zone, tainted for sensitive workloads
resource "google_container_node_pool" "confidential" {
  provider       = google-beta
  name           = "confidential"
  cluster        = google_container_cluster.this.id
  node_locations = [var.zones[0]]

  autoscaling {
    min_node_count = 1
    max_node_count = 1
  }

  node_config {
    machine_type    = "n2d-standard-2" # AMD SEV-capable
    spot            = false
    image_type      = local.node_common.image_type
    disk_size_gb    = local.node_common.disk_size_gb
    disk_type       = local.node_common.disk_type
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    confidential_nodes {
      enabled = true
    }
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    labels = { pool = "confidential", "data-class" = "sensitive" }
    taint {
      key    = "sensitive"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}
