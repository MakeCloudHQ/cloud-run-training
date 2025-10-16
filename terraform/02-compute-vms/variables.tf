variable "network_name" {
  description = "The name of the Shared VPC network"
  type        = string
  default     = "shared-vpc"
}

variable "machine_type" {
  description = "Machine type for VMs"
  type        = string
  default     = "e2-micro"
}
