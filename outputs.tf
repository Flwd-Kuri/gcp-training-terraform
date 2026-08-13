output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "subnet_name" {
  value = google_compute_subnetwork.gke_subnet.name
}

output "gke_cluster_name" {
  value = google_container_cluster.autopilot.name
}

output "gke_cluster_endpoint" {
  value     = google_container_cluster.autopilot.endpoint
  sensitive = true
}

output "get_credentials_command" {
  description = "Run this to configure kubectl against the new cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.autopilot.name} --region ${var.region} --project ${var.project_id}"
}

output "mlflow_workload_gsa_email" {
  description = "Email of the MLflow Google service account (goes into k8s/01-serviceaccount.yaml)."
  value       = google_service_account.mlflow_workload.email
}

output "mlflow_db_private_ip" {
  description = "Private IP of the MLflow Cloud SQL instance (goes into k8s/02-deployment.yaml)."
  value       = google_sql_database_instance.mlflow_pg.private_ip_address
}

output "mlflow_artifact_bucket" {
  description = "GCS bucket name for MLflow artifacts (goes into k8s/02-deployment.yaml)."
  value       = google_storage_bucket.mlflow_artifacts.name
}
