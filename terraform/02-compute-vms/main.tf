# ============================================================================
# Main Configuration
# ============================================================================
# This configuration creates VM instances in the Shared VPC created by
# the 01-folders-and-projects configuration.
#
# Projects are automatically discovered using label filtering - no need to
# manually specify project IDs! The data sources in data.tf find projects
# based on the labels set in 01-folders-and-projects.
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
