project_id         = "project-778a4715-afd6-4c3d-aa4"
region             = "europe-west1"
billing_account_id = "011436-A36858-80D456"

budget_amount           = 100
budget_alert_thresholds = [0.5, 0.9, 1.0]
budget_alert_emails     = ["legallthib@gwanadoo.fr"]

network_name  = "mlops-vpc"
subnet_cidr   = "10.10.0.0/20"
pods_cidr     = "10.20.0.0/16"
services_cidr = "10.30.0.0/20"

gke_cluster_name = "mlops-autopilot"
