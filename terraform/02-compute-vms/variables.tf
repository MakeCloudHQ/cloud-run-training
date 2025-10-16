variable "stage_host_project_id" {
  description = "The project ID of the Shared VPC host project (e.g., my-app-stage-host-a3f9)"
  type        = string
}

variable "stage_service1_project_id" {
  description = "The project ID of the first service project (e.g., my-app-stage-svc1-a3f9)"
  type        = string
}

variable "stage_service2_project_id" {
  description = "The project ID of the second service project (e.g., my-app-stage-svc2-a3f9)"
  type        = string
}

variable "network_name" {
  description = "The name of the Shared VPC network"
  type        = string
  default     = "shared-vpc"
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "stage-subnet"
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "europe-west2"
}

variable "zone" {
  description = "Google Cloud zone for VMs"
  type        = string
  default     = "europe-west2-a"
}

variable "machine_type" {
  description = "Machine type for VMs"
  type        = string
  default     = "e2-micro"
}
