# ============================================================================
# Compute Instances
# ============================================================================

# VM in Service Project 1
resource "google_compute_instance" "vm_service1" {
  project      = data.google_project.stage_service1.project_id
  name         = "vm-service1"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork_project = data.google_project.stage_host.project_id
    subnetwork         = data.google_compute_subnetwork.stage_subnet.id
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    environment = "stage"
    service     = "service1"
  }
}

# VM in Service Project 2
resource "google_compute_instance" "vm_service2" {
  project      = data.google_project.stage_service2.project_id
  name         = "vm-service2"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork_project = data.google_project.stage_host.project_id
    subnetwork         = data.google_compute_subnetwork.stage_subnet.id
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    environment = "stage"
    service     = "service2"
  }
}
