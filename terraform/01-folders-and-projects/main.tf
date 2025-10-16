# ============================================================================
# Main Configuration
# ============================================================================
# This file contains the Terraform configuration and provider setup.
# Resources are organized into separate files:
# - folders.tf: Folder hierarchy
# - projects.tf: Project creation
# - networking.tf: VPC, firewall rules, and VM instances
# ============================================================================

terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  # Authentication will use Application Default Credentials
  # Run: gcloud auth application-default login
}

# Generate a random 4-digit hex suffix for globally unique project IDs
resource "random_id" "suffix" {
  byte_length = 2 # 2 bytes = 4 hex characters
}
