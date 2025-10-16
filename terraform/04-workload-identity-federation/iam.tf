# ============================================================================
# IAM Bindings for GitHub Actions via Workload Identity
# ============================================================================

# Principal set for the specific GitHub repository
locals {
  github_principal = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${var.pool_id}/attribute.repository/${var.github_repository}"
}

# ============================================================================
# Artifact Registry Permissions
# ============================================================================

# Allow pushing Docker images to Artifact Registry
resource "google_artifact_registry_repository_iam_member" "github_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.writer"
  member     = local.github_principal
}

# ============================================================================
# Cloud Run Permissions
# ============================================================================

# Allow deploying and managing Cloud Run services
resource "google_project_iam_member" "github_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = local.github_principal
}

# Allow acting as the Cloud Run service account
# (needed for deploying services with specific service accounts)
resource "google_project_iam_member" "github_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = local.github_principal
}

# ============================================================================
# Optional: Storage Admin for Cloud Build artifacts
# ============================================================================

# Uncomment if you need to access Cloud Build artifacts in GCS
# resource "google_project_iam_member" "github_storage_admin" {
#   project = var.project_id
#   role    = "roles/storage.admin"
#   member  = local.github_principal
# }
