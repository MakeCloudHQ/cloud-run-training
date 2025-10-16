# VPC Networking for Cloud Run

Learn how to connect Cloud Run services to VPC resources and configure private networking.

## Why VPC Connectivity?

By default, Cloud Run services:
- Are publicly accessible via HTTPS
- Can access public internet
- **Cannot** access private VPC resources

You need VPC connectivity when your service needs to:
- Access Cloud SQL private IP
- Call internal services in VPC
- Access VMs in your network
- Connect to on-premises resources via VPN/Interconnect
- Comply with policies requiring private networking

## The Two Directions

### 1. Ingress (Incoming Traffic)

Who can send requests **to** your Cloud Run service?

**Options:**
- `all` - Public internet (default)
- `internal-and-cloud-load-balancing` - Internal VPC + Load Balancer
- `internal` - Only internal VPC traffic

### 2. Egress (Outgoing Traffic)

Where can your Cloud Run service send requests **to**?

**Options:**
- Public internet directly (default)
- Through VPC via VPC Connector (optional)

## Serverless VPC Access (Egress)

Connect your Cloud Run service to your VPC network.

### VPC Connector

A VPC Connector is a resource that bridges serverless services (Cloud Run, Cloud Functions) to VPC.

**Characteristics:**
- Regional resource
- Requires dedicated subnet (/28 minimum = 16 IPs)
- Has throughput limits (scale by creating more connectors)
- Costs based on throughput

### Creating a VPC Connector

**Step 1: Create the connector**

```bash
gcloud compute networks vpc-access connectors create my-connector \
    --network=my-vpc \
    --region=europe-west2 \
    --range=10.8.0.0/28
```

**Parameters:**
- `--network`: VPC to connect to
- `--region`: Where the connector lives (must match service region)
- `--range`: Dedicated IP range (cannot overlap with existing subnets)

**Alternative: Use existing subnet**
```bash
gcloud compute networks vpc-access connectors create my-connector \
    --network=my-vpc \
    --region=europe-west2 \
    --subnet=my-connector-subnet \
    --subnet-project=my-project
```

**Step 2: Attach to Cloud Run service**

```bash
gcloud run deploy my-service \
    --image=gcr.io/my-project/my-image \
    --region=europe-west2 \
    --vpc-connector=my-connector \
    --vpc-egress=all-traffic  # or private-ranges-only
```

### Egress Settings

**`--vpc-egress=all-traffic`** (route everything through VPC):
- All outbound traffic goes through VPC Connector
- Can apply VPC firewall rules
- Requires Cloud NAT for public internet access
- Higher latency for public internet calls

**`--vpc-egress=private-ranges-only`** (recommended):
- Only RFC 1918 traffic (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) through VPC
- Public internet traffic direct (faster)
- Best of both worlds

```
Cloud Run → VPC Connector → VPC Resources (10.x.x.x)
Cloud Run → Direct → Public Internet (everything else)
```

### Example: Connecting to Cloud SQL

**Scenario:** Cloud Run service needs to connect to Cloud SQL via private IP.

**Step 1: Configure Cloud SQL for private IP**
```bash
gcloud sql instances patch my-instance \
    --network=projects/my-project/global/networks/my-vpc \
    --no-assign-ip  # Private IP only
```

**Step 2: Create VPC Connector**
```bash
gcloud compute networks vpc-access connectors create sql-connector \
    --network=my-vpc \
    --region=europe-west2 \
    --range=10.8.0.0/28
```

**Step 3: Deploy Cloud Run with connector**
```bash
gcloud run deploy my-api \
    --image=gcr.io/my-project/api \
    --region=europe-west2 \
    --vpc-connector=sql-connector \
    --vpc-egress=private-ranges-only \
    --set-env-vars="DB_HOST=10.50.0.3"  # Private IP of Cloud SQL
```

**Note:** You can also use the built-in Cloud SQL connector (easier):
```bash
gcloud run deploy my-api \
    --image=gcr.io/my-project/api \
    --add-cloudsql-instances=my-project:europe-west2:my-instance
```

Then connect via Unix socket (no VPC Connector needed).

## Cloud NAT for Outbound Internet

If using `--vpc-egress=all-traffic`, you need Cloud NAT for internet access.

### Setting Up Cloud NAT

**Step 1: Create Cloud Router**
```bash
gcloud compute routers create my-router \
    --network=my-vpc \
    --region=europe-west2
```

**Step 2: Create NAT configuration**
```bash
gcloud compute routers nats create my-nat \
    --router=my-router \
    --region=europe-west2 \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips
```

