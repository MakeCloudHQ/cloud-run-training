# Projects and Folders

Understanding how Google Cloud organizes resources is fundamental to working effectively with the platform.

## The Resource Hierarchy

Google Cloud uses a hierarchical structure to organize resources:

```
Organization (optional)
    └── Folders (optional, can be nested)
        └── Projects (required)
            └── Resources (VMs, databases, Cloud Run services, etc.)
```

### Organization

The organization is the root node of your Google Cloud resource hierarchy and represents your company.

**Prerequisites:**

To have a Google Cloud organization, you **must** have either:

1. **Google Workspace** (formerly G Suite)
   - Full productivity suite: Gmail, Drive, Docs, etc.
   - Your company domain (e.g., `acme.com`)
   - Used by companies that want Google's productivity tools
   - Examples: `alice@acme.com`, `bob@acme.com`

2. **Cloud Identity** (Free or Premium)
   - Identity management **without** the productivity apps
   - Just user/group management for your domain
   - Free tier available (Cloud Identity Free)
   - Used by companies that want Google Cloud but not Google Workspace

**How it Works:**

```
Your Company Domain (acme.com)
    ↓
Google Workspace or Cloud Identity
    ↓
Google Cloud Organization (acme.com)
    ↓
All your Google Cloud projects
```

When you set up Google Workspace or Cloud Identity with your domain:
- Google automatically creates a corresponding Google Cloud organization
- The organization is tied to your domain (e.g., `acme.com`)
- Users with `@acme.com` accounts are part of your organization
- One organization per domain (or per primary domain in multi-domain setups)

**Without Workspace/Cloud Identity:**

If you just sign up for Google Cloud with a personal Gmail account:
- **No organization** - your projects are "standalone"
- No folders available
- No centralized control
- Each project is independent
- Fine for individuals/learning, not ideal for companies

**Key Benefits of Having an Organization:**
- Organization-wide IAM policies
- Centralized billing across all projects
- Consolidated audit logs
- Programmatic resource creation
- Folder hierarchy for structure
- Better governance and compliance

### Folders

- Provide grouping mechanism for projects
- Can be nested (up to 10 levels deep)
- Useful for different teams, departments, or environments
- **IAM permissions inherit downward** - permissions granted at folder level automatically apply to all projects within that folder

**Key Benefit - IAM Inheritance:**

This is powerful for access management! Grant a role once at the folder level, and it applies to all projects underneath. For example:
- Grant `roles/viewer` at the Production folder → Read-only access to all production projects
- Grant `roles/run.developer` at the Dev folder → Deploy/manage Cloud Run in all dev projects
- No need to manage permissions on each project individually

We'll cover IAM inheritance in detail and learn about predefined roles (recommended) vs basic roles in the [IAM section](./03-iam.md).

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

- **Required** container for all Google Cloud resources
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

**Leveraging IAM Inheritance:**

With this structure, you can grant permissions efficiently:

```bash
# Grant all developers read-only access to Cloud Run in production
gcloud resource-manager folders add-iam-policy-binding PRODUCTION_FOLDER_ID \
    --member=group:developers@acme.com \
    --role=roles/run.viewer

# This automatically applies to:
# - web-frontend-prod
# - api-backend-prod
# - admin-dashboard-prod

# Grant Cloud Run developer role to non-production
# (allows deploying and managing Cloud Run services)
gcloud resource-manager folders add-iam-policy-binding NON_PROD_FOLDER_ID \
    --member=group:developers@acme.com \
    --role=roles/run.developer

# This automatically applies to all dev and staging projects
```

This approach is much more maintainable than managing IAM on each individual project!

### 4. Shared Resources

Some resources can/should be shared:

**VPC Networks**: Use Shared VPC for network resources across projects
- Host project: Owns VPC
- Service projects: Use the VPC

**Container Images**: Use Artifact Registry with cross-project access

**Secrets**: Use Secret Manager with cross-project permissions

## Labels, Tags, and Network Tags

Three different ways to organize and control resources - each serves a distinct purpose:

### Labels (User-Defined Metadata)

**Key-value pairs for organizing and tracking resources.**

**What they're for:**
1. **Cost tracking** - See spending broken down by label in billing reports
   - "How much does the `team=backend` spend?"
   - "What are costs for `environment=prod` vs `environment=dev`?"
2. **Filtering resources** - Find resources in console or CLI
   - Filter Cloud Run services by `application=api`
   - List all resources for a specific team
3. **Identifying resources** - Understand what resources belong to what
   - Tag all payment-related resources with `application=payments`

**Usage:**
```bash
# Add labels to a Cloud Run service
gcloud run services update my-service \
    --labels=environment=prod,team=backend,cost-center=engineering

# Filter by labels
gcloud run services list --filter="labels.team=frontend"
```

**Common Label Patterns:**
- `environment`: dev, staging, prod
- `team`: frontend, backend, data, sre
- `cost-center`: engineering, marketing, sales
- `application`: api, web, worker, payments

**Characteristics:**
- Maximum 64 labels per resource
- Informal - anyone with resource access can add/change
- Attached directly to individual resources

### Resource Manager Tags (Governance and Policy Enforcement)

**Key-value pairs for conditional policies and governance.**

**What they're for:**
1. **Conditional IAM policies** - Grant permissions based on tags
   - "Only allow deletion if tagged `data-classification=non-sensitive`"
   - "Restrict access to resources tagged `compliance=pci`"
2. **Organization policies** - Apply constraints based on tags
   - "VMs tagged `environment=prod` must use specific machine types"

**Key Difference from Labels:**
- Must be **defined at organization/folder level first** (controlled/structured)
- Used for **policy enforcement**, not billing
- More formal governance tool

**Usage:**
```bash
# First, define tag at org level (requires admin)
gcloud resource-manager tags keys create environment \
    --parent=organizations/123456789

# Then apply to resources
gcloud resource-manager tags bindings create \
    --tag-value=environment/prod \
    --parent=//cloudresourcemanager.googleapis.com/projects/my-project
```

**When to use:**
- Enforcing compliance requirements
- Conditional access controls
- Organizational governance policies

### Network Tags (Firewall and Routing)

**Note:** These are completely different from the above!

- **Compute Engine specific** - Used only for VMs
- **Not key-value pairs** - Just strings (e.g., `web-server`, `database`)
- **Purpose**: Define which firewall rules apply to which VMs
- **Example**: All VMs with tag `web-server` allow ports 80 and 443

We'll cover network tags in detail in the [Networking section](./02-networking.md).

**Important:** Don't confuse network tags with labels or Resource Manager tags - they're completely separate concepts!

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

- Projects are the fundamental organizing unit in Google Cloud
- Every resource must belong to a project
- Use multiple projects for isolation (especially between environments)
- Project IDs are globally unique and immutable
- Folders provide additional hierarchy for organizations
- **IAM permissions inherit down the hierarchy** - grant once at folder/org level, applies to all children
- Labels help organize resources within projects

## Discussion Points

- How should we structure projects for your organization?
- What naming conventions make sense for your team?
- Single project vs multiple projects for your use case?
- How to handle shared resources?

---

Next: [Networking Basics →](./02-networking.md)
