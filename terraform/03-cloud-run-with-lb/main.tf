terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ============================================================================
# Cloud Run Service
# ============================================================================

resource "google_cloud_run_v2_service" "hello" {
  name     = var.service_name
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Make the service publicly accessible
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.hello.name
  location = google_cloud_run_v2_service.hello.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ============================================================================
# Serverless Network Endpoint Group (NEG)
# ============================================================================

resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  name                  = "${var.service_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.hello.name
  }
}

# ============================================================================
# Backend Service
# ============================================================================

resource "google_compute_backend_service" "default" {
  name                  = "${var.service_name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_region_network_endpoint_group.cloudrun_neg.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# ============================================================================
# URL Map
# ============================================================================

resource "google_compute_url_map" "default" {
  name            = "${var.service_name}-url-map"
  default_service = google_compute_backend_service.default.id
}

# ============================================================================
# HTTP(S) Target Proxy
# ============================================================================

# Option 1: HTTP Target Proxy (simple, no SSL)
resource "google_compute_target_http_proxy" "default" {
  name    = "${var.service_name}-http-proxy"
  url_map = google_compute_url_map.default.id
}

# Option 2: HTTPS Target Proxy (requires SSL certificate)
# Uncomment this and comment out the HTTP proxy above if you have a certificate
#
# resource "google_compute_target_https_proxy" "default" {
#   name             = "${var.service_name}-https-proxy"
#   url_map          = google_compute_url_map.default.id
#   ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
# }
#
# resource "google_compute_managed_ssl_certificate" "default" {
#   name = "${var.service_name}-cert"
#
#   managed {
#     domains = [var.domain_name]
#   }
# }

# ============================================================================
# Global Forwarding Rule
# ============================================================================

# Reserve a static external IP
resource "google_compute_global_address" "default" {
  name         = "${var.service_name}-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# HTTP Forwarding Rule
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.service_name}-http-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
  ip_address            = google_compute_global_address.default.id
}

# HTTPS Forwarding Rule (if using HTTPS proxy)
# Uncomment if using HTTPS target proxy above
#
# resource "google_compute_global_forwarding_rule" "https" {
#   name                  = "${var.service_name}-https-rule"
#   ip_protocol           = "TCP"
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   port_range            = "443"
#   target                = google_compute_target_https_proxy.default.id
#   ip_address            = google_compute_global_address.default.id
# }
