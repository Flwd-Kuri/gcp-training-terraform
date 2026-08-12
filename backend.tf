# Remote state in GCS. Bucket + versioning are created manually once
# (see README "One-time manual bootstrap") — Terraform can't safely
# bootstrap the bucket it then stores its own state in.
#
# Bucket and prefix are passed at `terraform init` time via -backend-config
# flags (see README) so this file doesn't hardcode a project-specific name.

terraform {
  backend "gcs" {
    # bucket = "<PROJECT_ID>-tfstate"   # supplied via -backend-config
    # prefix = "terraform/state"        # supplied via -backend-config
  }
}
