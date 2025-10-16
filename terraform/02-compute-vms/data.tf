# ============================================================================
# Data Sources
# ============================================================================
# Look up existing resources created by 01-folders-and-projects

# Look up the Shared VPC host project
data "google_project" "stage_host" {
  project_id = var.stage_host_project_id
}

# Look up the service projects
data "google_project" "stage_service1" {
  project_id = var.stage_service1_project_id
}

data "google_project" "stage_service2" {
  project_id = var.stage_service2_project_id
}

# Look up the VPC network
data "google_compute_network" "shared_vpc" {
  name    = var.network_name
  project = data.google_project.stage_host.project_id
}

# Look up the subnet
data "google_compute_subnetwork" "stage_subnet" {
  name    = var.subnet_name
  region  = var.region
  project = data.google_project.stage_host.project_id
}
