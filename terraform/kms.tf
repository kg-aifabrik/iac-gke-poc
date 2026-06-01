data "google_project" "this" {
  project_id = var.project_id
}

# Ensure the GKE service agent (robot) exists so we can grant it KMS access.
resource "google_project_service_identity" "gke" {
  provider = google-beta
  project  = var.project_id
  service  = "container.googleapis.com"
}

resource "google_kms_key_ring" "gke" {
  name     = "${var.cluster_name}-gke"
  location = var.region
}

resource "google_kms_crypto_key" "secrets" {
  name     = "secrets"
  key_ring = google_kms_key_ring.gke.id
  # Allow Terraform to destroy the key during POC teardown.
  lifecycle {
    prevent_destroy = false
  }
}

# GKE robot needs encrypt/decrypt on the key for application-layer secrets encryption.
resource "google_kms_crypto_key_iam_member" "gke_secrets" {
  crypto_key_id = google_kms_crypto_key.secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.gke.email}"
}
