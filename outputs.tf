/*
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

output "mlflow_db_password" {
  description = "Generated password for the MLflow Postgres user (used by create-db-secret.sh)."
  value       = random_password.mlflow_db_password.result
  sensitive   = true
}

output "mlflow_static_ip" {
  description = "Static public IP of the MLflow HTTPS load balancer."
  value       = google_compute_global_address.mlflow_ip.address
}

output "mlflow_domain" {
  description = "nip.io domain for MLflow (use this in your browser once the cert is provisioned)."
  value       = local.mlflow_domain
}

output "mlflow_iap_client_id" {
  description = "IAP OAuth client ID (used by k8s/setup-ingress.sh)."
  value       = google_iap_client.mlflow.client_id
  sensitive   = true
}

output "mlflow_iap_client_secret" {
  description = "IAP OAuth client secret (used by k8s/setup-ingress.sh)."
  value       = google_iap_client.mlflow.secret
  sensitive   = true
}
*/
