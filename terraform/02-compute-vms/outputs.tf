# ============================================================================
# Outputs
# ============================================================================

output "discovered_projects" {
  description = "Projects discovered by label filtering"
  value = {
    host_project     = local.stage_host_project_id
    service1_project = local.stage_service1_project_id
    service2_project = local.stage_service2_project_id
  }
}

output "vm_service1_name" {
  description = "Name of VM in service project 1"
  value       = google_compute_instance.vm_service1.name
}

output "vm_service1_internal_ip" {
  description = "Internal IP of VM in service project 1"
  value       = google_compute_instance.vm_service1.network_interface[0].network_ip
}

output "vm_service2_name" {
  description = "Name of VM in service project 2"
  value       = google_compute_instance.vm_service2.name
}

output "vm_service2_internal_ip" {
  description = "Internal IP of VM in service project 2"
  value       = google_compute_instance.vm_service2.network_interface[0].network_ip
}

output "subnets_info" {
  description = "Information about the subnets being used"
  value = {
    london = {
      name     = data.google_compute_subnetwork.london_subnet.name
      ip_range = data.google_compute_subnetwork.london_subnet.ip_cidr_range
      region   = data.google_compute_subnetwork.london_subnet.region
    }
    sydney = {
      name     = data.google_compute_subnetwork.sydney_subnet.name
      ip_range = data.google_compute_subnetwork.sydney_subnet.ip_cidr_range
      region   = data.google_compute_subnetwork.sydney_subnet.region
    }
    network = data.google_compute_network.shared_vpc.name
    project = local.stage_host_project_id
  }
}
