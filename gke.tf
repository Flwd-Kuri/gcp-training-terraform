# GKE Autopilot inside the custom VPC. Autopilot manages node
# provisioning/scaling for you — see the conversation notes for why
# that's the right tradeoff at this stage (workload-level objects,
# which is what you're here to learn, are fully exposed regardless
# of Autopilot vs Standard).

resource "google_container_cluster" "autopilot" {
  provider = google-beta

  name     = var.gke_cluster_name
  location = var.region # Autopilot clusters are regional

  enable_autopilot = true

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke_subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Autopilot requires deletion_protection to be explicitly addressed;
  # false here for a learning environment you expect to tear down.
  deletion_protection = false

  release_channel {
    channel = "REGULAR"
  }
}
