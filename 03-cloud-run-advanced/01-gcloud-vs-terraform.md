# gcloud vs Terraform

Understanding when and how to use different tools for managing Cloud Run services.

## Overview

You have two main approaches to managing Cloud Run infrastructure:

1. **gcloud CLI** - Imperative commands
2. **Terraform** - Declarative infrastructure as code

Both have their place. Let's explore when to use each.

## gcloud CLI Approach

### Pros

**Quick and Simple:**
```bash
gcloud run deploy my-service \
    --image=gcr.io/my-project/my-image \
    --region=us-central1
```
One command, service deployed.

**Great for:**
- Learning and experimentation
- Quick prototypes
- One-off deployments
- Local development
- Debugging and troubleshooting

**Interactive:**
- Prompts for missing info
- Immediate feedback
- Easy to iterate

**No additional tools needed:**
- Just `gcloud` CLI
- No state management
- No configuration files (optional)

### Cons

**Not Repeatable:**
- Hard to recreate exact configuration
- No version history
- Manual process

**Difficult to Review:**
- No code review for changes
- Hard to track what changed
- No diff before applying

**Doesn't Scale:**
- Managing 10+ services gets messy
- No dependencies between resources
- Hard to coordinate changes

### gcloud Best Practices

**1. Use Configuration Files:**

Instead of long commands, use YAML:

```yaml
# service.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: my-service
spec:
  template:
    spec:
      containers:
      - image: gcr.io/my-project/my-image:latest
        env:
        - name: ENVIRONMENT
          value: production
        resources:
          limits:
            memory: 512Mi
            cpu: "1"
```

Deploy:
```bash
gcloud run services replace service.yaml --region=us-central1
```

**Benefits:**
- Configuration in version control
- More maintainable
- Can generate/template
- Easier to review

**2. Script Common Operations:**

```bash
#!/bin/bash
# deploy.sh

SERVICE_NAME="my-service"
REGION="us-central1"
IMAGE="gcr.io/my-project/my-image:$1"

gcloud run deploy $SERVICE_NAME \
    --image=$IMAGE \
    --region=$REGION \
    --memory=512Mi \
    --cpu=1 \
    --max-instances=10 \
    --set-env-vars=ENVIRONMENT=production
```

**3. Use Environment-Specific Configs:**

```
configs/
  ├── dev.yaml
  ├── staging.yaml
  └── prod.yaml
```

```bash
gcloud run services replace configs/$ENV.yaml
```

## Terraform Approach

### Pros

**Declarative:**
```hcl
resource "google_cloud_run_service" "my_service" {
  name     = "my-service"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/my-project/my-image:latest"
      }
    }
  }
}
```

You describe desired state, Terraform makes it happen.

**Repeatable:**
- Exact configuration in code
- Can recreate from scratch
- Version controlled

**Team-Friendly:**
- Code review changes
- Plan before apply
- Clear change history

**Handles Dependencies:**
- Resources depend on each other
- Terraform determines order
- Manages related resources (IAM, VPC, etc.)

**State Management:**
- Tracks what's deployed
- Detects drift
- Safe updates

**Great for:**
- Production environments
- Multi-service applications
- Team collaboration
- Complex infrastructures
- Compliance/audit requirements

### Cons

**More Complex:**
- Learn Terraform syntax
- Understand state management
- Setup required

**Slower Iteration:**
- Plan → Review → Apply cycle
- More ceremony for simple changes

**State Management:**
- Need remote state storage
- State locking
- Potential for conflicts

### Terraform Example

**Basic Service:**

```hcl
# main.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "image_tag" {
  description = "Container image tag"
  type        = string
  default     = "latest"
}

# Cloud Run Service
resource "google_cloud_run_service" "api" {
  name     = "my-api"
  location = var.region

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "10"
        "autoscaling.knative.dev/minScale" = "1"
      }
    }

    spec {
      container_concurrency = 80
      timeout_seconds      = 300

      containers {
        image = "gcr.io/${var.project_id}/my-api:${var.image_tag}"

        env {
          name  = "ENVIRONMENT"
          value = "production"
        }

        resources {
          limits = {
            memory = "512Mi"
            cpu    = "1"
          }
        }
      }

      service_account_name = google_service_account.api_sa.email
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Service Account
resource "google_service_account" "api_sa" {
  account_id   = "my-api-sa"
  display_name = "Service Account for My API"
}

# Allow public access
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.api.name
  location = google_cloud_run_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Output the URL
output "service_url" {
  value = google_cloud_run_service.api.status[0].url
}
```

**Deploy:**
```bash
terraform init
terraform plan -var="project_id=my-project"
terraform apply -var="project_id=my-project"
```

### Terraform Best Practices

**1. Use Modules:**

```hcl
# modules/cloud-run-service/main.tf
resource "google_cloud_run_service" "service" {
  name     = var.service_name
  location = var.region
  # ... configuration
}

# In root main.tf
module "api_service" {
  source = "./modules/cloud-run-service"

  service_name = "my-api"
  region       = "us-central1"
  image        = "gcr.io/my-project/api:latest"
}

module "worker_service" {
  source = "./modules/cloud-run-service"

  service_name = "my-worker"
  region       = "us-central1"
  image        = "gcr.io/my-project/worker:latest"
}
```

