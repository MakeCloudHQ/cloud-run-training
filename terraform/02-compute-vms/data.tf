# ============================================================================
# Data Sources
# ============================================================================
# Look up existing resources created by 01-folders-and-projects

# Find the Shared VPC host project by labels
data "google_projects" "stage_host" {
  filter = "labels.environment:stage AND labels.vpc_type:shared-host"
}

# Find service project 1 by labels
data "google_projects" "stage_service1" {
  filter = "labels.environment:stage AND labels.vpc_type:shared-service AND labels.service:service1"
}

# Find service project 2 by labels
data "google_projects" "stage_service2" {
  filter = "labels.environment:stage AND labels.vpc_type:shared-service AND labels.service:service2"
}

# Extract project IDs
locals {
  stage_host_project_id     = data.google_projects.stage_host.projects[0].project_id
  stage_service1_project_id = data.google_projects.stage_service1.projects[0].project_id
  stage_service2_project_id = data.google_projects.stage_service2.projects[0].project_id
}

# Look up the VPC network
data "google_compute_network" "shared_vpc" {
  name    = var.network_name
  project = local.stage_host_project_id
}

# Look up the London subnet
data "google_compute_subnetwork" "london_subnet" {
  name    = "stage-subnet-london"
  region  = "europe-west2"
  project = local.stage_host_project_id
}

# Look up the Sydney subnet
data "google_compute_subnetwork" "sydney_subnet" {
  name    = "stage-subnet-sydney"
  region  = "australia-southeast1"
  project = local.stage_host_project_id
}
