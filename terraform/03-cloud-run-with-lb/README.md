# Cloud Run with Load Balancer - Terraform Demo

This Terraform configuration deploys a Cloud Run service behind an Application Load Balancer.

## What This Creates

```
Internet → External IP → HTTP Proxy → URL Map → Backend Service → NEG → Cloud Run
```

**Resources created:**
- Cloud Run service (using Google's hello container)
- Serverless Network Endpoint Group (NEG)
- Backend Service
- URL Map
- HTTP Target Proxy
- Global Forwarding Rule
- Static External IP Address

## Architecture

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│  Load Balancer IP       │
│  (Global Forwarding     │
│   Rule)                 │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  HTTP Target Proxy      │
│  (Port 80)              │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  URL Map                │
│  (Routing rules)        │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  Backend Service        │
│  (Configuration)        │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  Serverless NEG         │
│  (Cloud Run reference)  │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  Cloud Run Service      │
│  (hello container)      │
└─────────────────────────┘
```

## Prerequisites

- Terraform >= 1.0
- Google Cloud project with billing enabled
- APIs enabled:
  - Cloud Run API: `gcloud services enable run.googleapis.com`
  - Compute Engine API: `gcloud services enable compute.googleapis.com`
- Appropriate IAM permissions:
  - `roles/run.admin`
  - `roles/compute.admin`

## Usage

### Step 1: Configure Variables

Copy the example file and set your project ID:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
project_id   = "my-project-id"
region       = "europe-west2"
service_name = "hello-lb"
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan
```

You should see 8 resources to be created:
- `google_cloud_run_v2_service.hello`
- `google_cloud_run_v2_service_iam_member.public_access`
- `google_compute_region_network_endpoint_group.cloudrun_neg`
- `google_compute_backend_service.default`
- `google_compute_url_map.default`
- `google_compute_target_http_proxy.default`
- `google_compute_global_address.default`
- `google_compute_global_forwarding_rule.http`

### Step 4: Apply

```bash
terraform apply
```

Type `yes` when prompted.

This will take 2-3 minutes to complete.

### Step 5: Test the Deployment

After apply completes, you'll see outputs:

```
cloud_run_url       = "https://hello-lb-xxx-uc.a.run.app"
load_balancer_ip    = "34.120.1.5"
load_balancer_url   = "http://34.120.1.5"
```

**Test via load balancer:**
```bash
LB_IP=$(terraform output -raw load_balancer_ip)
curl http://$LB_IP
```

**Test direct Cloud Run URL:**
```bash
CLOUD_RUN_URL=$(terraform output -raw cloud_run_url)
curl $CLOUD_RUN_URL
```

Both should return the same Hello World HTML page.

**Note:** It may take 1-2 minutes after `terraform apply` completes for the load balancer to be fully operational.

### Step 6: View in Console

Open the load balancer in Google Cloud Console:
```
https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers
```

Explore the components:
- Frontend (IP and forwarding rule)
- Host and path rules (URL map)
- Backend (backend service and NEG)

## Adding HTTPS

To use HTTPS with a managed SSL certificate:

### Step 1: Uncomment HTTPS Resources

In `main.tf`, uncomment:
- `google_compute_target_https_proxy.default`
- `google_compute_managed_ssl_certificate.default`
- `google_compute_global_forwarding_rule.https`

Comment out:
- `google_compute_target_http_proxy.default`
- `google_compute_global_forwarding_rule.http`

### Step 2: Add Domain Variable

In `variables.tf`, uncomment:
```hcl
variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
}
```

In `terraform.tfvars`:
```hcl
domain_name = "api.example.com"
```

### Step 3: Configure DNS

Before applying, point your domain to the load balancer IP:
```
A record: api.example.com → 34.120.1.5
```

### Step 4: Apply

```bash
terraform apply
```

Certificate provisioning takes 15-60 minutes. Check status:
```bash
gcloud compute ssl-certificates describe hello-lb-cert --global
```

## Customization

### Change Service Name

```hcl
service_name = "my-custom-service"
```

### Change Region

```hcl
region = "us-central1"
```

**Note:** The NEG must be in the same region as the Cloud Run service.

### Add Cloud Armor

Add to `main.tf`:

```hcl
resource "google_compute_security_policy" "policy" {
  name = "${var.service_name}-armor"

  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(403)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 600
    }
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

# Add to backend service
resource "google_compute_backend_service" "default" {
  # ... existing configuration ...
  security_policy = google_compute_security_policy.policy.id
}
```

### Enable Cloud CDN

Add to backend service:

```hcl
resource "google_compute_backend_service" "default" {
  # ... existing configuration ...
  enable_cdn = true

  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    default_ttl                  = 3600
    client_ttl                   = 7200
    max_ttl                      = 86400
    negative_caching             = true
    serve_while_stale            = 86400
  }
}
```

## Cost Estimate

**Resources and approximate costs:**

- Cloud Run (with scale-to-zero): ~$0/month when idle
- Load Balancer forwarding rule: ~$18/month
- Load Balancer traffic: $0.008/GB
- External IP: ~$0.01/hour (~$7/month) if reserved but not used

**Total for low-traffic demo:** ~$25-30/month

## Cleanup

To delete all resources:

```bash
terraform destroy
```

Type `yes` when prompted.

This will delete:
- All load balancer components
- The Cloud Run service
- The external IP address

## Troubleshooting

### 404 Not Found

**Issue:** Load balancer returns 404

**Solutions:**
- Wait 1-2 minutes for configuration to propagate
- Check that Cloud Run service is deployed: `gcloud run services list`
- Verify NEG is pointing to correct service
- Check URL map default backend is set

### 502 Bad Gateway

**Issue:** Load balancer returns 502

**Solutions:**
- Verify Cloud Run service is healthy
- Check service allows public access (IAM binding)
- Increase backend service timeout if requests are slow

### SSL Certificate Not Provisioning

**Issue:** HTTPS not working, certificate status is "PROVISIONING"

**Solutions:**
- Verify DNS is correctly configured (A record pointing to LB IP)
- Wait up to 60 minutes for provisioning
- Domain must be publicly resolvable
- Check certificate status: `gcloud compute ssl-certificates list`

### Terraform State Lock

**Issue:** State locked by another operation

**Solutions:**
```bash
# Force unlock (use carefully)
terraform force-unlock <lock-id>
```

## Learning Points

This demo illustrates:
- **Serverless NEGs** connect Cloud Run to load balancers
- **Multiple components** work together to form a load balancer
- **Global resources** (URL map, backend service) vs regional (NEG)
- **Separation of concerns** between routing, backends, and services
- **Infrastructure as Code** makes complex architectures repeatable

## Next Steps

- Add HTTPS with managed certificate
- Add Cloud Armor security policy
- Deploy multiple Cloud Run services with path-based routing
- Add Cloud CDN for static content caching
- Set up multi-region deployment with failover

## References

- [Cloud Run documentation](https://cloud.google.com/run/docs)
- [Application Load Balancer documentation](https://cloud.google.com/load-balancing/docs/https)
- [Serverless NEGs documentation](https://cloud.google.com/load-balancing/docs/negs/serverless-neg-concepts)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
