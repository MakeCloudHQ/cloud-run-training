variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Region for Cloud Run service"
  type        = string
  default     = "europe-west2"
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "hello-lb"
}

variable "domain_name" {
  description = "Domain name for SSL certificate (e.g., api.example.com)"
  type        = string
}