Now your Cloud Run service can access the internet via this NAT gateway.

**Traffic flow:**
```
Cloud Run → VPC Connector → Cloud Router → Cloud NAT → Internet
```

## Ingress Control (Incoming Traffic)

Control who can send requests to your service.

### Public Access (Default)

```bash
gcloud run deploy my-service \
    --ingress=all \
    --allow-unauthenticated
```

Anyone on the internet can access: `https://my-service-xxx.run.app`

### Internal + Load Balancer

```bash
gcloud run deploy my-service \
    --ingress=internal-and-cloud-load-balancing
```

**Accessible from:**
- Other resources in the same VPC
- Through Cloud Load Balancer (can be internal or external)

**Not accessible:**
- Direct from public internet to `*.run.app` URL

**Use cases:**
- Services behind API Gateway
- Services behind Cloud Armor (DDoS protection)
- Custom domains with load balancer

### Internal Only

```bash
gcloud run deploy my-service \
    --ingress=internal
```

**Accessible from:**
- VPC resources only
- Other Cloud Run services in same project/VPC
- Via VPN/Interconnect

**Not accessible:**
- Public internet (even with load balancer)

**Use cases:**
- Backend services
- Internal APIs
- Microservices communication

## Internal Load Balancer Setup

For fully private Cloud Run services accessible from VPC:

### Step 1: Deploy Internal Service

```bash
gcloud run deploy internal-api \
    --image=gcr.io/my-project/api \
    --region=europe-west2 \
    --ingress=internal-and-cloud-load-balancing \
    --no-allow-unauthenticated
```

### Step 2: Create Internal Load Balancer

```bash
# Create serverless NEG (Network Endpoint Group)
gcloud compute network-endpoint-groups create my-api-neg \
    --region=europe-west2 \
    --network-endpoint-type=serverless \
    --cloud-run-service=internal-api

# Create backend service
gcloud compute backend-services create my-api-backend \
    --load-balancing-scheme=INTERNAL_MANAGED \
    --region=europe-west2 \
    --protocol=HTTPS

# Add NEG to backend
gcloud compute backend-services add-backend my-api-backend \
    --region=europe-west2 \
    --network-endpoint-group=my-api-neg \
    --network-endpoint-group-region=europe-west2

# Create URL map
gcloud compute url-maps create my-api-map \
    --region=europe-west2 \
    --default-service=my-api-backend

# Create HTTPS proxy
gcloud compute target-https-proxies create my-api-proxy \
    --region=europe-west2 \
    --url-map=my-api-map \
    --certificate-manager-certificates=my-cert  # Or use self-signed

# Create forwarding rule (this is your internal IP)
gcloud compute forwarding-rules create my-api-lb \
    --region=europe-west2 \
    --load-balancing-scheme=INTERNAL_MANAGED \
    --network=my-vpc \
    --subnet=my-subnet \
    --address=10.0.0.10 \
    --target-https-proxy=my-api-proxy \
    --ports=443
```

Now access via: `https://10.0.0.10` from within VPC

## Service-to-Service Communication

Multiple Cloud Run services calling each other.

### Scenario: Frontend → Backend → Database

**Architecture:**
```
Internet → Frontend (public) → Backend (internal) → Cloud SQL (private)
```

### Backend Service (Internal)

```bash
gcloud run deploy backend \
    --image=gcr.io/my-project/backend \
    --region=europe-west2 \
    --ingress=internal-and-cloud-load-balancing \
    --vpc-connector=my-connector \
    --vpc-egress=private-ranges-only \
    --no-allow-unauthenticated
```

### Frontend Service (Public)

```bash
gcloud run deploy frontend \
    --image=gcr.io/my-project/frontend \
    --region=europe-west2 \
    --ingress=all \
    --allow-unauthenticated
```

### Grant Frontend Permission to Call Backend

```bash
# Get frontend's service account
FRONTEND_SA=$(gcloud run services describe frontend \
    --region=europe-west2 \
    --format='value(spec.template.spec.serviceAccountName)')

# Grant invoker role on backend
gcloud run services add-iam-policy-binding backend \
    --region=europe-west2 \
    --member=serviceAccount:$FRONTEND_SA \
    --role=roles/run.invoker
```

### In Frontend Code (Python)

```python
import google.auth
from google.auth.transport.requests import Request
import requests

def call_backend():
    # Get backend URL
    backend_url = "https://backend-xxx.run.app"

    # Get identity token
    auth_req = Request()
    credentials, project = google.auth.default()
    credentials.refresh(auth_req)

    # Call backend with auth
    response = requests.get(
        backend_url,
        headers={"Authorization": f"Bearer {credentials.token}"}
    )

    return response.json()
```

