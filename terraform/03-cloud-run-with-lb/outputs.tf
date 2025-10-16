output "cloud_run_url" {
  description = "Direct Cloud Run service URL"
  value       = google_cloud_run_v2_service.hello.uri
}

output "load_balancer_ip" {
  description = "External IP address of the load balancer"
  value       = google_compute_global_address.default.address
}

output "load_balancer_url" {
  description = "URL to access via load balancer"
  value       = "https://${var.domain_name}"
}

output "load_balancer_ip_url" {
  description = "URL to access via load balancer IP (for testing before DNS)"
  value       = "https://${google_compute_global_address.default.address}"
}

output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.default.name
}

output "neg_name" {
  description = "Name of the serverless NEG"
  value       = google_compute_region_network_endpoint_group.cloudrun_neg.name
}

output "ssl_certificate_status" {
  description = "SSL certificate provisioning status"
  value       = google_compute_managed_ssl_certificate.default.id
}

output "instructions" {
  description = "Next steps"
  value       = <<-EOT

    Cloud Run Service deployed successfully!

    IMPORTANT: Configure DNS before the SSL certificate will provision:
      Create an A record: ${var.domain_name} → ${google_compute_global_address.default.address}

    Direct access (via Cloud Run):
      ${google_cloud_run_v2_service.hello.uri}

    Load Balancer access (after DNS is configured):
      https://${var.domain_name}

    Note:
    - SSL certificate provisioning takes 15-60 minutes after DNS is configured
    - HTTP traffic on port 80 redirects to HTTPS
    - Check certificate status: gcloud compute ssl-certificates describe ${var.service_name}-cert --global

    View load balancer in Console:
      https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers

  EOT
}
