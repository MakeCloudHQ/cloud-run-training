# Workload Identity Federation for GitHub Actions

Configure Workload Identity Federation to allow GitHub Actions to deploy to Cloud Run without service account keys.

## What This Creates

**Architecture:**
```
GitHub Actions → OIDC Token → Workload Identity Provider → Google Cloud
```

**Resources created:**
- Workload Identity Pool
- Workload Identity Provider (GitHub OIDC)
- Artifact Registry repository for Docker images
- IAM bindings for the GitHub repository principal:
  - `roles/artifactregistry.writer` - Push Docker images
  - `roles/run.admin` - Deploy Cloud Run services
  - `roles/iam.serviceAccountUser` - Act as service accounts

## Why Workload Identity Federation?

**Traditional approach (service account keys):**
- ❌ Long-lived credentials stored in GitHub secrets
- ❌ Security risk if keys are leaked
- ❌ Manual key rotation required
- ❌ Hard to audit and revoke

**Workload Identity Federation (this approach):**
- ✅ No long-lived credentials
- ✅ Short-lived tokens issued on-demand
- ✅ Automatic expiration (1 hour)
- ✅ Repository-specific access
- ✅ Easy to audit and revoke
- ✅ Google recommended best practice

## How It Works

1. **GitHub Actions runs** a workflow in your repository
2. **GitHub issues OIDC token** with claims about the workflow (repository, branch, etc.)
3. **Token sent to Google Cloud** via `google-github-actions/auth` action
4. **Google validates token** against Workload Identity Provider configuration
5. **Google issues short-lived access token** with permissions from IAM bindings
6. **GitHub Actions uses token** to push images and deploy services

## Prerequisites

- Terraform >= 1.0
- Google Cloud project with billing enabled
- GitHub repository: `MakeCloudHQ/cloud-run-training`
- APIs enabled:
  - IAM API: `gcloud services enable iam.googleapis.com`
  - Cloud Resource Manager API: `gcloud services enable cloudresourcemanager.googleapis.com`
  - IAM Credentials API: `gcloud services enable iamcredentials.googleapis.com`
  - Security Token Service API: `gcloud services enable sts.googleapis.com`
  - Artifact Registry API: `gcloud services enable artifactregistry.googleapis.com`
  - Cloud Run API: `gcloud services enable run.googleapis.com`
- Appropriate IAM permissions:
  - `roles/iam.workloadIdentityPoolAdmin`
  - `roles/iam.securityAdmin`
  - `roles/artifactregistry.admin`

## Usage

### Step 1: Enable Required APIs

```bash
gcloud services enable \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com
```

### Step 2: Configure Variables

Copy the example file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
project_id        = "my-project-id"
region            = "europe-west2"
github_repository = "MakeCloudHQ/cloud-run-training"
```

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Review the Plan

```bash
terraform plan
```

You should see resources to be created:
- Workload Identity Pool
- Workload Identity Provider
- Artifact Registry repository
- 3 IAM bindings (artifactregistry.writer, run.admin, iam.serviceAccountUser)

### Step 5: Apply

```bash
terraform apply
```

Type `yes` when prompted.

This takes about 1-2 minutes.

### Step 6: Configure GitHub Secrets

After `terraform apply` completes, you'll see output with the values you need.

**Add these to GitHub repository:**

1. Go to your GitHub repository: `https://github.com/MakeCloudHQ/cloud-run-training`
2. Navigate to **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Add the following secrets:

**Required secrets:**

| Secret Name | Value | How to Get |
|------------|-------|------------|
| `GCP_PROJECT_ID` | Your project ID | `terraform output -raw project_id` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Provider resource name | `terraform output -raw workload_identity_provider` |

**Optional secrets (for convenience):**

| Secret Name | Value | How to Get |
|------------|-------|------------|
| `GCP_REGION` | `europe-west2` | `terraform output -raw region` |
| `GCP_DOCKER_REGISTRY` | Artifact Registry URL | `terraform output -raw docker_repository_url` |

### Step 7: Create GitHub Actions Workflow

Create `.github/workflows/deploy.yml` in your repository:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches:
      - main

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: ${{ secrets.GCP_REGION || 'europe-west2' }}
  SERVICE_NAME: my-app
  REGISTRY: ${{ secrets.GCP_DOCKER_REGISTRY }}

