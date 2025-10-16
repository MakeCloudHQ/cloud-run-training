# Terraform Example: Folders and Projects

This example demonstrates how to create a Google Cloud organization hierarchy with folders and projects using Terraform **and the official Google Cloud Platform Terraform modules**.

## Why Use Terraform Modules?

This example uses the **terraform-google-modules** from Google, which is the industry-standard approach:

- **Production-ready**: Battle-tested by thousands of organizations
- **Best practices built-in**: Follows Google's recommended patterns
- **Maintained by Google**: Regular updates and security patches
- **Handles edge cases**: API enablement, retry logic, dependencies
- **Consistent patterns**: Same approach across all GCP resources

### Modules Used

1. **[terraform-google-modules/folders/google](https://registry.terraform.io/modules/terraform-google-modules/folders/google)** - Creates folders
2. **[terraform-google-modules/project-factory/google](https://registry.terraform.io/modules/terraform-google-modules/project-factory/google)** - Creates projects with best practices

## What This Creates

This Terraform configuration creates:

1. **Three folders** at the organization level:
   - Development
   - Staging
   - Production

2. **Projects**:
   - **Development**: `my-app-dev-XXXX` - Single standalone project
   - **Staging**: Demonstrates Shared VPC architecture
     - `my-app-stage-host-XXXX` - Shared VPC host project
     - `my-app-stage-svc1-XXXX` - Service project 1
     - `my-app-stage-svc2-XXXX` - Service project 2
   - **Production**: `my-app-prod-XXXX` - Single standalone project

   Where `XXXX` is a random 4-character hex suffix for global uniqueness.

3. **Staging Shared VPC Network**:
   - Custom VPC network in the host project
   - Single subnet (10.0.0.0/24) in europe-west2
   - Firewall rules for ICMP (ping) and SSH via IAP
   - Two VM instances (one in each service project) to demonstrate cross-project networking

4. **Basic APIs enabled** on each project:
   - Cloud Resource Manager API
   - Service Usage API
   - Compute Engine API

5. **Labels** on each project:
   - `environment`: dev, stage, or prod
   - `managed_by`: terraform
   - `vpc_type`: shared-host or shared-service (on staging projects)

## Folder Hierarchy

**Option 1: Under an existing parent folder (Recommended)**
```
Organization (123456789012)
└── Training Folder (or your existing folder)
    ├── Development Folder
    │   └── my-app-dev-a3f9
    ├── Staging Folder
    │   ├── my-app-stage-host-a3f9 (Shared VPC Host)
    │   │   ├── VPC Network: shared-vpc
    │   │   └── Subnet: 10.0.0.0/24
    │   ├── my-app-stage-svc1-a3f9 (Service Project)
    │   │   └── VM: vm-service1 (uses shared VPC)
    │   └── my-app-stage-svc2-a3f9 (Service Project)
    │       └── VM: vm-service2 (uses shared VPC)
    └── Production Folder
        └── my-app-prod-a3f9
```

**Option 2: Directly under organization**
```
Organization (123456789012)
├── Development Folder
│   └── my-app-dev-a3f9
├── Staging Folder
│   ├── my-app-stage-host-a3f9 (Shared VPC Host)
│   ├── my-app-stage-svc1-a3f9 (Service Project)
│   └── my-app-stage-svc2-a3f9 (Service Project)
└── Production Folder
    └── my-app-prod-a3f9
```

## Prerequisites

Before running this example, you need:

1. **Google Cloud Organization**
   - Requires Google Workspace or Cloud Identity
   - You must have organization-level permissions

2. **Required IAM Roles**:
   - `roles/resourcemanager.folderCreator` - To create folders
   - `roles/resourcemanager.projectCreator` - To create projects
   - `roles/billing.user` - To associate projects with billing

3. **Terraform installed**:
   ```bash
   # Check installation
   terraform version
   ```

4. **Google Cloud CLI authenticated**:
   ```bash
   # Authenticate
   gcloud auth application-default login

   # Verify you can see your organization
   gcloud organizations list
   ```

5. **Billing Account** - Active billing account with permissions to associate projects

## Setup

### 1. Find Your Parent ID

You need either an organization ID or an existing folder ID.

**Option A: Organization (creates folders at org level)**
```bash
gcloud organizations list
```

Output:
```
DISPLAY_NAME       ID            DIRECTORY_CUSTOMER_ID
acme.com           123456789012  C01234567
```

Use as: `parent = "organizations/123456789012"`

**Option B: Existing Folder (recommended - creates folders under a parent folder)**
```bash
gcloud resource-manager folders list --organization=YOUR_ORG_ID
```

Output:
```
DISPLAY_NAME    ID            PARENT
Training        987654321     organizations/123456789012
```

Use as: `parent = "folders/987654321"`

### 2. Find Your Billing Account ID

```bash
gcloud billing accounts list
```

Output will look like:
```
ACCOUNT_ID            NAME                OPEN  MASTER_ACCOUNT_ID
ABCDEF-123456-GHIJKL  My Billing Account  True
```

Use the `ACCOUNT_ID` value.

### 3. Create terraform.tfvars

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Fill in your actual values:

```hcl
# Option A: Under existing folder (recommended)
parent = "folders/123456789012"

# OR

# Option B: Directly under organization
parent = "organizations/123456789012"

# Plus these required values:
billing_account_id = "ABCDEF-123456-GHIJKL"
project_prefix     = "my-app"
```

## Usage

### Initialize Terraform

```bash
terraform init
```

This downloads the required providers (Google Cloud and Random).

### Plan the Changes

```bash
terraform plan
```

Review the resources that will be created:
- 3 folders
- 5 projects (1 dev, 3 staging, 1 prod)
- 1 VPC network with subnet
- 2 firewall rules
- 2 VM instances
- 1 random ID
- API enablements

### Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

This will take 2-3 minutes as projects are created.

### View the Results

After successful apply:

```bash
# See the output summary (includes all projects and VM IPs)
terraform output summary

# View individual outputs
terraform output dev_project_id
terraform output stage_host_project_id
terraform output stage_vm1_internal_ip
terraform output stage_vm2_internal_ip
terraform output prod_folder_id
```

### Verify in Console

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **IAM & Admin** > **Manage Resources**
3. You should see your new folders and projects

### Verify with gcloud

```bash
# List folders
gcloud resource-manager folders list --organization=YOUR_ORG_ID

# List projects
gcloud projects list --filter="parent.id:YOUR_FOLDER_ID"
```

## Understanding the Code

### main.tf

**1. Random ID Generation:**
```hcl
resource "random_id" "suffix" {
  byte_length = 2  # 2 bytes = 4 hex characters
}
```
Creates a random suffix like `a3f9` to ensure globally unique project IDs.

**2. Folder Creation (using the folders module):**
```hcl
module "folders" {
  source  = "terraform-google-modules/folders/google"
  version = "~> 4.0"

  parent = var.parent  # Can be org or folder

  names = [
    "Development",
    "Staging",
    "Production"
  ]
}
```
**Why use the module?**
- Creates all three folders in one declaration
- Handles dependencies automatically
- Returns a consistent list of folder IDs
- Includes retry logic for API rate limits

**3. Local values for easy reference:**
```hcl
locals {
  folder_ids = {
    dev   = module.folders.ids_list[0]
    stage = module.folders.ids_list[1]
    prod  = module.folders.ids_list[2]
  }
}
```
Creates a map so we can reference folders by name instead of list index.

**4. Project Creation (using the project-factory module):**
```hcl
module "project_dev" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 15.0"

  name              = "${var.project_prefix}-dev"
  project_id        = "${var.project_prefix}-dev-${random_id.suffix.hex}"
  folder_id         = local.folder_ids.dev
  billing_account   = var.billing_account_id

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
  ]

  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }

  auto_create_network = true
}
```

**Why use project-factory?**
- **API enablement**: Automatically enables required APIs
- **Service accounts**: Can create default service accounts
- **Shared VPC**: Supports shared VPC configuration
- **Budget alerts**: Can configure budget notifications
- **IAM**: Can set up default IAM bindings
- **Better error handling**: Handles common project creation issues

### Why Random Suffix?

Project IDs must be globally unique across all of Google Cloud. The 4-character random suffix helps avoid conflicts:

- Without suffix: `my-app-dev` (might be taken)
- With suffix: `my-app-dev-a3f9` (very unlikely to conflict)

## Shared VPC in Staging

The staging environment demonstrates **Shared VPC**, a common enterprise pattern that allows multiple projects to share a single VPC network.

### What is Shared VPC?

Shared VPC allows an organization to connect resources from multiple projects to a common VPC network. This enables:
- **Centralized network management**: Network admins manage the VPC in one place
- **Cross-project communication**: Resources in different projects can communicate privately
- **Separation of concerns**: Network team owns the host, app teams own service projects
- **Cost optimization**: Share network infrastructure across teams

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Host Project: my-app-stage-host-a3f9                    │
│                                                           │
│  VPC Network: shared-vpc                                 │
│  ├── Subnet: stage-subnet (10.0.0.0/24)                 │
│  ├── Firewall: Allow ICMP (ping)                        │
│  └── Firewall: Allow SSH from IAP                       │
│                                                           │
│  Owned by: Network administrators                        │
└─────────────────────────────────────────────────────────┘
           │                           │
           │                           │
           ▼                           ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│ Service Project 1        │  │ Service Project 2        │
│ my-app-stage-svc1-a3f9   │  │ my-app-stage-svc2-a3f9   │
│                          │  │                          │
│ ┌────────────────────┐   │  │ ┌────────────────────┐   │
│ │ VM: vm-service1    │   │  │ │ VM: vm-service2    │   │
│ │ IP: 10.0.0.2       │◄──┼──┼─►│ IP: 10.0.0.3       │   │
│ └────────────────────┘   │  │ └────────────────────┘   │
│                          │  │                          │
│ Owned by: App Team A     │  │ Owned by: App Team B     │
└──────────────────────────┘  └──────────────────────────┘
```

### How It Works in This Example

1. **Host Project** (`project_stage_host`):
   - Configured with `enable_shared_vpc_host_project = true`
   - Contains the VPC network and subnets
   - Manages firewall rules
   - No compute resources (just networking)

2. **Service Projects** (`project_stage_service1`, `project_stage_service2`):
   - Configured with `svpc_host_project_id` pointing to the host
   - Can create VMs that use the shared VPC
   - VMs get IPs from the host project's subnet
   - VMs can communicate with each other

3. **VM Instances**:
   - Created in service projects
   - Use `subnetwork_project` to reference the host project
   - Both VMs are in the same subnet, so they can ping each other

### Testing the Shared VPC

After running `terraform apply`, you can verify the VMs can communicate:

```bash
# Get the project IDs and VM IPs from outputs
terraform output summary

# SSH into VM 1 (via IAP tunnel)
gcloud compute ssh vm-service1 \
  --project=YOUR-STAGE-SVC1-PROJECT-ID \
  --zone=europe-west2-a \
  --tunnel-through-iap

# From VM 1, ping VM 2
ping 10.0.0.3  # Replace with actual IP from outputs

# You should see successful ping responses!
# Press Ctrl+C to stop
```

**Expected output:**
```
PING 10.0.0.3 (10.0.0.3) 56(84) bytes of data.
64 bytes from 10.0.0.3: icmp_seq=1 ttl=64 time=1.23 ms
64 bytes from 10.0.0.3: icmp_seq=2 ttl=64 time=0.892 ms
```

This proves that resources in different projects can communicate through the shared VPC!

### Key Benefits for Training

This example demonstrates:
- **Real-world pattern**: Shared VPC is used by enterprises for team/workload isolation
- **IAM separation**: Network admins and app developers have different project permissions
- **Cost savings**: Multiple teams share network infrastructure
- **Security**: Centralized firewall rule management
- **Practical validation**: Students can actually SSH in and test connectivity

## Customization

### Change Project Prefix

Edit `terraform.tfvars`:
```hcl
project_prefix = "acme-platform"
```

Results in: `acme-platform-dev-a3f9`, `acme-platform-stage-a3f9`, etc.

### Add More Projects

To add another project to the dev folder, add to `main.tf`:

```hcl
resource "google_project" "dev_frontend" {
  name            = "${var.project_prefix}-frontend-dev"
  project_id      = "${var.project_prefix}-frontend-dev-${random_id.suffix.hex}"
  folder_id       = google_folder.dev.name
  billing_account = var.billing_account_id

  labels = {
    environment = "dev"
    application = "frontend"
    managed_by  = "terraform"
  }
}
```

### Disable Default Network

If you want to create custom networks:

```hcl
resource "google_project" "dev" {
  # ... other configuration ...
  auto_create_network = false  # Change from true
}
```

### Add More APIs

Enable additional APIs by adding to the `for_each`:

```hcl
resource "google_project_service" "dev_services" {
  project = google_project.dev.project_id

  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "run.googleapis.com",              # Add Cloud Run
    "compute.googleapis.com",           # Add Compute Engine
  ])

  service            = each.key
  disable_on_destroy = false
}
```

## Clean Up

To destroy all resources created by this example:

```bash
terraform destroy
```

Type `yes` when prompted.

**Warning:** This will delete:
- All 5 projects (dev, 3 staging projects, prod)
- All VMs, networks, and firewall rules
- All 3 folders
- The random ID

**Note:** The VMs and network resources will be deleted first, then the projects, then the folders. This takes 3-5 minutes.

Make sure you don't have any important resources in these projects!

## Common Issues

### "Organization not found"

**Error:** `Error creating Folder: googleapi: Error 403: Permission denied`

**Solution:**
- Verify your organization ID: `gcloud organizations list`
- Check you have `roles/resourcemanager.folderCreator` permission

### "Billing account not found"

**Error:** `Billing account XXXXXX-XXXXXX-XXXXXX not found`

**Solution:**
- Verify billing account: `gcloud billing accounts list`
- Check it's `OPEN: True`
- Verify you have `roles/billing.user` permission

### "Project ID already exists"

**Error:** `googleapi: Error 409: Project ID already exists`

**Solution:**
The random suffix collision is extremely rare. If it happens:
1. Run `terraform destroy` (removes the random_id)
2. Run `terraform apply` again (generates new random suffix)

### "Authentication error"

**Error:** `Error: google: could not find default credentials`

**Solution:**
```bash
gcloud auth application-default login
```

## Learning Points

This example teaches:

1. **Folder hierarchy** - Organizing resources by environment
2. **Project creation** - Using Terraform to create projects with the project-factory module
3. **Shared VPC** - Enterprise networking pattern with host and service projects
4. **Resource dependencies** - Projects depend on folders, VMs depend on networks
5. **Random generation** - Ensuring globally unique IDs
6. **Labels** - Organizing projects with metadata
7. **API enablement** - Enabling services on projects
8. **Variables and outputs** - Parameterizing and exposing values
9. **Cross-project networking** - Resources in different projects communicating via Shared VPC
10. **Firewall rules** - Allowing specific traffic (ICMP, SSH via IAP)

## Next Steps

After understanding this example:

1. **Add IAM bindings** - Grant permissions to folders/projects
2. **Create VPC networks** - Add networking resources
3. **Deploy Cloud Run services** - Put workloads in projects
4. **Implement Resource Manager tags** - For conditional policies

See other examples in the `terraform/` directory.

## Related Documentation

- [Google Folder Resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_folder)
- [Google Project Resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project)
- [Random ID Resource](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id)
- [Google Cloud Projects Documentation](https://cloud.google.com/resource-manager/docs/creating-managing-projects)
