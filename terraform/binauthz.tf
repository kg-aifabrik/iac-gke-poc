# Binary Authorization — POC runs AUDIT-ONLY (D4 deferred to enforce).
# Default rule logs what *would* be denied without blocking deploys.
resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  default_admission_rule {
    evaluation_mode  = "ALWAYS_DENY"
    enforcement_mode = "DRYRUN_AUDIT_LOG_ONLY"
  }

  # Allow GKE/GCP system images so audit logs aren't noisy with platform pods.
  # NOTE: leading-wildcard domains (e.g. "*.pkg.dev/*") are rejected by BinAuthz;
  # patterns must start with a concrete registry domain.
  admission_whitelist_patterns {
    name_pattern = "gcr.io/*"
  }
  admission_whitelist_patterns {
    name_pattern = "gke.gcr.io/*"
  }
  admission_whitelist_patterns {
    name_pattern = "us-docker.pkg.dev/*"
  }
}
