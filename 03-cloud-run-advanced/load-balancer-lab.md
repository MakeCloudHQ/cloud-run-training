# Hands-On Lab: Cloud Run with Load Balancer

Deploy a Cloud Run service and put it behind an Application Load Balancer using the Google Cloud Console.

## Lab Overview

**Time:** 45-60 minutes

**What you'll build:**
```
Internet → Load Balancer (External IP) → Cloud Run Service
```

**What you'll learn:**
- Deploy Cloud Run service
- Create Serverless Network Endpoint Group (NEG)
- Configure Application Load Balancer components
- Test traffic through load balancer
- Optional: Add Cloud Armor protection

## Prerequisites

- Google Cloud project with billing enabled
- `Editor` or `Owner` role
- APIs enabled:
  - Cloud Run API
  - Compute Engine API

## Part 1: Deploy Cloud Run Service (10 minutes)

We'll use Google's sample "hello" container.

### Step 1: Deploy Service via gcloud

Open Cloud Shell and run:

```bash
gcloud run deploy hello-lb \
    --image=us-docker.pkg.dev/cloudrun/container/hello \
    --region=europe-west2 \
    --allow-unauthenticated \
    --ingress=all
```

**Note the service URL** - you'll compare this to the load balancer URL later.

### Step 2: Test the Service

```bash
SERVICE_URL=$(gcloud run services describe hello-lb \
    --region=europe-west2 \
    --format='value(status.url)')

curl $SERVICE_URL
```

You should see the Hello World page HTML.

### Step 3: Open Cloud Console

Navigate to **Cloud Run** in the console to see your deployed service.

## Part 2: Create Serverless Network Endpoint Group (10 minutes)

The NEG connects your Cloud Run service to the load balancer.

### Step 1: Navigate to Network Endpoint Groups

1. In Cloud Console, search for **"Network endpoint groups"**
2. Or go to: **Compute Engine → Network endpoint groups**
3. Click **Create Network Endpoint Group**

### Step 2: Configure the NEG

**Basic configuration:**
- **Name:** `hello-lb-neg`
- **Network endpoint group type:** Select **Serverless network endpoint group**

**Serverless network endpoint group:**
- **Target:** Select **Cloud Run service**
- **Region:** `europe-west2`
- **Service:** Select `hello-lb`

Click **Create**

**What you just did:** Created a reference that the load balancer can use to route to your Cloud Run service.

## Part 3: Create Backend Service (10 minutes)

The backend service configures how traffic is sent to your NEG.

### Step 1: Navigate to Backend Services

1. Search for **"Backend services"** in console
2. Or go to: **Network services → Load balancing → Backend services**
3. Click **Create Backend Service**

### Step 2: Configure Backend Service

**Name and protocol:**
- **Name:** `hello-lb-backend`
- **Backend type:** `Internet network endpoint group`
- **Protocol:** `HTTPS`

**Backends:**
- Click **Add Backend**
- **Network endpoint group:** Select `hello-lb-neg`
- **Balancing mode:** `Rate` (requests per second)
- **Maximum RPS:** `100` (per instance)
- Click **Done**

**Health check:**
- The default health check settings are fine for Cloud Run
- Cloud Run manages instance health internally

**Advanced configurations (Optional):**
- **Timeout:** Leave at 30 seconds (or increase if your service needs longer)
- **Session affinity:** None (default)

Click **Create**

## Part 4: Create URL Map (5 minutes)

The URL map defines routing rules.

### Step 1: Navigate to URL Maps

1. Search for **"URL maps"** in console
2. Or go to: **Network services → Load balancing → URL maps**
3. Click **Create URL Map**

### Step 2: Configure URL Map

**Name:** `hello-lb-url-map`

**Default backend service:** Select `hello-lb-backend`

