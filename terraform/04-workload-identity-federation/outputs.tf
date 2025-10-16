output "workload_identity_provider" {
  description = "Workload Identity Provider resource name (use in GitHub Actions)"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "project_number" {
  description = "Google Cloud project number"
  value       = data.google_project.project.number
}

output "project_id" {
  description = "Google Cloud project ID"
  value       = var.project_id
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository for Docker images"
  value       = google_artifact_registry_repository.docker.name
}

output "artifact_registry_location" {
  description = "Artifact Registry repository location"
  value       = google_artifact_registry_repository.docker.location
}

output "docker_repository_url" {
  description = "Full Docker repository URL for pushing images"
  value       = "${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.name}"
}

output "github_actions_config" {
  description = "Configuration for GitHub Actions workflow"
  value = {
    workload_identity_provider = google_iam_workload_identity_pool_provider.github.name
    service_account           = "Not used - using direct principal authentication"
    project_id                = var.project_id
    region                    = var.region
    docker_registry           = "${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.name}"
  }
}

output "instructions" {
  description = "Next steps for GitHub Actions setup"
  value       = <<-EOT

    Workload Identity Federation configured successfully!

    Add these secrets to your GitHub repository:
    (Settings → Secrets and variables → Actions)

    GCP_PROJECT_ID:
      ${var.project_id}

    GCP_WORKLOAD_IDENTITY_PROVIDER:
      ${google_iam_workload_identity_pool_provider.github.name}

    Optional (for convenience):
    GCP_REGION:
      ${var.region}

    GCP_DOCKER_REGISTRY:
      ${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.name}

    Example GitHub Actions workflow snippet:
    ---
    - uses: google-github-actions/auth@v2
      with:
        workload_identity_provider: $${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
        project_id: $${{ secrets.GCP_PROJECT_ID }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2

    - name: Configure Docker for Artifact Registry
      run: gcloud auth configure-docker ${google_artifact_registry_repository.docker.location}-docker.pkg.dev

    - name: Build and push Docker image
      run: |
        docker build -t ${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.name}/myapp:$${{ github.sha }} .
        docker push ${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.name}/myapp:$${{ github.sha }}

    - name: Deploy to Cloud Run
      run: |
        gcloud run deploy myapp \
          --image=${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.name}/myapp:$${{ github.sha }} \
          --region=${var.region}

  EOT
}
