output "cluster_name" {
  value = google_container_cluster.this.name
}

output "location" {
  value = google_container_cluster.this.location
}

output "endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}

output "get_credentials" {
  description = "Run this to get a kubeconfig (from an authorized network)."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --region ${var.region} --project ${var.project_id}"
}
