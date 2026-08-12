# MLflow's storage layer: Cloud SQL (Postgres) for the tracking backend,
# GCS for artifacts, and Workload Identity so the MLflow pod authenticates
# to both without any downloaded key material.

resource "random_password" "mlflow_db_password" {
  length  = 24
  special = false # keep it URL-safe; it goes into a Postgres connection string
}

# --- Private Service Access: lets Cloud SQL live on a private IP inside
#     your VPC instead of being reachable over the public internet. This
#     is a one-time peering setup per VPC. ---

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.network_name}-sql-peering"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

# --- Cloud SQL (Postgres), private IP only, no public IP surface ---

resource "google_sql_database_instance" "mlflow_pg" {
  name             = "${var.gke_cluster_name}-mlflow-pg"
  database_version = "POSTGRES_15"
  region           = var.region

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = var.sql_tier

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled = true
    }
  }

  # Learning environment — flip to true once this holds data you'd
  # be upset to lose, same reasoning as deletion_protection on the GKE
  # cluster.
  deletion_protection = false
}

resource "google_sql_database" "mlflow" {
  name     = "mlflow"
  instance = google_sql_database_instance.mlflow_pg.name
}

resource "google_sql_user" "mlflow" {
  name     = "mlflow"
  instance = google_sql_database_instance.mlflow_pg.name
  password = random_password.mlflow_db_password.result
}

# --- GCS bucket for MLflow artifacts ---

resource "google_storage_bucket" "mlflow_artifacts" {
  name                        = "${var.project_id}-mlflow-artifacts"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true # learning env; flip off once it matters

  versioning {
    enabled = true
  }
}

# --- Workload Identity: a Google service account with just the roles
#     MLflow needs (GCS read/write on its bucket, Cloud SQL client),
#     bound to a Kubernetes service account so the pod can impersonate
#     it — no JSON key ever created or downloaded. ---

resource "google_service_account" "mlflow_workload" {
  account_id   = "mlflow-workload"
  display_name = "MLflow workload identity"
}

resource "google_storage_bucket_iam_member" "mlflow_bucket_access" {
  bucket = google_storage_bucket.mlflow_artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.mlflow_workload.email}"
}

resource "google_project_iam_member" "mlflow_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.mlflow_workload.email}"
}

# This is the binding that makes Workload Identity work: it tells GCP
# "the Kubernetes SA <ksa_name> in namespace <namespace>, in this
# project's GKE fleet, is allowed to act as this Google SA."
resource "google_service_account_iam_member" "mlflow_workload_identity_binding" {
  service_account_id = google_service_account.mlflow_workload.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "serviceAccount:${var.project_id}.svc.id.goog[${var.mlflow_namespace}/${var.mlflow_ksa_name}]"
}
