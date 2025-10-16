variable "parent" {
  description = "Parent for the folders. Can be either 'organizations/123456789' or 'folders/123456789'"
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent))
    error_message = "Parent must be in format 'organizations/123456789' or 'folders/123456789'."
  }
}

variable "org_id" {
  description = "The organization ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "Organization ID must be numeric."
  }
}

variable "billing_account_id" {
  description = "The ID of the billing account to associate with projects"
  type        = string

  validation {
    condition     = can(regex("^[A-F0-9]{6}-[A-F0-9]{6}-[A-F0-9]{6}$", var.billing_account_id))
    error_message = "Billing account ID must be in format XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "project_prefix" {
  description = "Prefix for project IDs (will be suffixed with environment and random ID)"
  type        = string
  default     = "my-app"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}$", var.project_prefix))
    error_message = "Project prefix must start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and be 5-28 characters long."
  }
}

variable "region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "europe-west2"
}
