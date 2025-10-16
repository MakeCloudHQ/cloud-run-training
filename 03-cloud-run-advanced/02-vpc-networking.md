# VPC Networking for Cloud Run

Connect Cloud Run services to VPC networks to access private resources.

## Why VPC Connectivity?

By default, Cloud Run services:
- Can access the public internet
- **Cannot** access private VPC resources (VMs, Cloud SQL private IPs, Memorystore, etc.)

You need VPC connectivity to:
- Access Cloud SQL via private IP
- Call internal APIs in your VPC
- Connect to VMs or other Compute Engine resources
- Reach on-premises resources via VPN/Interconnect

**Note:** This covers **egress** (outbound traffic from Cloud Run). For **ingress** (incoming traffic to Cloud Run), see [Ingress Control](./ingress.md).

## Two Methods for VPC Egress

### 1. Direct VPC Egress (Recommended)

Send traffic directly to your VPC without managing connector infrastructure.

**Advantages:**
- **Simpler:** No separate resources to manage
- **Cheaper:** Pay only for network traffic (scales to zero)
- **Faster:** Lower latency and higher throughput
- **More secure:** Apply network tags per service for granular firewall control

**Use this unless you have a specific reason not to.**

### 2. Serverless VPC Access Connectors

Bridge Cloud Run to VPC through dedicated connector instances.

**When to use:**
- You need to share connectivity across many services
- You have existing connectors already deployed
- You need the connector's fixed IP range for firewall rules

**Downsides:**
- Requires provisioning and managing connectors
- Costs include compute charges (billed as Compute Engine VMs) plus network egress
- Higher latency and lower throughput than Direct VPC egress

## Direct VPC Egress Setup

### Prerequisites

- VPC network in the same project or a Shared VPC
- Subnet in the same region as your Cloud Run service
- Appropriate IAM permissions

### Basic Configuration

```bash
gcloud run deploy my-service \
    --image=gcr.io/my-project/my-image \
    --region=europe-west2 \
    --network=my-vpc \
    --subnet=my-subnet \
    --vpc-egress=private-ranges-only
```

**Parameters:**
- `--network`: VPC network name (or full path for Shared VPC)
- `--subnet`: Subnet name in the service region
- `--vpc-egress`: Traffic routing mode (see below)

### VPC Egress Settings

**`--vpc-egress=private-ranges-only` (recommended):**
- Routes RFC 1918 private IP ranges through VPC (10.x.x.x, 172.16.x.x, 192.168.x.x)
- Routes public internet traffic directly (faster)
- Best performance for most use cases

**`--vpc-egress=all-traffic`:**
- Routes all traffic through VPC
- Requires Cloud NAT for internet access
- Use when you need VPC firewall rules for all traffic

### Example: Connecting to Cloud SQL

```bash
# Deploy with VPC access
gcloud run deploy my-api \
    --image=gcr.io/my-project/api \
    --region=europe-west2 \
    --network=my-vpc \
    --subnet=default \
    --vpc-egress=private-ranges-only \
    --set-env-vars="DB_HOST=10.50.0.3"
```

Your service can now connect to Cloud SQL on its private IP (10.50.0.3).

**Note:** Cloud Run also offers built-in Cloud SQL connections that are even easier:
```bash
gcloud run deploy my-api \
    --image=gcr.io/my-project/api \
    --add-cloudsql-instances=my-project:europe-west2:my-instance
```

### Network Tags for Firewall Rules

Apply network tags to control traffic with VPC firewall rules:

```bash
gcloud run services update my-service \
    --region=europe-west2 \
    --network-tags=cloud-run,backend
```

Then create firewall rules targeting these tags:

```bash
# Allow traffic from Cloud Run to database
gcloud compute firewall-rules create allow-run-to-db \
    --network=my-vpc \
    --action=allow \
    --rules=tcp:5432 \
    --source-tags=cloud-run \
    --target-tags=postgres
```

### Terraform Example

```hcl
resource "google_cloud_run_v2_service" "service" {
  name     = "my-service"
  location = "europe-west2"

  template {
    containers {
      image = "gcr.io/my-project/my-image"
    }

    vpc_access {
      network_interfaces {
        network    = "my-vpc"
        subnetwork = "my-subnet"
      }
      egress = "PRIVATE_RANGES_ONLY"
    }
  }
}
```

## Serverless VPC Access Connectors

### Creating a Connector

```bash
gcloud compute networks vpc-access connectors create my-connector \
    --network=my-vpc \
    --region=europe-west2 \
    --range=10.8.0.0/28
```

**Requirements:**
- Dedicated IP range (/28 minimum = 16 addresses)
- Cannot overlap with existing subnets
- Must be in same region as Cloud Run service

**Alternative: Use existing subnet**
```bash
gcloud compute networks vpc-access connectors create my-connector \
    --network=my-vpc \
    --region=europe-west2 \
    --subnet=connector-subnet \
    --subnet-project=my-project
```

### Using a Connector

```bash
gcloud run deploy my-service \
    --image=gcr.io/my-project/my-image \
    --region=europe-west2 \
    --vpc-connector=my-connector \
    --vpc-egress=private-ranges-only
```

Same egress settings apply (`private-ranges-only` or `all-traffic`).

### Connector Characteristics

- **Throughput:** 200-1000 Mbps per connector
- **Costs:** Billed as f1-micro Compute Engine instances (minimum 2)
- **Scaling:** Create multiple connectors for more throughput
- **Shared:** Can be used by multiple Cloud Run services

## Cloud NAT for Internet Access

Required when using `--vpc-egress=all-traffic`.

### Setup

**Step 1: Create Cloud Router**
```bash
gcloud compute routers create my-router \
    --network=my-vpc \
    --region=europe-west2
```

