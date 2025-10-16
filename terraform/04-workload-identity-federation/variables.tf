variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Region for resources"
  type        = string
  default     = "europe-west2"
}

variable "pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-actions-pool"
}

variable "provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-oidc-provider"
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = "MakeCloudHQ/cloud-run-training"
}

variable "artifact_registry_repository" {
  description = "Artifact Registry repository name for Docker images"
  type        = string
  default     = "cloud-run-images"
}