## Shared VPC

For multi-project architectures.

### Concept

- **Host Project**: Owns the VPC and subnets
- **Service Projects**: Use the VPC to run Cloud Run

### Setup

**In Host Project:**
```bash
# Enable Shared VPC
gcloud compute shared-vpc enable my-host-project

# Associate service project
gcloud compute shared-vpc associated-projects add my-service-project \
    --host-project=my-host-project
```

**Grant Permissions:**
```bash
# Grant Cloud Run SA access to use VPC
gcloud projects add-iam-policy-binding my-host-project \
    --member=serviceAccount:service-PROJECT_NUMBER@serverless-robot-prod.iam.gserviceaccount.com \
    --role=roles/vpcaccess.user
```

**In Service Project:**
```bash
# Create connector using host project's VPC
gcloud compute networks vpc-access connectors create shared-connector \
    --network=projects/my-host-project/global/networks/shared-vpc \
    --region=europe-west2 \
    --range=10.8.0.0/28

# Deploy service with shared connector
gcloud run deploy my-service \
    --region=europe-west2 \
    --vpc-connector=shared-connector
```

## VPC Networking Best Practices

### 1. Use `private-ranges-only` for Egress

Unless you have specific compliance needs:
```bash
--vpc-egress=private-ranges-only
```

Faster and cheaper for public API calls.

### 2. Right-Size VPC Connectors

**Throughput per connector:**
- Minimum: 200 Mbps
- Maximum: 1000 Mbps
- Scale by adding more connectors

**Monitor:**
```bash
gcloud monitoring time-series list \
    --filter='metric.type="vpcaccess.googleapis.com/connector/received_bytes_count"'
```

### 3. Plan IP Ranges Carefully

VPC Connector needs dedicated range (/28 or larger).

**Example allocation:**
```
VPC: 10.0.0.0/16
├── Subnet A: 10.0.1.0/24 (GKE, VMs)
├── Subnet B: 10.0.2.0/24 (Cloud SQL)
└── Connector: 10.8.0.0/28 (VPC Connector)
```

Avoid overlaps!

### 4. Use Internal Load Balancer for Internal Services

Benefits:
- Custom domain names
- SSL termination
- Health checks
- Traffic management

### 5. Implement Defense in Depth

- Ingress control (internal/external)
- IAM (who can invoke)
- VPC firewall rules
- Service accounts with least privilege

## Terraform Example: Complete VPC Setup

```hcl
# VPC Connector
resource "google_vpc_access_connector" "connector" {
  name          = "my-connector"
  region        = "europe-west2"
  ip_cidr_range = "10.8.0.0/28"
  network       = "my-vpc"
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "my-router"
  region  = "europe-west2"
  network = "my-vpc"
}

# Cloud NAT
resource "google_compute_router_nat" "nat" {
  name   = "my-nat"
  router = google_compute_router.router.name
  region = google_compute_router.router.region

  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Cloud Run Service with VPC
resource "google_cloud_run_service" "service" {
  name     = "my-service"
  location = "europe-west2"

  template {
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
      }
    }

    spec {
      containers {
        image = "gcr.io/my-project/my-image"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}
```

## Troubleshooting

### Service Can't Reach VPC Resources

**Check:**
1. VPC Connector in same region as service
2. VPC egress configured
3. Firewall rules allow traffic from connector range
4. VPC Connector has sufficient throughput

```bash
# Test from Cloud Shell (in VPC)
gcloud compute ssh my-vm -- curl http://10.0.1.5:8080

# Check connector status
gcloud compute networks vpc-access connectors describe my-connector \
    --region=europe-west2
```

### Can't Access Public Internet with `all-traffic`

Need Cloud NAT:
```bash
# Check NAT exists
gcloud compute routers nats list --router=my-router --region=europe-west2
```

### High Latency

**Possible causes:**
- VPC Connector throughput maxed (add more connectors)
- Using `all-traffic` for public APIs (switch to `private-ranges-only`)
- Cloud NAT overhead

## Key Takeaways

- VPC Connector bridges Cloud Run to VPC (egress)
- Ingress control determines who can call your service
- Use `private-ranges-only` for best performance
- Cloud NAT required for internet with `all-traffic`
- Service-to-service auth via service account identity tokens
- Internal Load Balancer for fully private services
- Plan IP ranges carefully
- Monitor VPC Connector throughput

---

Next: [Scaling Strategies →](./03-scaling.md)