**Step 2: Configure Cloud NAT**
```bash
gcloud compute routers nats create my-nat \
    --router=my-router \
    --region=europe-west2 \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips
```

Traffic flow:
```
Cloud Run → VPC → Cloud NAT → Internet
```

## Shared VPC

For multi-project architectures.

### Setup

**In host project:**
```bash
# Enable Shared VPC
gcloud compute shared-vpc enable my-host-project

# Associate service project
gcloud compute shared-vpc associated-projects add my-service-project \
    --host-project=my-host-project
```

**Grant permissions:**
```bash
# Find Cloud Run service agent
PROJECT_NUMBER=$(gcloud projects describe my-service-project --format='value(projectNumber)')
SA="service-${PROJECT_NUMBER}@serverless-robot-prod.iam.gserviceaccount.com"

# Grant VPC access
gcloud projects add-iam-policy-binding my-host-project \
    --member="serviceAccount:${SA}" \
    --role="roles/vpcaccess.user"

# Grant network access for Direct VPC egress
gcloud projects add-iam-policy-binding my-host-project \
    --member="serviceAccount:${SA}" \
    --role="roles/compute.networkUser"
```

**In service project:**
```bash
# Using Direct VPC egress (recommended)
gcloud run deploy my-service \
    --region=europe-west2 \
    --network=projects/my-host-project/global/networks/shared-vpc \
    --subnet=projects/my-host-project/regions/europe-west2/subnetworks/my-subnet \
    --vpc-egress=private-ranges-only

# Or using VPC Connector
gcloud compute networks vpc-access connectors create shared-connector \
    --network=projects/my-host-project/global/networks/shared-vpc \
    --region=europe-west2 \
    --range=10.8.0.0/28

gcloud run deploy my-service \
    --region=europe-west2 \
    --vpc-connector=shared-connector \
    --vpc-egress=private-ranges-only
```

## Service-to-Service Communication

Cloud Run services calling each other.

### Example Architecture

```
Internet → Frontend (public) → Backend (internal) → Cloud SQL
```

**Backend (internal):**
```bash
gcloud run deploy backend \
    --image=gcr.io/my-project/backend \
    --region=europe-west2 \
    --network=my-vpc \
    --subnet=default \
    --vpc-egress=private-ranges-only \
    --no-allow-unauthenticated
```

**Frontend (public):**
```bash
gcloud run deploy frontend \
    --image=gcr.io/my-project/frontend \
    --region=europe-west2 \
    --allow-unauthenticated
```

**Grant frontend permission to call backend:**
```bash
FRONTEND_SA=$(gcloud run services describe frontend \
    --region=europe-west2 \
    --format='value(spec.template.spec.serviceAccountName)')

gcloud run services add-iam-policy-binding backend \
    --region=europe-west2 \
    --member="serviceAccount:${FRONTEND_SA}" \
    --role="roles/run.invoker"
```

**In frontend code (Python):**
```python
import google.auth
from google.auth.transport.requests import Request
import requests

def call_backend():
    backend_url = "https://backend-xxx.run.app"

    # Get identity token
    auth_req = Request()
    credentials, _ = google.auth.default()
    credentials.refresh(auth_req)

    # Call with auth header
    response = requests.get(
        backend_url,
        headers={"Authorization": f"Bearer {credentials.token}"}
    )

    return response.json()
```

## Best Practices

### 1. Use Direct VPC Egress

Unless you have specific needs for VPC Connectors, use Direct VPC egress for better performance and lower costs.

### 2. Use `private-ranges-only`

Route only private traffic through VPC. Public APIs go direct (faster).

```bash
--vpc-egress=private-ranges-only
```

### 3. Plan IP Addresses

- Direct VPC egress: More IP addresses from subnet
- VPC Connector: Fixed range (/28 minimum)

Ensure your subnets have sufficient capacity.

### 4. Apply Network Tags

Use network tags with Direct VPC egress for granular firewall control:

```bash
--network-tags=cloud-run,backend
```

### 5. Monitor and Right-Size

**For VPC Connectors:**
```bash
# Check connector throughput
gcloud monitoring time-series list \
    --filter='metric.type="vpcaccess.googleapis.com/connector/received_bytes_count"' \
    --format=json
```

Add more connectors if throughput is maxed (1 Gbps per connector).

## Troubleshooting

### Service Can't Reach VPC Resources

**Check:**
1. VPC network and subnet in same region as service
2. VPC egress configured (`--vpc-egress` flag)
3. Firewall rules allow traffic from Cloud Run
4. Using Direct VPC egress: Check network tags
5. Using VPC Connector: Check connector is healthy

```bash
# Check service VPC configuration
gcloud run services describe my-service \
    --region=europe-west2 \
    --format=yaml

# Check connector status (if using connectors)
gcloud compute networks vpc-access connectors describe my-connector \
    --region=europe-west2
```

### Can't Access Public Internet

Using `--vpc-egress=all-traffic`? You need Cloud NAT:

```bash
# Verify NAT exists
gcloud compute routers nats list \
    --router=my-router \
    --region=europe-west2
```

### High Latency

**Possible causes:**
- Using VPC Connector (switch to Direct VPC egress)
- Using `all-traffic` for public APIs (switch to `private-ranges-only`)
- VPC Connector throughput maxed (add more connectors)

## Key Takeaways

- **Two methods:** Direct VPC egress (recommended) and VPC Connectors
- **Direct VPC egress** offers better performance, lower cost, simpler management
- **Use `private-ranges-only`** to route only private traffic through VPC
- **Cloud NAT required** for internet access with `all-traffic` mode
- **Network tags** enable per-service firewall rules with Direct VPC egress
- For incoming traffic control, see [Ingress Control](./ingress.md)

---

Next: [Scaling Strategies →](./03-scaling.md)
