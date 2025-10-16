# IAM (Identity and Access Management)

IAM controls who can do what with your Google Cloud resources. Understanding IAM is crucial for security and access management.

## Core Concepts

IAM is built on this principle:

```
WHO (Principal) + WHAT (Role) + WHERE (Resource) = Policy Binding
```

Example: "alice@example.com has the Cloud Run Admin role on my-project"

## Principals (WHO)

The identity that can access resources. Can be:

### 1. Google Account
Individual user with a Google account.
```
alice@example.com
bob@gmail.com
```

### 2. Service Account
Identity for applications/services (not humans).
```
my-service@my-project.iam.gserviceaccount.com
123456789-compute@developer.gserviceaccount.com
```

### 3. Google Group
Collection of Google accounts and service accounts.
```
devs@example.com
```

### 4. Google Workspace Domain
All accounts in a domain.
```
example.com
```

### 5. Cloud Identity Domain
Like Google Workspace but without Gmail/Docs.

### 6. allUsers / allAuthenticatedUsers
- `allUsers`: Everyone on the internet (public)
- `allAuthenticatedUsers`: Anyone with a Google account

## Roles (WHAT)

Roles are collections of permissions. Three types:

### 1. Basic Roles (Legacy - Avoid in Production)

Coarse-grained, project-wide roles:

- **Owner**: Full control, manage roles, billing
- **Editor**: Modify resources, can't manage roles
- **Viewer**: Read-only access

**Problem**: Too broad for production use.

```bash
# Example (avoid this pattern in prod)
gcloud projects add-iam-policy-binding my-project \
    --member=user:alice@example.com \
    --role=roles/editor
```

### 2. Predefined Roles (Recommended)

Curated by Google for specific services:

**Cloud Run Examples:**
- `roles/run.admin` - Full control over Cloud Run
- `roles/run.developer` - Deploy and manage services
- `roles/run.invoker` - Invoke (call) Cloud Run services
- `roles/run.viewer` - Read-only access

**Other Common Roles:**
- `roles/storage.objectViewer` - Read from Cloud Storage
- `roles/cloudsql.client` - Connect to Cloud SQL
- `roles/secretmanager.secretAccessor` - Read secrets
- `roles/logging.logWriter` - Write logs

```bash
# Grant Cloud Run Developer role
gcloud projects add-iam-policy-binding my-project \
    --member=user:alice@example.com \
    --role=roles/run.developer
```

### 3. Custom Roles

Create your own roles with specific permissions.

```bash
# Create custom role
gcloud iam roles create myCustomRole \
    --project=my-project \
    --title="My Custom Role" \
    --description="Custom role for specific use case" \
    --permissions=run.services.get,run.services.list \
    --stage=ALPHA
```

**When to use:**
- Predefined roles are too broad
- Need very specific permission combinations
- Implementing least-privilege principle

## Permissions

Permissions are the atomic units of access:

Format: `service.resource.verb`

**Examples:**
- `run.services.create` - Create Cloud Run services
- `run.services.get` - Read Cloud Run service details
- `run.services.update` - Update Cloud Run services
- `run.services.delete` - Delete Cloud Run services
- `run.services.invoke` - Call/invoke a Cloud Run service

**You usually don't work with permissions directly** - you assign roles that contain permissions.

## Service Accounts

Service accounts are identities for applications, not humans.

### Why Service Accounts?

Your code needs to:
- Call Google APIs
- Access other Google Cloud resources
- Authenticate itself

**Don't use user credentials in code!** Use service accounts instead.

### Types of Service Accounts

**Default Service Accounts** (Created automatically):
- Compute Engine default: `PROJECT_NUMBER-compute@developer.gserviceaccount.com`
- App Engine default: `PROJECT_ID@appspot.gserviceaccount.com`

**User-Managed Service Accounts** (You create):
```bash
gcloud iam service-accounts create my-service \
    --display-name="My Service Account"
```

