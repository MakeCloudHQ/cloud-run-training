# ============================================================================
# Main Configuration
# ============================================================================
# This configuration creates VM instances in the Shared VPC created by
# the 01-folders-and-projects configuration.
# It uses data sources to look up existing projects and network resources.
# ============================================================================

terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  # Authentication will use Application Default Credentials
  # Run: gcloud auth application-default login
}
