# ============================================================================
# Staging Shared VPC: Network Resources
# ============================================================================

# Create VPC network using terraform-google-modules/network/google
module "stage_shared_vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = module.project_stage_host.project_id
  network_name = "shared-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name   = "stage-subnet"
      subnet_ip     = "10.0.0.0/24"
      subnet_region = "europe-west2"
    }
  ]

  depends_on = [module.project_stage_host]
}

# Firewall rule: Allow ICMP (ping) between VMs
resource "google_compute_firewall" "stage_allow_icmp" {
  project = module.project_stage_host.project_id
  name    = "allow-icmp-internal"
  network = module.stage_shared_vpc.network_name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24"]
  priority      = 1000
}

# Firewall rule: Allow SSH from IAP (for troubleshooting)
resource "google_compute_firewall" "stage_allow_iap_ssh" {
  project = module.project_stage_host.project_id
  name    = "allow-iap-ssh"
  network = module.stage_shared_vpc.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP IP range
  source_ranges = ["35.235.240.0/20"]
  priority      = 1000
}
