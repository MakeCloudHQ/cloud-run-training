# ============================================================================
# Outputs
# ============================================================================

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

output "subnet_info" {
  description = "Information about the subnet being used"
  value = {
    name       = data.google_compute_subnetwork.stage_subnet.name
    ip_range   = data.google_compute_subnetwork.stage_subnet.ip_cidr_range
    region     = data.google_compute_subnetwork.stage_subnet.region
    network    = data.google_compute_network.shared_vpc.name
    project    = data.google_project.stage_host.project_id
  }
}