### Service Account for Cloud Run

Every Cloud Run service runs as a service account:

```bash
# Deploy with specific service account
gcloud run deploy my-service \
    --image=gcr.io/my-project/my-image \
    --service-account=my-service@my-project.iam.gserviceaccount.com
```

**Best Practice**: Create dedicated service accounts per service with only the permissions they need.

### Working with Service Accounts

```bash
# Create
gcloud iam service-accounts create my-service-sa \
    --display-name="My Service"

# List
gcloud iam service-accounts list

# Grant service account a role on a project
gcloud projects add-iam-policy-binding my-project \
    --member=serviceAccount:my-service-sa@my-project.iam.gserviceaccount.com \
    --role=roles/cloudsql.client

# Grant a user permission to use a service account (impersonation)
gcloud iam service-accounts add-iam-policy-binding \
    my-service-sa@my-project.iam.gserviceaccount.com \
    --member=user:alice@example.com \
    --role=roles/iam.serviceAccountUser
```

## Resource Hierarchy and Inheritance

IAM policies can be set at different levels and inherit downward:

```
Organization
    ├── Folder
    │   └── Project
    │       └── Resource (e.g., Cloud Run service)
```

**Inheritance**: Permissions granted at higher levels apply to all children.

**Example:**
- Grant `roles/viewer` at organization level → Can view everything
- Grant `roles/run.admin` at project level → Can manage Cloud Run in that project
- Grant `roles/run.invoker` on specific service → Can only call that service

### IAM Policy Inheritance

```bash
# Organization level
gcloud organizations add-iam-policy-binding ORG_ID \
    --member=user:alice@example.com \
    --role=roles/viewer

# Project level
gcloud projects add-iam-policy-binding my-project \
    --member=user:bob@example.com \
    --role=roles/run.developer

# Resource level (Cloud Run service)
gcloud run services add-iam-policy-binding my-service \
    --region=us-central1 \
    --member=user:charlie@example.com \
    --role=roles/run.invoker
```

## Common Cloud Run IAM Scenarios

### 1. Allow Anyone to Call a Service (Public Access)

```bash
gcloud run services add-iam-policy-binding my-service \
    --region=us-central1 \
    --member=allUsers \
    --role=roles/run.invoker
```

**Use case**: Public API or website

### 2. Allow Only Authenticated Users

```bash
gcloud run services add-iam-policy-binding my-service \
    --region=us-central1 \
    --member=allAuthenticatedUsers \
    --role=roles/run.invoker
```

**Use case**: Internal tool accessible to anyone with Google account

### 3. Allow Specific Users/Services

```bash
gcloud run services add-iam-policy-binding my-service \
    --region=us-central1 \
    --member=user:alice@example.com \
    --role=roles/run.invoker

# Or allow another service account (service-to-service)
gcloud run services add-iam-policy-binding my-service \
    --region=us-central1 \
    --member=serviceAccount:caller-service@my-project.iam.gserviceaccount.com \
    --role=roles/run.invoker
```

**Use case**: Private service, only specific identities can call

### 4. Service Account Needs to Access Cloud SQL

```bash
# Grant the Cloud Run service account permission to connect to Cloud SQL
gcloud projects add-iam-policy-binding my-project \
    --member=serviceAccount:my-service@my-project.iam.gserviceaccount.com \
    --role=roles/cloudsql.client
```

### 5. Service Account Needs to Read from Cloud Storage

```bash
# Grant permission on a specific bucket
gcloud storage buckets add-iam-policy-binding gs://my-bucket \
    --member=serviceAccount:my-service@my-project.iam.gserviceaccount.com \
    --role=roles/storage.objectViewer
```

## IAM Best Practices

### 1. Principle of Least Privilege

Grant the minimum permissions needed. Don't use `roles/editor` when `roles/run.developer` will do.

### 2. Use Groups

