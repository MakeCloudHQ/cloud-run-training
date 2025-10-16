output "random_suffix" {
  description = "The random 4-character hex suffix used for project IDs"
  value       = random_id.suffix.hex
}

output "folder_ids" {
  description = "Map of folder IDs by environment"
  value       = local.folder_ids
}

output "dev_folder_id" {
  description = "The ID of the Development folder"
  value       = local.folder_ids.dev
}

output "stage_folder_id" {
  description = "The ID of the Staging folder"
  value       = local.folder_ids.stage
}

output "prod_folder_id" {
  description = "The ID of the Production folder"
  value       = local.folder_ids.prod
}

output "dev_project_id" {
  description = "The project ID of the development project"
  value       = module.project_dev.project_id
}

output "stage_host_project_id" {
  description = "The project ID of the staging Shared VPC host project"
  value       = module.project_stage_host.project_id
}

output "stage_service1_project_id" {
  description = "The project ID of the staging service project 1"
  value       = module.project_stage_service1.project_id
}

output "stage_service2_project_id" {
  description = "The project ID of the staging service project 2"
  value       = module.project_stage_service2.project_id
}

output "prod_project_id" {
  description = "The project ID of the production project"
  value       = module.project_prod.project_id
}

output "dev_project_number" {
  description = "The project number of the development project"
  value       = module.project_dev.project_number
}

output "stage_host_project_number" {
  description = "The project number of the staging host project"
  value       = module.project_stage_host.project_number
}

output "stage_service1_project_number" {
  description = "The project number of staging service project 1"
  value       = module.project_stage_service1.project_number
}

output "stage_service2_project_number" {
  description = "The project number of staging service project 2"
  value       = module.project_stage_service2.project_number
}

output "prod_project_number" {
  description = "The project number of the production project"
  value       = module.project_prod.project_number
}

output "network_name" {
  description = "The name of the Shared VPC network"
  value       = module.stage_shared_vpc.network_name
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = module.stage_shared_vpc.subnets["europe-west2/stage-subnet"].name
}

output "summary" {
  description = "Summary of created resources"
  value = {
    folders = local.folder_ids
    projects = {
      dev            = module.project_dev.project_id
      stage_host     = module.project_stage_host.project_id
      stage_service1 = module.project_stage_service1.project_id
      stage_service2 = module.project_stage_service2.project_id
      prod           = module.project_prod.project_id
    }
    network = {
      name   = module.stage_shared_vpc.network_name
      subnet = module.stage_shared_vpc.subnets["europe-west2/stage-subnet"].name
    }
    suffix = random_id.suffix.hex
  }
}
