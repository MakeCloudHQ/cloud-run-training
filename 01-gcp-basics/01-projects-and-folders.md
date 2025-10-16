# Projects and Folders

Understanding how GCP organizes resources is fundamental to working effectively with the platform.

## The Resource Hierarchy

GCP uses a hierarchical structure to organize resources:

```
Organization (optional)
    └── Folders (optional, can be nested)
        └── Projects (required)
            └── Resources (VMs, databases, Cloud Run services, etc.)
```

### Organization

- Represents your company/organization
- Root node of the hierarchy
- Requires Google Workspace or Cloud Identity
- Provides centralized control and visibility

**Key Benefits:**
- Organization-wide policies
- Centralized billing
- Consolidated audit logs
- Programmatic resource creation

### Folders

- Provide grouping mechanism for projects
- Can be nested (up to 10 levels deep)
- Useful for different teams, departments, or environments

**Common Patterns:**
```
Organization
    ├── Production Folder
    │   ├── Frontend Projects
    │   └── Backend Projects
    ├── Development Folder
    └── Shared Services Folder
```

### Projects

- **Required** container for all GCP resources
- Isolated container with its own permissions, billing, APIs
- Has unique project ID, project number, and project name

**Key Characteristics:**
- Every resource belongs to exactly one project
- Projects are independent (no resource sharing by default)
- Each project has its own billing account
- APIs must be enabled per-project

## Project Anatomy

Every project has three identifiers:

1. **Project Name**: Human-friendly, can be changed, not unique globally
   - Example: "Production Frontend"

2. **Project ID**: Unique globally, immutable after creation
   - Example: "prod-frontend-2024"
   - Used in gcloud commands and API calls

3. **Project Number**: Auto-generated, immutable, used by Google APIs
   - Example: "123456789012"

## Working with Projects

### In the Console

Navigate to: [console.cloud.google.com](https://console.cloud.google.com)

- **Project Selector**: Top bar - click to switch projects
- **Project Settings**: IAM & Admin > Settings
- **Project Dashboard**: Home page when project selected

### Using gcloud

```bash
# List all projects you have access to
gcloud projects list

# Get details about a specific project
gcloud projects describe PROJECT_ID

# Set default project for current session
gcloud config set project PROJECT_ID

# See current configuration
gcloud config list
```

### Creating a New Project

```bash
# Via gcloud
gcloud projects create PROJECT_ID \
    --name="My Project Name" \
    --folder=FOLDER_ID \
    --organization=ORG_ID

# Note: FOLDER_ID and ORG_ID are optional
```

In Console: Select project dropdown > "New Project"

## Resource Organization Best Practices

### 1. Environment Separation

**Recommended**: Separate projects for different environments

```
├── myapp-dev
├── myapp-staging
└── myapp-prod
```

**Benefits:**
- Isolation prevents accidents (can't delete prod from dev)
- Different IAM permissions per environment
- Separate billing/cost tracking
- Independent API quotas

### 2. Project Naming Conventions

Be consistent:
```
[company]-[application]-[environment]-[region]

Examples:
- acme-api-prod-us
- acme-api-dev-eu
- acme-frontend-prod-us
```

### 3. Use Folders for Organization

```
Organization: Acme Corp
    ├── Production
    │   ├── Customer-Facing
    │   │   ├── web-frontend-prod
    │   │   └── api-backend-prod
    │   └── Internal
    │       └── admin-dashboard-prod
    └── Non-Production
        ├── Development
        └── Staging
```

### 4. Shared Resources

Some resources can/should be shared:

**VPC Networks**: Use Shared VPC for network resources across projects
- Host project: Owns VPC
- Service projects: Use the VPC

**Container Images**: Use Artifact Registry with cross-project access

**Secrets**: Use Secret Manager with cross-project permissions

## Labels and Tags

Organize resources within projects using:

### Labels
- Key-value pairs attached to resources
- Used for filtering, billing breakdown, and organization
- Maximum 64 labels per resource

```bash
# Add labels to a Cloud Run service
gcloud run services update my-service \
    --labels=environment=prod,team=backend,cost-center=engineering
```

**Common Label Patterns:**
- `environment`: dev, staging, prod
- `team`: frontend, backend, data
- `cost-center`: engineering, marketing
- `application`: api, web, worker

### Tags

- For more complex organization and conditional policies
- Defined at organization/folder level
- Applied to projects and resources
- Used in IAM conditional policies and firewall rules

## Demo: Exploring Your Project

Let's explore the project you have access to:

1. **Check current project:**
```bash
gcloud config get-value project
```

2. **List enabled APIs:**
```bash
gcloud services list --enabled
```

3. **View project metadata:**
```bash
gcloud projects describe $(gcloud config get-value project)
```

4. **Check project quotas:**
```bash
gcloud compute project-info describe --project=$(gcloud config get-value project)
```

## Key Takeaways

- Projects are the fundamental organizing unit in GCP
- Every resource must belong to a project
- Use multiple projects for isolation (especially between environments)
- Project IDs are globally unique and immutable
- Folders provide additional hierarchy for organizations
- Labels help organize resources within projects

## Discussion Points

- How should we structure projects for your organization?
- What naming conventions make sense for your team?
- Single project vs multiple projects for your use case?
- How to handle shared resources?

---

Next: [Networking Basics →](./02-networking.md)