**Host and path rules:** Skip for now (we'll just use the default rule)

Click **Create**

**What this does:** Routes all traffic to your backend service. You could add rules here to route different paths to different services.

## Part 5: Reserve External IP Address (5 minutes)

Get a stable external IP for your load balancer.

### Step 1: Navigate to External IP Addresses

1. Search for **"External IP addresses"** or **"IP addresses"**
2. Or go to: **VPC network → IP addresses**
3. Click **Reserve External Static Address**

### Step 2: Configure IP Address

**Name:** `hello-lb-ip`

**IP version:** IPv4

**Type:** `Global`

**Tier:** `Premium`

Click **Reserve**

**Note the IP address** - this is what you'll use to access your service.

## Part 6: Create SSL Certificate (Optional but Recommended)

For HTTPS, you need a certificate. We'll use a self-signed cert for testing.

**Option A: Self-Signed Certificate (Quick, for testing)**

You can skip this and use HTTP target proxy instead. If you want HTTPS, you'll need to provide your own certificate or use Google-managed certificates (requires a domain).

**For this lab, we'll use HTTP** to keep it simple.

**Option B: Google-Managed Certificate (Production)**

Requires:
- Your own domain
- DNS configured to point to the load balancer IP
- 15-60 minutes for provisioning

We'll skip this for the lab.

## Part 7: Create Target HTTP Proxy (5 minutes)

The target proxy receives traffic and uses the URL map for routing.

### Step 1: Navigate to Target HTTP Proxies

1. Search for **"Target HTTP proxies"**
2. Or go to: **Network services → Load balancing → Target proxies**
3. Click **Create Target HTTP Proxy**

### Step 2: Configure Target Proxy

**Name:** `hello-lb-proxy`

**URL map:** Select `hello-lb-url-map`

Click **Create**

## Part 8: Create Forwarding Rule (10 minutes)

The forwarding rule is the entry point - it receives traffic on the external IP.

### Step 1: Navigate to Forwarding Rules

1. Search for **"Forwarding rules"**
2. Or go to: **Network services → Load balancing → Forwarding rules**
3. Click **Create Forwarding Rule**

### Step 2: Configure Forwarding Rule

**Name:** `hello-lb-forwarding-rule`

**Network tier:** `Premium`

**IP version:** `IPv4`

**IP address:** Select `hello-lb-ip` (the IP you reserved earlier)

**Port:** `80` (HTTP)

**Target:** Select `hello-lb-proxy` (the target proxy you created)

**Service label:** Leave empty (optional, for DNS)

Click **Create**

## Part 9: Test the Load Balancer (5 minutes)

### Step 1: Get the Load Balancer IP

In Cloud Shell:

```bash
LB_IP=$(gcloud compute addresses describe hello-lb-ip \
    --global \
    --format='value(address)')

echo "Load Balancer IP: $LB_IP"
```

### Step 2: Test with curl

```bash
# Test the load balancer
curl http://$LB_IP

# You might need to wait 1-2 minutes for configuration to propagate
# If you get errors, wait and try again
```

### Step 3: Test in Browser

Open your browser and navigate to:
```
http://YOUR_LB_IP
```

You should see the same Hello World page!

### Step 4: Compare

Notice:
- Direct Cloud Run URL: `https://hello-lb-xxx.run.app`
- Load Balancer URL: `http://YOUR_LB_IP`

Both reach the same service, but the load balancer gives you more control.

## Part 10: View Load Balancer Details (5 minutes)

### Step 1: Navigate to Load Balancing Page

1. Go to **Network services → Load balancing**
2. You should see your load balancer listed

### Step 2: Click on Your Load Balancer

Explore:
- **Frontend** - The forwarding rule and IP
- **Host and path rules** - Your URL map
- **Backend** - The backend service and NEG
- **Monitoring** - Request counts and latency (may take a few minutes to populate)

### Step 3: Generate Some Traffic

```bash
# Send 20 requests
for i in {1..20}; do
  curl -s http://$LB_IP > /dev/null
  echo "Request $i sent"
  sleep 1
done
```

Refresh the monitoring tab to see metrics.

## Optional Challenge 1: Add Cloud Armor

Add basic DDoS protection with Cloud Armor.

### Step 1: Create Security Policy

1. Search for **"Cloud Armor"** or go to **Network security → Cloud Armor**
2. Click **Create Policy**
3. **Name:** `hello-lb-armor`
4. **Policy type:** `Backend security policy`
5. Click **Next**

### Step 2: Add Rules

**Default rule:**
- **Action:** `Allow`
- **Priority:** `2147483647` (lowest)

**Rate limiting rule:**
- Click **Add Rule**
- **Description:** `Rate limit`
- **Mode:** `Rate-based ban`
- **Match:** All traffic
- **Rate limit:** `100` requests per `60` seconds
- **Ban duration:** `600` seconds
- **Action:** `Deny (403)`
- **Priority:** `1000`
- Click **Done**

Click **Create Policy**

### Step 3: Attach to Backend Service

1. Go to **Backend services**
2. Click on `hello-lb-backend`
3. Click **Edit**
4. Under **Cloud Armor security policy**, select `hello-lb-armor`
5. Click **Save**

### Step 4: Test Rate Limiting

```bash
# Try to exceed rate limit
for i in {1..150}; do
  curl -s http://$LB_IP
done
```

After ~100 requests in a minute, you should start seeing 403 Forbidden responses.

## Optional Challenge 2: Add Path-Based Routing

Deploy a second service and route different paths to different services.

### Step 1: Deploy Second Service

```bash
gcloud run deploy goodbye-lb \
    --image=us-docker.pkg.dev/cloudrun/container/hello \
    --region=europe-west2 \
    --allow-unauthenticated
```

### Step 2: Create NEG for Second Service

Follow Part 2 steps, but:
- Name: `goodbye-lb-neg`
- Service: `goodbye-lb`

### Step 3: Create Backend for Second Service

Follow Part 3 steps, but:
- Name: `goodbye-lb-backend`
- NEG: `goodbye-lb-neg`

### Step 4: Update URL Map

1. Go to **URL maps**
2. Click on `hello-lb-url-map`
3. Click **Edit**
4. Under **Host and path rules**, click **Add Host and Path Rule**
5. **Hosts:** `*` (all hosts)
6. **Paths:**
   - Path: `/goodbye/*`
   - Backend: `goodbye-lb-backend`
7. Click **Done**
8. Click **Save**

### Step 5: Test Routing

```bash
# Should go to hello service (default)
curl http://$LB_IP/

# Should go to goodbye service
curl http://$LB_IP/goodbye/
```

## Part 11: Clean Up (5 minutes)

To avoid charges, delete the resources:

```bash
# Delete forwarding rule
gcloud compute forwarding-rules delete hello-lb-forwarding-rule --global --quiet

# Delete target proxy
gcloud compute target-http-proxies delete hello-lb-proxy --quiet

# Delete URL map
gcloud compute url-maps delete hello-lb-url-map --quiet

# Delete backend services
gcloud compute backend-services delete hello-lb-backend --global --quiet

# Delete NEG
gcloud compute network-endpoint-groups delete hello-lb-neg --region=europe-west2 --quiet

# Release IP
gcloud compute addresses delete hello-lb-ip --global --quiet

# Delete Cloud Run services
gcloud run services delete hello-lb --region=europe-west2 --quiet
gcloud run services delete goodbye-lb --region=europe-west2 --quiet

# Delete Cloud Armor policy (if created)
gcloud compute security-policies delete hello-lb-armor --quiet
```

## Troubleshooting

### Load Balancer Returns 404

**Check:**
1. Backend service is healthy (go to backend service page)
2. NEG is correctly pointing to Cloud Run service
3. URL map default backend is set correctly
4. Wait 1-2 minutes for configuration to propagate

### Load Balancer Returns 502 Bad Gateway

**Check:**
1. Cloud Run service is running (`gcloud run services describe hello-lb --region=europe-west2`)
2. Cloud Run service allows unauthenticated access (or load balancer has proper auth)
3. Backend service timeout is sufficient

### Can't Access Load Balancer IP

**Check:**
1. Forwarding rule is created and active
2. Using correct IP address
3. Using HTTP (not HTTPS) if you didn't configure SSL
4. No VPN/firewall blocking access

### Cloud Armor Not Blocking

**Check:**
1. Security policy is attached to backend service
2. Rules have correct priority (lower number = higher priority)
3. Test criteria matches your traffic pattern
4. Wait 1-2 minutes for policy to take effect

## Key Takeaways

- Load balancers require multiple components working together
- Serverless NEGs connect serverless services to load balancers
- Configuration takes 1-2 minutes to propagate
- Cloud Armor adds security at the load balancer level
- Path-based routing enables multiple services behind one IP
- Console UI makes it easy to visualize the architecture

## Next Steps

- Try the Terraform demo to see infrastructure-as-code approach
- Add custom domain with Google-managed SSL certificate
- Set up multi-region load balancing
- Integrate with Cloud CDN for static content

---

**Questions?** Discuss what you've learned!
