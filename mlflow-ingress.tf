/*
# IAP-protected HTTPS ingress for MLflow.
# Traffic path: internet → static IP → GCP HTTPS LB → IAP (Google login)
#               → GKE Ingress → MLflow Service → pod

resource "google_project_service" "iap" {
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}

# --- Static global IP — stable address for the HTTPS load balancer ---

resource "google_compute_global_address" "mlflow_ip" {
  name = "mlflow-ingress-ip"
}

locals {
  # nip.io maps <ip>.nip.io → <ip>, dots replaced with dashes in the subdomain
  mlflow_ip_dashed = replace(google_compute_global_address.mlflow_ip.address, ".", "-")
  mlflow_domain    = "${local.mlflow_ip_dashed}.nip.io"
}

# --- IAP OAuth brand (one per project, cannot be deleted once created) ---

resource "google_iap_brand" "mlflow" {
  support_email     = var.budget_alert_emails[0]
  application_title = "MLflow"
  project           = var.project_id

  depends_on = [google_project_service.iap]
}

# --- IAP OAuth client — credentials the GKE BackendConfig will use ---

resource "google_iap_client" "mlflow" {
  display_name = "MLflow IAP Client"
  brand        = google_iap_brand.mlflow.name
}

# --- Grant your account access through IAP ---

resource "google_project_iam_member" "mlflow_iap_user" {
  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  member  = "user:${var.budget_alert_emails[0]}"
}
*/
