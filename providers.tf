terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Used only for APIs that require an explicit quota project (e.g. billingbudgets)
provider "google" {
  alias                 = "with_quota"
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}
