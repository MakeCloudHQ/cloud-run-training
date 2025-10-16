# ============================================================================
# Compute Instances
# ============================================================================

# VM in Service Project 1 (London)
resource "google_compute_instance" "vm_service1" {
  project      = local.stage_service1_project_id
  name         = "vm-service1-london"
  machine_type = var.machine_type
  zone         = "europe-west2-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork_project = local.stage_host_project_id
    subnetwork         = data.google_compute_subnetwork.london_subnet.id
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    environment = "stage"
    service     = "service1"
    location    = "london"
  }
}

# VM in Service Project 2 (Sydney)
resource "google_compute_instance" "vm_service2" {
  project      = local.stage_service2_project_id
  name         = "vm-service2-sydney"
  machine_type = var.machine_type
  zone         = "australia-southeast1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork_project = local.stage_host_project_id
    subnetwork         = data.google_compute_subnetwork.sydney_subnet.id
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    environment = "stage"
    service     = "service2"
    location    = "sydney"
  }
}
