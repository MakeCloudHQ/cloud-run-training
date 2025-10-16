# Cloud Run Ingress Control

Control who can send requests to your Cloud Run services.

## What is Ingress Control?

Ingress settings determine which network traffic can reach your Cloud Run service. This is separate from:
- **IAM authentication** (who can invoke the service)
- **VPC egress** (where your service can send requests)

Think of ingress as the front door policy for your service.

## The Three Ingress Settings

### 1. All (Public Access)

```bash
gcloud run deploy my-service \
    --ingress=all \
    --allow-unauthenticated
```

**Accessible from:**
- Public internet
- VPC resources
- Other Cloud Run services

**Default URL:** `https://my-service-xxx.run.app`

**Use cases:**
- Public APIs
- Public websites
- Services that need internet access

**Security:**
- Anyone can reach the service URL
- Use IAM (`--no-allow-unauthenticated`) to require authentication
- Consider Cloud Armor for DDoS protection

### 2. Internal and Cloud Load Balancing

```bash
gcloud run deploy my-service \
    --ingress=internal-and-cloud-load-balancing
```

**Accessible from:**
- VPC resources in the same project
- VPC resources in same VPC (Shared VPC)
- Through Cloud Load Balancer (internal or external)
- Other Cloud Run services in same project/VPC

**Not accessible:**
- Direct from public internet to `*.run.app` URL

**Use cases:**
- Services behind load balancers
- Services behind API Gateway
- Services with Cloud Armor
- Custom domains with SSL certificates
- Services requiring advanced routing

**Example architecture:**
```
Internet → Cloud Load Balancer → Cloud Run (internal ingress)
                ↓
         Cloud Armor (WAF)
```

### 3. Internal Only

```bash
gcloud run deploy my-service \
    --ingress=internal
```

**Accessible from:**
- VPC resources in the same project
- VPC resources in same VPC (Shared VPC)
- Other Cloud Run services in same project
- Resources connected via VPN/Interconnect

**Not accessible:**
- Public internet (even through load balancer)

**Use cases:**
- Backend microservices
- Internal APIs
- Database access services
- Services that should never be exposed externally

**Example architecture:**
```
Cloud Run (frontend, all) → Cloud Run (backend, internal) → Cloud SQL
```

## Configuration Methods

### Using gcloud

**Deploy new service:**
```bash
gcloud run deploy my-service \
    --image=gcr.io/my-project/my-image \
    --region=europe-west2 \
    --ingress=internal-and-cloud-load-balancing
```

**Update existing service:**
```bash
gcloud run services update my-service \
    --region=europe-west2 \
    --ingress=internal
```

### Using Console