Instead of granting permissions to individual users:
```bash
# Good: Grant to group
gcloud projects add-iam-policy-binding my-project \
    --member=group:developers@example.com \
    --role=roles/run.developer

# Less maintainable: Grant to individual users
gcloud projects add-iam-policy-binding my-project \
    --member=user:alice@example.com \
    --role=roles/run.developer
```

### 3. Use Service Accounts for Applications

Never put user credentials in code. Always use service accounts.

### 4. Dedicated Service Accounts per Service

```
my-api@my-project.iam.gserviceaccount.com
my-worker@my-project.iam.gserviceaccount.com
my-frontend@my-project.iam.gserviceaccount.com
```

Each with only the permissions it needs.

### 5. Avoid Basic Roles in Production

Don't use Owner, Editor, Viewer. Use predefined roles instead.

### 6. Regular Audits

```bash
# View IAM policy for project
gcloud projects get-iam-policy my-project

# View IAM policy for specific service
gcloud run services get-iam-policy my-service --region=us-central1
```

### 7. Use Conditions (Advanced)

Add conditions to IAM bindings:
- Time-based access
- IP-based restrictions
- Resource-based conditions

```bash
gcloud projects add-iam-policy-binding my-project \
    --member=user:alice@example.com \
    --role=roles/run.admin \
    --condition='expression=request.time < timestamp("2024-12-31T23:59:59Z"),title=Temporary Access'
```

## Viewing and Managing IAM

### Console

Navigate to: **IAM & Admin** > **IAM**
- See all principals and their roles
- Add/remove bindings
- View permissions

### gcloud Commands

```bash
# View project IAM policy
gcloud projects get-iam-policy my-project

# View in readable format
gcloud projects get-iam-policy my-project --format=json

# Add binding
gcloud projects add-iam-policy-binding my-project \
    --member=user:alice@example.com \
    --role=roles/run.developer

# Remove binding
gcloud projects remove-iam-policy-binding my-project \
    --member=user:alice@example.com \
    --role=roles/run.developer

# Test IAM permissions (what can I do?)
gcloud projects get-iam-policy my-project \
    --flatten="bindings[].members" \
    --filter="bindings.members:user:$(gcloud config get-value account)"
```

## Authentication vs Authorization

**Authentication** (AuthN): Who are you?
- Logging in
- Verifying identity

**Authorization** (AuthZ): What can you do?
- IAM controls this
- Checking permissions

**Cloud Run Example:**
1. User sends request with token → Authentication
2. Cloud Run checks if user has `run.invoker` role → Authorization

## Troubleshooting IAM Issues

### "Permission Denied" Errors

```bash
# Check what permissions you have
gcloud projects get-iam-policy my-project \
    --flatten="bindings[].members" \
    --filter="bindings.members:user:$(gcloud config get-value account)"

# Test specific permission
gcloud projects get-iam-policy my-project --format=json | \
    jq '.bindings[] | select(.members[] | contains("YOUR_EMAIL"))'
```

### Service Can't Access Resource

1. Check service account: What SA is the service using?
2. Check IAM bindings: Does that SA have necessary roles?
3. Check resource-specific permissions: Some resources have their own IAM

### Invoker Permission Issues

```bash
# Check who can invoke your service
gcloud run services get-iam-policy my-service --region=us-central1
```

## Key Takeaways

- IAM = WHO (Principal) + WHAT (Role) + WHERE (Resource)
- Use predefined roles, avoid basic roles
- Service accounts for applications, not user credentials
- Grant least privilege necessary
- Policies inherit down the resource hierarchy
- `roles/run.invoker` is needed to call Cloud Run services
- Use groups for easier management

## Discussion Points

- How should we structure service accounts for your services?
- Who needs access to deploy vs invoke services?
- Public vs private services in your architecture?
- Integration with existing identity systems?

---

Next: [Discussion Topics →](./04-discussion-topics.md)
