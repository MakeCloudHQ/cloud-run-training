# Cloud Run with Load Balancer - Terraform Demo

This Terraform configuration deploys a Cloud Run service behind an Application Load Balancer with HTTPS and a Google-managed SSL certificate.

## What This Creates

```
Internet → External IP → HTTP Proxy → URL Map → Backend Service → NEG → Cloud Run
```

**Resources created:**
- Cloud Run service (using Google's hello container)
- Serverless Network Endpoint Group (NEG)
- Backend Service
- URL Map for routing
- Google-managed SSL certificate
- HTTPS Target Proxy
- HTTP to HTTPS redirect
- Global Forwarding Rules (HTTPS on 443, HTTP on 80)
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
- **A domain name you control** (for SSL certificate)
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
domain_name  = "api.example.com"  # Your actual domain
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan
```

You should see 11 resources to be created:
- `google_cloud_run_v2_service.hello`
- `google_cloud_run_v2_service_iam_member.public_access`
- `google_compute_region_network_endpoint_group.cloudrun_neg`
- `google_compute_backend_service.default`
- `google_compute_url_map.default`
- `google_compute_managed_ssl_certificate.default`
- `google_compute_target_https_proxy.default`
- `google_compute_url_map.http_redirect`
- `google_compute_target_http_proxy.http_redirect`
- `google_compute_global_address.default`
- `google_compute_global_forwarding_rule.https`
- `google_compute_global_forwarding_rule.http`

### Step 4: Apply

```bash
terraform apply
```

Type `yes` when prompted.

This will take 2-3 minutes to complete.

### Step 5: Configure DNS

**IMPORTANT:** Before the SSL certificate will provision, you must configure DNS.

Get the load balancer IP:
```bash
terraform output load_balancer_ip
```

Create an A record in your DNS provider:
```
api.example.com  →  34.120.1.5
```

### Step 6: Wait for SSL Certificate

SSL certificate provisioning takes **15-60 minutes** after DNS is configured.

Check certificate status:
```bash
gcloud compute ssl-certificates describe hello-lb-cert --global
```

Look for `status: ACTIVE`. While provisioning, it will show `PROVISIONING`.

### Step 7: Test the Deployment

After the certificate is `ACTIVE`, test:

**Test via custom domain:**
```bash
curl https://api.example.com
```

**Test HTTP redirect:**
```bash
curl -I http://api.example.com
# Should return 301 redirect to https://
```

**Test direct Cloud Run URL:**
```bash
CLOUD_RUN_URL=$(terraform output -raw cloud_run_url)
curl $CLOUD_RUN_URL
```

All should return the Hello World HTML page.

### Step 8: View in Console

Open the load balancer in Google Cloud Console:
```
https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers
```

Explore the components:
- Frontend (IP and forwarding rule)
- Host and path rules (URL map)
- Backend (backend service and NEG)

## How It Works

### HTTPS with Managed Certificate

The configuration automatically provisions a Google-managed SSL certificate for your domain. This requires:

1. **DNS Configuration:** Your domain must point to the load balancer IP
2. **Domain Validation:** Google validates you control the domain via DNS
3. **Certificate Provisioning:** Takes 15-60 minutes
4. **Automatic Renewal:** Google handles certificate renewal

### HTTP to HTTPS Redirect

All HTTP traffic (port 80) is automatically redirected to HTTPS (port 443):
- Separate URL map for HTTP with redirect rule
- Separate HTTP target proxy
- HTTP forwarding rule routes to redirect proxy
- 301 permanent redirect to HTTPS version

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
- Check DNS propagation: `dig api.example.com` or `nslookup api.example.com`
- Wait up to 60 minutes for provisioning after DNS is correct
- Domain must be publicly resolvable (not localhost or private domain)
- Check certificate status: `gcloud compute ssl-certificates describe hello-lb-cert --global`
- View detailed status in Console: Network Services → Load balancing → Certificates

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