1. Go to [Cloud Run](https://console.cloud.google.com/run)
2. Select your service
3. Click **Edit & Deploy New Revision**
4. Go to **Security** tab
5. Under **Ingress**, select:
   - All
   - Internal and Cloud Load Balancing
   - Internal

### Using Terraform

```hcl
resource "google_cloud_run_service" "service" {
  name     = "my-service"
  location = "europe-west2"

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal-and-cloud-load-balancing"
    }
  }

  template {
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

**Valid values:**
- `"all"`
- `"internal-and-cloud-load-balancing"`
- `"internal"`

### Using YAML

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: my-service
  annotations:
    run.googleapis.com/ingress: internal-and-cloud-load-balancing
spec:
  template:
    spec:
      containers:
      - image: gcr.io/my-project/my-image
```

Deploy:
```bash
gcloud run services replace service.yaml --region=europe-west2
```

## Load Balancer Integration

### External Application Load Balancer

Route public traffic through a load balancer to an internal Cloud Run service.

**Step 1: Deploy service with internal ingress**
```bash
gcloud run deploy my-api \
    --image=gcr.io/my-project/api \
    --region=europe-west2 \
    --ingress=internal-and-cloud-load-balancing \
    --no-allow-unauthenticated
```

**Step 2: Create Serverless NEG (Network Endpoint Group)**
```bash
gcloud compute network-endpoint-groups create my-api-neg \
    --region=europe-west2 \
    --network-endpoint-type=serverless \
    --cloud-run-service=my-api
```

**Step 3: Create backend service**
```bash
gcloud compute backend-services create my-api-backend \
    --global \
    --load-balancing-scheme=EXTERNAL_MANAGED
```

**Step 4: Add NEG to backend**
```bash
gcloud compute backend-services add-backend my-api-backend \
    --global \
    --network-endpoint-group=my-api-neg \
    --network-endpoint-group-region=europe-west2
```

**Step 5: Create URL map, target proxy, and forwarding rule**
```bash
# URL map
gcloud compute url-maps create my-api-map \
    --default-service=my-api-backend

# Target HTTPS proxy (requires SSL certificate)
gcloud compute target-https-proxies create my-api-proxy \
    --url-map=my-api-map \
    --ssl-certificates=my-cert

# Forwarding rule (external IP)
gcloud compute forwarding-rules create my-api-lb \
    --global \
    --target-https-proxy=my-api-proxy \
    --ports=443
```

Now access via the external IP or custom domain.

### Internal Application Load Balancer

For fully private services accessed from VPC.

**Step 1: Deploy internal service**
```bash
gcloud run deploy internal-api \
    --image=gcr.io/my-project/api \
    --region=europe-west2 \
    --ingress=internal-and-cloud-load-balancing
```

**Step 2: Create internal load balancer**
```bash
# Serverless NEG
gcloud compute network-endpoint-groups create internal-api-neg \
    --region=europe-west2 \
    --network-endpoint-type=serverless \
    --cloud-run-service=internal-api

# Backend service (INTERNAL_MANAGED)
gcloud compute backend-services create internal-api-backend \
    --load-balancing-scheme=INTERNAL_MANAGED \
    --region=europe-west2 \
    --protocol=HTTPS

# Add NEG
gcloud compute backend-services add-backend internal-api-backend \
    --region=europe-west2 \
    --network-endpoint-group=internal-api-neg \
    --network-endpoint-group-region=europe-west2

# URL map
gcloud compute url-maps create internal-api-map \
    --region=europe-west2 \
    --default-service=internal-api-backend

# HTTPS proxy
gcloud compute target-https-proxies create internal-api-proxy \
    --region=europe-west2 \
    --url-map=internal-api-map \
    --certificate-manager-certificates=my-cert

# Forwarding rule (internal IP)
gcloud compute forwarding-rules create internal-api-lb \
    --region=europe-west2 \
    --load-balancing-scheme=INTERNAL_MANAGED \
    --network=my-vpc \
    --subnet=my-subnet \
    --address=10.0.0.10 \
    --target-https-proxy=internal-api-proxy \
    --ports=443
```

Access via: `https://10.0.0.10` from within VPC.

## Disabling Default URLs

When using load balancers, you may want to disable direct access to the `*.run.app` URL.

**Why?**
- Force traffic through load balancer
- Ensure Cloud Armor policies apply
- Prevent URL discovery

**How:**
1. Set ingress to `internal-and-cloud-load-balancing` or `internal`
2. Remove IAM bindings for `allUsers`

```bash
# Remove public access
gcloud run services remove-iam-policy-binding my-service \
    --region=europe-west2 \
    --member=allUsers \
    --role=roles/run.invoker
```

Now the `*.run.app` URL returns 403 Forbidden when accessed directly.

## IAM and Ingress

Ingress controls **network access**. IAM controls **authentication**.

### Public Service (No Auth)

```bash
gcloud run deploy public-api \
    --ingress=all \
    --allow-unauthenticated
```

Anyone can call the service.

### Public URL, But Auth Required

```bash
gcloud run deploy auth-api \
    --ingress=all \
    --no-allow-unauthenticated
```

Service is reachable from internet, but requires valid authentication token.

### Internal Service, No Auth

```bash
gcloud run deploy internal-api \
    --ingress=internal \
    --allow-unauthenticated
```

Only reachable from VPC, but no token required. Use this when network isolation is sufficient.

### Internal Service, With Auth

```bash
gcloud run deploy secure-api \
    --ingress=internal \
    --no-allow-unauthenticated
```

Both network isolation and authentication required. Most secure option for internal services.

## Common Patterns

### Pattern 1: Public Frontend + Internal Backend

```bash
# Frontend (public)
gcloud run deploy frontend \
    --image=gcr.io/my-project/frontend \
    --region=europe-west2 \
    --ingress=all \
    --allow-unauthenticated

# Backend (internal)
gcloud run deploy backend \
    --image=gcr.io/my-project/backend \
    --region=europe-west2 \
    --ingress=internal \
    --no-allow-unauthenticated
```

Frontend gets IAM permission to call backend (see [VPC Networking](./02-vpc-networking.md) for details).

### Pattern 2: Load Balancer with Cloud Armor

```bash
# Service (internal ingress)
gcloud run deploy api \
    --image=gcr.io/my-project/api \
    --region=europe-west2 \
    --ingress=internal-and-cloud-load-balancing

# Cloud Armor policy
gcloud compute security-policies create my-policy \
    --description="Rate limiting and geo-blocking"

gcloud compute security-policies rules create 1000 \
    --security-policy=my-policy \
    --expression="origin.region_code == 'CN'" \
    --action=deny-403

# Attach to backend service
gcloud compute backend-services update my-api-backend \
    --security-policy=my-policy \
    --global
```

### Pattern 3: Microservices Mesh

All services internal, communicate via service-to-service auth:

```bash
# All microservices
for service in auth users orders payments; do
  gcloud run deploy $service \
      --image=gcr.io/my-project/$service \
      --region=europe-west2 \
      --ingress=internal \
      --no-allow-unauthenticated
done
```

Grant cross-service IAM permissions as needed.

## Security Best Practices

### 1. Use Least Privilege Ingress

Start with most restrictive ingress and only open as needed:
- Internal by default
- Add `internal-and-cloud-load-balancing` if you need LB
- Only use `all` for truly public services

### 2. Combine Ingress with IAM

```bash
# Good: Internal + Auth required
gcloud run deploy my-service \
    --ingress=internal \
    --no-allow-unauthenticated
```

### 3. Use Load Balancers for Public Services

Instead of public ingress directly, use:
```
Internet → Cloud Load Balancer → Cloud Run (internal ingress)
             ↓
        Cloud Armor
```

Benefits:
- DDoS protection
- Rate limiting
- Geo-blocking
- Custom domains
- SSL management

### 4. Monitor Access

Enable Cloud Audit Logs:
```bash
gcloud services enable cloudaudit.googleapis.com
```

View ingress change logs:
```bash
gcloud logging read "protoPayload.methodName:UpdateService" \
    --limit=50 \
    --format=json
```

### 5. Test Ingress Changes

After changing ingress, verify:

**From internet:**
```bash
curl https://my-service-xxx.run.app
```

**From VPC:**
```bash
gcloud compute ssh my-vm -- curl https://my-service-xxx.run.app
```

**With authentication:**
```bash
TOKEN=$(gcloud auth print-identity-token)
curl -H "Authorization: Bearer $TOKEN" https://my-service-xxx.run.app
```

## Troubleshooting

### 403 Forbidden (Public Access)

**Symptom:** `curl https://my-service-xxx.run.app` returns 403

**Possible causes:**
1. Ingress set to `internal` or `internal-and-cloud-load-balancing`
2. Authentication required but no token provided

**Solution:**
```bash
# Check ingress setting
gcloud run services describe my-service --region=europe-west2 \
    --format='value(metadata.annotations[run.googleapis.com/ingress])'

# Check IAM
gcloud run services get-iam-policy my-service --region=europe-west2
```

### Can't Reach from VPC

**Symptom:** Service with `internal` ingress not reachable from VPC

**Check:**
1. Service and caller in same project/VPC
2. IAM permissions if auth required
3. VPC Connector if calling from Cloud Run

### Load Balancer Returns 502

**Symptom:** Load balancer configured but returns 502 Bad Gateway

**Check:**
1. Ingress is `internal-and-cloud-load-balancing` (not `internal`)
2. Serverless NEG points to correct service
3. Backend service health checks passing

```bash
# Check backend health
gcloud compute backend-services get-health my-backend \
    --global
```

## Key Takeaways

- **Three ingress settings:** `all`, `internal-and-cloud-load-balancing`, `internal`
- **Ingress ≠ IAM:** Network access vs authentication
- **Use load balancers** for production public services
- **Start restrictive:** Use `internal` by default, open as needed
- **Combine with IAM** for defense in depth
- **Test after changes** from different network locations

---

Next: [Scaling Strategies →](./03-scaling.md)
