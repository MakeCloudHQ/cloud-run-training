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
  value       = "http://${google_compute_global_address.default.address}"
}

output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.default.name
}

output "neg_name" {
  description = "Name of the serverless NEG"
  value       = google_compute_region_network_endpoint_group.cloudrun_neg.name
}

output "instructions" {
  description = "Next steps"
  value       = <<-EOT

    Cloud Run Service deployed successfully!

    Direct access (via Cloud Run):
      ${google_cloud_run_v2_service.hello.uri}

    Load Balancer access:
      http://${google_compute_global_address.default.address}

    Note: It may take 1-2 minutes for the load balancer to become fully operational.

    Test the load balancer:
      curl http://${google_compute_global_address.default.address}

    View load balancer in Console:
      https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers

  EOT
}
