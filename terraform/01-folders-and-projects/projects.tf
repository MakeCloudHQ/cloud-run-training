# ============================================================================
# Project Resources
# ============================================================================

# Development Project
module "project_dev" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 15.0"

  name              = "${var.project_prefix}-dev"
  random_project_id = false  # We're using our own random suffix
  project_id        = "${var.project_prefix}-dev-${random_id.suffix.hex}"
  folder_id         = local.folder_ids.dev
  billing_account   = var.billing_account_id

  # Enable default APIs
  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
  ]

  # Labels
  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }

  # Auto-create default network
  auto_create_network = true
}

# ============================================================================
# Staging: Shared VPC Projects
# ============================================================================

# Staging: Shared VPC Host Project
module "project_stage_host" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 15.0"

  name              = "${var.project_prefix}-stage-host"
  random_project_id = false
  project_id        = "${var.project_prefix}-stage-host-${random_id.suffix.hex}"
  folder_id         = local.folder_ids.stage
  billing_account   = var.billing_account_id

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
  ]

  labels = {
    environment = "stage"
    managed_by  = "terraform"
    vpc_type    = "shared-host"
  }

  auto_create_network           = false  # We'll create a custom network
  enable_shared_vpc_host_project = true  # Enable as Shared VPC host
}

# Staging: Service Project 1
module "project_stage_service1" {
  source  = "terraform-google-modules/project-factory/google//modules/svpc_service_project"
  version = "~> 15.0"

  name              = "${var.project_prefix}-stage-svc1"
  random_project_id = false
  project_id        = "${var.project_prefix}-stage-svc1-${random_id.suffix.hex}"
  org_id            = var.org_id
  folder_id         = local.folder_ids.stage
  billing_account   = var.billing_account_id

  shared_vpc         = module.project_stage_host.project_id
  shared_vpc_subnets = [
    "projects/${module.project_stage_host.project_id}/regions/europe-west2/subnetworks/stage-subnet-london",
    "projects/${module.project_stage_host.project_id}/regions/australia-southeast1/subnetworks/stage-subnet-sydney"
  ]

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
  ]

  labels = {
    environment = "stage"
    managed_by  = "terraform"
    vpc_type    = "shared-service"
    service     = "service1"
  }

  depends_on = [
    module.project_stage_host,
    module.stage_shared_vpc
  ]
}

# Staging: Service Project 2
module "project_stage_service2" {
  source  = "terraform-google-modules/project-factory/google//modules/svpc_service_project"
  version = "~> 15.0"

  name              = "${var.project_prefix}-stage-svc2"
  random_project_id = false
  project_id        = "${var.project_prefix}-stage-svc2-${random_id.suffix.hex}"
  org_id            = var.org_id
  folder_id         = local.folder_ids.stage
  billing_account   = var.billing_account_id

  shared_vpc         = module.project_stage_host.project_id
  shared_vpc_subnets = [
    "projects/${module.project_stage_host.project_id}/regions/europe-west2/subnetworks/stage-subnet-london",
    "projects/${module.project_stage_host.project_id}/regions/australia-southeast1/subnetworks/stage-subnet-sydney"
  ]

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
  ]

  labels = {
    environment = "stage"
    managed_by  = "terraform"
    vpc_type    = "shared-service"
    service     = "service2"
  }

  depends_on = [
    module.project_stage_host,
    module.stage_shared_vpc
  ]
}

# ============================================================================
# Production Project
# ============================================================================

module "project_prod" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 15.0"

  name              = "${var.project_prefix}-prod"
  random_project_id = false
  project_id        = "${var.project_prefix}-prod-${random_id.suffix.hex}"
  folder_id         = local.folder_ids.prod
  billing_account   = var.billing_account_id

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
  ]

  labels = {
    environment = "prod"
    managed_by  = "terraform"
  }

  auto_create_network = true
}