**2. Environment-Specific Workspaces:**

```bash
terraform workspace new prod
terraform workspace new staging
terraform workspace new dev

terraform workspace select prod
terraform apply -var-file="prod.tfvars"
```

**3. Remote State:**

```hcl
terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "cloud-run/prod"
  }
}
```

**4. Use Variables and Locals:**

```hcl
# variables.tf
variable "environment" {
  type = string
}

variable "services" {
  type = map(object({
    image       = string
    memory      = string
    cpu         = string
    min_instances = number
    max_instances = number
  }))
}

# terraform.tfvars
environment = "production"

services = {
  api = {
    image         = "gcr.io/my-project/api:v1.2.0"
    memory        = "512Mi"
    cpu           = "1"
    min_instances = 1
    max_instances = 10
  }
  worker = {
    image         = "gcr.io/my-project/worker:v1.2.0"
    memory        = "1Gi"
    cpu           = "2"
    min_instances = 0
    max_instances = 5
  }
}

# main.tf
resource "google_cloud_run_service" "services" {
  for_each = var.services

  name     = "${each.key}-${var.environment}"
  location = var.region

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = each.value.max_instances
        "autoscaling.knative.dev/minScale" = each.value.min_instances
      }
    }

    spec {
      containers {
        image = each.value.image

        resources {
          limits = {
            memory = each.value.memory
            cpu    = each.value.cpu
          }
        }
      }
    }
  }
}
```

## Hybrid Approach

You can combine both:

### Pattern 1: Terraform for Infrastructure, gcloud for Deployments

**Terraform:** Create service, IAM, VPC, etc. (static infrastructure)
**gcloud:** Update container image (frequent deployments)

```hcl
# Terraform creates the service
resource "google_cloud_run_service" "api" {
  name     = "my-api"
  location = "us-central1"

  template {
    spec {
      containers {
        # Use a placeholder or ignore changes
        image = "gcr.io/my-project/api:latest"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].image,
      template[0].metadata[0].annotations["client.knative.dev/user-image"],
    ]
  }
}
```

Then deploy with gcloud:
```bash
gcloud run deploy my-api \
    --image=gcr.io/my-project/api:v1.2.3 \
    --region=us-central1
```

Terraform won't revert the image change.

### Pattern 2: service.yaml + Terraform for Other Resources

**service.yaml:** Cloud Run service configuration
**Terraform:** VPC, IAM, Cloud SQL, etc.

```bash
# Deploy service
gcloud run services replace service.yaml

# Manage other infrastructure
terraform apply
```

## Decision Matrix

| Scenario | Recommendation | Why |
|----------|---------------|-----|
| Learning Cloud Run | **gcloud** | Faster feedback, simpler |
| Single service, small team | **gcloud + YAML** | Good balance |
| Multiple services | **Terraform** | Manage dependencies |
| Production, team of 3+ | **Terraform** | Code review, repeatability |
| CI/CD deployments | **Both** | Terraform for infra, gcloud/YAML for deploys |
| Compliance/audit needs | **Terraform** | Change tracking, approvals |
| Quick experiment | **gcloud** | Fastest path |
| Complex infrastructure | **Terraform** | Handle dependencies |

## CI/CD Integration

### With gcloud (GitHub Actions example)

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy my-service \
            --source=. \
            --region=us-central1 \
            --allow-unauthenticated
```

### With Terraform (GitHub Actions example)

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: hashicorp/setup-terraform@v2

      - uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        run: terraform apply tfplan
```

## Managing service.yaml with Either Approach

Both approaches can use the Knative service.yaml format:

**gcloud:**
```bash
gcloud run services replace service.yaml
```

**Terraform:**
```hcl
resource "google_cloud_run_service" "service" {
  name     = "my-service"
  location = "us-central1"

  metadata {
    annotations = yamldecode(file("service.yaml")).metadata.annotations
  }

  # Or generate from YAML entirely
}
```

Or use `kubectl` (since Cloud Run is Knative-compatible):
```bash
kubectl apply -f service.yaml
```

## Key Takeaways

- **gcloud**: Fast, simple, great for learning and prototyping
- **Terraform**: Repeatable, team-friendly, production-ready
- **Hybrid**: Use both - Terraform for infrastructure, gcloud for frequent deployments
- **Start simple**: Begin with gcloud, graduate to Terraform as needs grow
- **YAML configs**: Use service.yaml for version control with either approach
- **CI/CD**: Both work well in automated pipelines

## Recommendation for Your Team

For a professional team:

1. **Start with gcloud + YAML** for learning (today!)
2. **Move to Terraform** for production deployments
3. **Use hybrid approach** for frequent image updates
4. **Implement CI/CD** with either tool
5. **Document** your chosen approach for the team

---

Next: [VPC Networking →](./02-vpc-networking.md)
