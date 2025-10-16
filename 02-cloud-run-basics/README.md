# Cloud Run Basics

Hands-on introduction to deploying and managing Cloud Run services.

## Duration: 1 hour

## Learning Objectives

By the end of this section, you should be able to:
- Understand what Cloud Run is and when to use it
- Deploy a containerized application to Cloud Run
- Understand Cloud Run's key concepts: services, revisions, and traffic
- Configure basic Cloud Run settings
- Test and call your deployed service

## What is Cloud Run?

Cloud Run is a fully managed compute platform for deploying and scaling containerized applications quickly and securely.

**Key Features:**
- **Fully managed** - No infrastructure to manage
- **Containers** - Deploy any language/runtime that fits in a container
- **Auto-scaling** - From zero to thousands of instances automatically
- **Pay-per-use** - Only pay when requests are being processed
- **Built on Knative** - Open source, portable

**What makes Cloud Run special:**
- Scale to zero (no cost when idle)
- Scale up in seconds
- Built-in TLS/HTTPS
- Custom domains
- Easy to use

## When to Use Cloud Run

**Good for:**
- HTTP APIs and microservices
- Web applications
- Webhook handlers
- Async task processing (Cloud Tasks/Pub/Sub)
- Static site serving
- Serverless backends
- Event-driven architectures

**Consider alternatives if:**
- Need persistent local storage (use GKE or VMs)
- Tasks > 1 hour per request (use Cloud Run jobs or Compute Engine)
- Need specific OS/kernel features (use VMs)
- Require very specific networking setup (GKE might be better)

## Cloud Run Concepts

### Services
A service is your deployed application. One service = one container image.

**Properties:**
- URL (e.g., `https://my-service-abc123-uc.a.run.app`)
- Container image reference
- Configuration (memory, CPU, scaling, etc.)
- Region (where it runs)

### Revisions
Every deployment creates a new immutable revision.

- Snapshot of code + configuration
- Immutable (can't be changed)
- Can split traffic between revisions
- Automatically named with timestamp suffix

**Example:**
```
my-service-00001-abc
my-service-00002-def  ← Latest
```

### Traffic Splitting
Route traffic to different revisions.

**Use cases:**
- Blue/green deployments
- Canary releases (send 10% traffic to new version)
- Rollback (shift traffic back to old revision)

```bash
# 90% to old version, 10% to new (canary)
gcloud run services update-traffic my-service \
    --to-revisions=my-service-00002=10,my-service-00001=90
```

## Section Contents

1. [Hands-On Lab](./hands-on-lab.md) - Deploy your first Cloud Run service
2. [Core Concepts Deep Dive](./concepts.md) - Understanding Cloud Run architecture
3. [Sample Application](./sample-app/) - Simple app to deploy and experiment with

## Prerequisites

Before starting:
- Completed [setup instructions](../setup-instructions.md)
- `gcloud` installed and authenticated
- Docker installed
- Access to a Google Cloud project with billing enabled

## Quick Verification

Check your setup:
```bash
# Verify gcloud is configured
gcloud config list

# Verify Docker is running
docker ps

# Verify Cloud Run API is enabled
gcloud services list --enabled --filter="name:run.googleapis.com"

# If not enabled, run:
gcloud services enable run.googleapis.com
```

---

Let's get started with the [Hands-On Lab →](./hands-on-lab.md)