jobs:
  deploy:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write  # Required for OIDC token

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          project_id: ${{ secrets.GCP_PROJECT_ID }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker for Artifact Registry
        run: |
          gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Build Docker image
        run: |
          docker build -t ${{ env.REGISTRY }}/${{ env.SERVICE_NAME }}:${{ github.sha }} .
          docker build -t ${{ env.REGISTRY }}/${{ env.SERVICE_NAME }}:latest .

      - name: Push Docker image
        run: |
          docker push ${{ env.REGISTRY }}/${{ env.SERVICE_NAME }}:${{ github.sha }}
          docker push ${{ env.REGISTRY }}/${{ env.SERVICE_NAME }}:latest

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy ${{ env.SERVICE_NAME }} \
            --image=${{ env.REGISTRY }}/${{ env.SERVICE_NAME }}:${{ github.sha }} \
            --region=${{ env.REGION }} \
            --platform=managed \
            --allow-unauthenticated
```

**Important:** Note the `permissions` section with `id-token: write` - this is required for OIDC!

### Step 8: Test the Workflow

1. Commit and push the workflow file to your repository
2. GitHub Actions will automatically run
3. Check the Actions tab to see the workflow execution
4. Verify that the service deploys successfully

## Configuration Details

### Attribute Mapping

The provider maps GitHub OIDC token claims to Google Cloud attributes:

```hcl
attribute_mapping = {
  "google.subject"       = "assertion.sub"           # Unique workflow identity
  "attribute.actor"      = "assertion.actor"         # GitHub user who triggered
  "attribute.repository" = "assertion.repository"    # GitHub repo (org/name)
  "attribute.aud"        = "assertion.aud"           # Audience claim
}
```

### Attribute Condition

Access is restricted to the specific repository:

```hcl
attribute_condition = "assertion.repository == 'MakeCloudHQ/cloud-run-training'"
```

This means **only workflows from this repository** can authenticate.

### Principal Set

The IAM bindings use a principal set that matches the repository:

```
principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/MakeCloudHQ/cloud-run-training
```

This grants permissions to **all workflows** in the repository, regardless of branch or user.

### Alternative: Restrict to Specific Branch

To only allow `main` branch, update `iam.tf`:

```hcl
locals {
  github_principal = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${var.pool_id}/attribute.repository/${var.github_repository}/attribute.ref/refs/heads/main"
}
```

And add to attribute mapping in `main.tf`:

```hcl
attribute_mapping = {
  # ... existing mappings ...
  "attribute.ref" = "assertion.ref"
}
```

## Permissions Granted

The GitHub Actions workflow has these permissions:

| Role | Purpose | Scope |
|------|---------|-------|
| `roles/artifactregistry.writer` | Push Docker images | Artifact Registry repository |
| `roles/run.admin` | Deploy and manage Cloud Run services | Project-wide |
| `roles/iam.serviceAccountUser` | Impersonate service accounts | Project-wide |

### Security Considerations

**Project-wide permissions:**
- `roles/run.admin` applies to ALL Cloud Run services in the project
- Consider using custom roles for production to limit scope

**Repository access:**
- Only `MakeCloudHQ/cloud-run-training` can authenticate
- Other repositories (even in same org) are blocked

**No service account:**
- No long-lived credentials to leak
- Tokens expire automatically after 1 hour

## Troubleshooting

### Authentication Failed

**Error:** `Failed to authenticate to Google Cloud using Workload Identity Federation`

**Check:**
1. Verify `id-token: write` permission in workflow
2. Confirm secrets are set correctly in GitHub
3. Verify attribute condition matches your repository
4. Check provider status: `gcloud iam workload-identity-pools providers describe github-oidc-provider --location=global --workload-identity-pool=github-actions-pool`

### Permission Denied

**Error:** `Permission denied` when pushing to Artifact Registry or deploying Cloud Run

**Check:**
1. Verify IAM bindings exist: `gcloud projects get-iam-policy PROJECT_ID`
2. Look for principal set in the output
3. Wait 1-2 minutes for IAM propagation
4. Test with: `gcloud auth print-access-token`

### Repository Mismatch

**Error:** `The provided token does not satisfy the condition`

**Check:**
1. Verify `github_repository` variable matches your actual repository
2. Format must be `owner/repo` (e.g., `MakeCloudHQ/cloud-run-training`)
3. Check provider attribute condition

### Token Expired

**Error:** `Token expired` during long workflows

**Solution:**
- Tokens last 1 hour by default
- Re-authenticate in long workflows:
```yaml
- name: Re-authenticate
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    project_id: ${{ secrets.GCP_PROJECT_ID }}
```

## Advanced Configuration

### Multiple Repositories

To allow multiple repositories, update the principal set in `iam.tf`:

```hcl
locals {
  github_repos = [
    "MakeCloudHQ/cloud-run-training",
    "MakeCloudHQ/another-repo"
  ]

  github_principals = [
    for repo in local.github_repos :
    "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${var.pool_id}/attribute.repository/${repo}"
  ]
}

# Update IAM bindings to use for_each
resource "google_project_iam_member" "github_run_admin" {
  for_each = toset(local.github_principals)
  project  = var.project_id
  role     = "roles/run.admin"
  member   = each.value
}
```

### Custom Role (Least Privilege)

Create a custom role instead of `roles/run.admin`:

```hcl
resource "google_project_iam_custom_role" "cloud_run_deployer" {
  role_id     = "cloudRunDeployer"
  title       = "Cloud Run Deployer"
  description = "Minimum permissions for deploying Cloud Run services"
  permissions = [
    "run.services.create",
    "run.services.update",
    "run.services.get",
    "run.services.list",
    "run.operations.get",
  ]
}

resource "google_project_iam_member" "github_custom_role" {
  project = var.project_id
  role    = google_project_iam_custom_role.cloud_run_deployer.id
  member  = local.github_principal
}
```

### Audit Logging

Enable audit logs for Workload Identity:

```hcl
resource "google_project_iam_audit_config" "workload_identity" {
  project = var.project_id
  service = "iamcredentials.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
```

View logs:
```bash
gcloud logging read "protoPayload.serviceName=iamcredentials.googleapis.com"
```

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Warning:** This will:
- Delete the Workload Identity Pool and Provider
- Remove IAM bindings
- **Delete the Artifact Registry repository and all images**
- Break existing GitHub Actions workflows

## Key Takeaways

- **No service account keys** - more secure than traditional approach
- **Short-lived tokens** - automatically expire after 1 hour
- **Repository-specific** - only specified repo can authenticate
- **Easy to revoke** - disable provider or delete pool
- **Google recommended** - best practice for CI/CD authentication
- **Principal sets** - grant permissions directly to federated identities

## References

- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)
- [Configuring Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)
