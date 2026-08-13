variable "project_id" {
  description = "GCP project ID where resources are created."
  type        = string
}

variable "region" {
  description = "Primary region for regional resources."
  type        = string
  default     = "europe-west1"
}

variable "billing_account_id" {
  description = "Billing account ID to attach the budget to (format XXXXXX-XXXXXX-XXXXXX)."
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget amount in the billing account's currency."
  type        = number
  default     = 100
}

variable "budget_alert_thresholds" {
  description = "Percentages of budget_amount at which alerts fire."
  type        = list(number)
  default     = [0.5, 0.9, 1.0]
}

variable "budget_alert_emails" {
  description = "Email addresses notified when a budget threshold is crossed."
  type        = list(string)
}

variable "network_name" {
  description = "Name of the custom VPC."
  type        = string
  default     = "mlops-vpc"
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE subnet."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range CIDR for pods (used by GKE VPC-native networking)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range CIDR for services (used by GKE VPC-native networking)."
  type        = string
  default     = "10.30.0.0/20"
}

variable "gke_cluster_name" {
  description = "Name of the GKE Autopilot cluster."
  type        = string
  default     = "mlops-autopilot"
}

variable "sql_tier" {
  description = "Cloud SQL machine tier for the MLflow Postgres instance."
  type        = string
  default     = "db-f1-micro"
}

variable "mlflow_namespace" {
  description = "Kubernetes namespace where MLflow is deployed."
  type        = string
  default     = "mlflow"
}

variable "mlflow_ksa_name" {
  description = "Kubernetes service account name used by the MLflow pod."
  type        = string
  default     = "mlflow"
}
