# Migrating from GKE to Cloud Run

A practical guide for teams considering moving workloads from Google Kubernetes Engine (GKE) to Cloud Run.

## Should You Migrate?

Not every GKE workload is a good fit for Cloud Run. Let's evaluate.

### Good Candidates for Cloud Run

**HTTP Services:**
- REST APIs
- GraphQL endpoints
- Web applications
- Webhook handlers
- Microservices with HTTP interfaces

**Characteristics:**
- Stateless
- Request/response pattern
- Standard HTTP operations
- Relatively short-lived requests (<60 min)
- Don't need persistent storage

**Example services that fit:**
```
✅ User authentication API
✅ Product catalog service
✅ Image resize service
✅ Email notification service
✅ Payment webhook handler
✅ Admin dashboard
```

### Not Good Candidates

**Non-HTTP workloads:**
- gRPC services (limited support)
- WebSocket servers (limited)
- TCP/UDP services
- Background workers (use Cloud Run Jobs instead)

**Special requirements:**
- Need specific kernel modules
- Require root access
- Need GPUs (Cloud Run has limited GPU support)
- Very large memory (>32GB)
- Stateful applications with persistent storage

**Example services that don't fit:**
```
❌ Kafka consumers
❌ gRPC-only services (no HTTP)
❌ WebSocket-heavy real-time apps
❌ Game servers
❌ Distributed databases
❌ Services needing DaemonSets
```

### The Gray Area

**Can work with modifications:**
- Batch jobs → Use Cloud Run Jobs
- Cron jobs → Cloud Scheduler + Cloud Run
- Workers → Pub/Sub + Cloud Run
- gRPC → Add HTTP transcoding or use GKE

## What You Gain

### 1. Less Operational Overhead

**GKE requires:**
- Cluster management
- Node pool configuration
- Kubernetes version upgrades
- Security patching
- Scaling policies
- Load balancer configuration

**Cloud Run:**
- Managed entirely by Google
- Auto-updates
- No cluster to manage
- Just deploy containers

### 2. Better Cost Model

**GKE:**
- Pay for nodes 24/7
- Even if idle
- Need to right-size node pools
- Over-provision for peak traffic

**Cloud Run:**
- Pay only for requests + instance time
- Scale to zero when idle
- Automatic right-sizing
- No over-provisioning needed

**Example cost comparison:**
```
Low-traffic service (1M requests/month, 200ms avg):

GKE:
- 1 node (e2-medium): $24.27/month
- Running 24/7 regardless of traffic
- Total: ~$25/month

Cloud Run:
- 1M requests: $0.40
- Compute time: ~$5
- Total: ~$5.50/month

Savings: 78%
```

### 3. Simpler Deployments

**GKE:**
```yaml
# Deployment, Service, Ingress, HPA, ServiceAccount, etc.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: gcr.io/my-project/my-app
---
apiVersion: v1
kind: Service
# ... more YAML
---
apiVersion: networking.k8s.io/v1
kind: Ingress
# ... even more YAML
```

**Cloud Run:**
```bash
gcloud run deploy my-app --image=gcr.io/my-project/my-app
```

Done!

### 4. Auto-Scaling

**GKE:**
- Configure HPA (Horizontal Pod Autoscaler)
- Configure VPA (Vertical Pod Autoscaler)
- Configure Cluster Autoscaler
- Tune thresholds

**Cloud Run:**
- Automatic
- Just set min/max instances
- Scales based on requests automatically

## What You Lose

### 1. Control and Flexibility

**GKE:**
- Full control over networking
- Custom scheduling
- DaemonSets, StatefulSets
- Sidecar containers
- Init containers

**Cloud Run:**
- Single container per service
- Limited networking control
- No custom scheduling
- Can't run privileged containers

### 2. Some Kubernetes Features

**Not available in Cloud Run:**
- Custom resource types (CRDs)
- Operators
- Service mesh (Istio/Linkerd)
- Network policies (use VPC instead)
- PersistentVolumeClaims
- ConfigMaps/Secrets (use Secret Manager)

### 3. Request Size/Timeout Limits

**GKE:**
- Configure as needed
- Can handle very large requests
- Long-running tasks

**Cloud Run:**
- Max 32MB request size
- Max 60 min per request
- Need to work within limits

## Migration Strategy

### Phase 1: Assessment

**Step 1: Inventory your services**

```bash
kubectl get deployments --all-namespaces -o json | \
    jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"'
```

**Step 2: Categorize**

For each service, determine:
- [ ] HTTP-based?
- [ ] Stateless?
- [ ] Requests < 60 min?
- [ ] No special hardware needs?
- [ ] Container < 32GB memory?

If all yes → **Good candidate**

**Step 3: Prioritize**

Start with:
1. Low-risk services (dev/staging)
2. Low-complexity services (simple APIs)
3. Services with variable traffic (good cost savings)

### Phase 2: Proof of Concept

**Pick one simple service:**

```bash
# Your current GKE deployment
kubectl get deployment my-api -o yaml

# Container image (same!)
image: gcr.io/my-project/my-api:v1.0.0
```

**Deploy to Cloud Run:**

```bash
# Use the same image!
gcloud run deploy my-api \
    --image=gcr.io/my-project/my-api:v1.0.0 \
    --region=us-central1
```

**Compare:**
- Functionality (does it work?)
- Performance (latency, throughput)
- Cost (actual spend)
- Operations (easier?)

### Phase 3: Incremental Migration

**Pattern 1: Parallel Run**

```
Traffic → Load Balancer → 80% GKE
                       → 20% Cloud Run
```

Gradually shift traffic, compare metrics.

**Pattern 2: New Features on Cloud Run**

Keep existing services on GKE, deploy new services to Cloud Run.

**Pattern 3: Service by Service**

Migrate one service completely, then next.

### Phase 4: Full Migration

Once confident:
1. Move all applicable services
2. Keep GKE for services that need it
3. Consider hybrid approach

## Code Changes Needed

Most containers "just work," but some need adjustment:

### 1. PORT Environment Variable

**GKE (typical):**
```python
app.run(port=8080)  # Hardcoded
```

**Cloud Run (required):**
```python
import os
port = int(os.environ.get('PORT', 8080))
app.run(port=port)
```

### 2. Health Checks

**GKE:**
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

**Cloud Run:**
```yaml
# In service.yaml or via gcloud
startupProbe:
  httpGet:
    path: /health
```

Ensure your health endpoint exists and responds quickly.

### 3. Configuration

**GKE (ConfigMaps):**
```yaml
envFrom:
- configMapRef:
    name: my-config
```

**Cloud Run:**
```bash
# Environment variables
gcloud run deploy my-service \
    --set-env-vars="KEY1=value1,KEY2=value2"

# Or Secret Manager
gcloud run deploy my-service \
    --set-secrets="API_KEY=api-key-secret:latest"
```

### 4. Service Discovery

**GKE (DNS):**
```python
# Calls other-service.default.svc.cluster.local
response = requests.get('http://other-service:8080/api')
```

**Cloud Run:**
```python
# Calls public Cloud Run URL with auth
SERVICE_URL = os.environ.get('OTHER_SERVICE_URL')
auth_req = google.auth.transport.requests.Request()
credentials, _ = google.auth.default()
credentials.refresh(auth_req)

response = requests.get(
    f'{SERVICE_URL}/api',
    headers={'Authorization': f'Bearer {credentials.token}'}
)
```

Need to:
- Use full URLs (not Kubernetes DNS)
- Include authentication
- Pass URLs as env vars

### 5. Storage

**GKE (PersistentVolumes):**
```yaml
volumeMounts:
- name: data
  mountPath: /data
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc
```

**Cloud Run:**
```python
# Use Cloud Storage instead
from google.cloud import storage

client = storage.Client()
bucket = client.bucket('my-bucket')
blob = bucket.blob('data/file.txt')
blob.download_to_filename('/tmp/file.txt')
```

Can't use persistent volumes - must use cloud storage.

## Networking Considerations

### GKE to Cloud Run Communication

**During migration, GKE services may need to call Cloud Run:**

**Option 1: Public Cloud Run URLs**
```python
# From GKE pod
response = requests.get('https://my-service-xxx.run.app/api')
```

Simple but goes over public internet.

**Option 2: Internal Cloud Run + VPC**
```bash
# Deploy Cloud Run as internal
gcloud run deploy my-service \
    --ingress=internal-and-cloud-load-balancing

# Access from GKE via internal load balancer
```

**Option 3: Service Mesh (Advanced)**
Use Anthos/Istio for unified mesh across GKE and Cloud Run.

### Cloud Run to GKE Communication

**Cloud Run needs to call GKE services:**

**Option 1: Expose GKE via Load Balancer**
```yaml
# GKE Service with external LB
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
```

Cloud Run calls the external IP.

**Option 2: Internal communication via VPC**
```bash
# Cloud Run with VPC connector
gcloud run deploy my-cloud-run-service \
    --vpc-connector=my-connector

# Calls GKE internal service
response = requests.get('http://10.0.1.5:8080/api')
```

## Terraform Example: Hybrid Setup

```hcl
# GKE Cluster (existing)
resource "google_container_cluster" "main" {
  name     = "my-cluster"
  location = "us-central1"
  # ... GKE config
}

# Cloud Run Service (new)
resource "google_cloud_run_service" "new_api" {
  name     = "new-api"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/my-project/new-api:v1"
      }
    }
  }
}

# Load Balancer routing to both
resource "google_compute_url_map" "hybrid" {
  name = "hybrid-lb"

  default_service = google_compute_backend_service.gke_backend.id

  host_rule {
    hosts        = ["api.example.com"]
    path_matcher = "paths"
  }

  path_matcher {
    name = "paths"

    # New endpoints → Cloud Run
    path_rule {
      paths   = ["/v2/*"]
      service = google_compute_backend_service.cloudrun_backend.id
    }

    # Legacy endpoints → GKE
    default_service = google_compute_backend_service.gke_backend.id
  }
}
```

## Migration Checklist

### Before Migration

- [ ] Confirm service is HTTP-based
- [ ] Check it's stateless
- [ ] Verify container works locally
- [ ] Document environment variables
- [ ] List all dependencies
- [ ] Check request/response sizes
- [ ] Verify timeouts are reasonable

### During Migration

- [ ] Deploy to Cloud Run in dev/test
- [ ] Run integration tests
- [ ] Load test Cloud Run version
- [ ] Compare metrics (latency, errors)
- [ ] Test auth/IAM setup
- [ ] Verify logging works
- [ ] Configure monitoring/alerts

### After Migration

- [ ] Gradual traffic shift (10% → 50% → 100%)
- [ ] Monitor error rates
- [ ] Check cost changes
- [ ] Update documentation
- [ ] Train team on new tools
- [ ] Decommission GKE resources (when safe)

## Real-World Migration Example

### Before (GKE)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-api
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: api
        image: gcr.io/my-project/user-api:v1.5.0
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: url
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

**Monthly cost:** ~$72 (3 replicas × $24/node)

### After (Cloud Run)

```bash
# Deploy
gcloud run deploy user-api \
    --image=gcr.io/my-project/user-api:v1.5.0 \
    --region=us-central1 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --set-secrets="DATABASE_URL=db-url:latest"
```

**Monthly cost:** ~$12 (actual usage)

**Savings:** 83%

## Hybrid Architecture Benefits

You don't have to choose one or the other!

**Common pattern:**
```
GKE:
- Complex stateful services
- Services needing special Kubernetes features
- High-control workloads
- Non-HTTP services

Cloud Run:
- Simple HTTP APIs
- Event-driven functions
- Variable-traffic services
- New microservices
```

**Benefits:**
- Use the right tool for each job
- Reduce GKE cluster size (cost savings)
- Simpler for new services
- Keep existing investments

## Decision Framework

**Should this service move to Cloud Run?**

```
Is it HTTP-based? ────────────────────> No ──> Keep on GKE
    │ Yes
    ▼
Is it stateless? ─────────────────────> No ──> Keep on GKE
    │ Yes
    ▼
Requests < 60 min? ───────────────────> No ──> Keep on GKE
    │ Yes
    ▼
No special K8s features needed? ─────> No ──> Keep on GKE
    │ Yes
    ▼
Simple deployment acceptable? ────────> No ──> Keep on GKE
    │ Yes
    ▼
✅ Good candidate for Cloud Run!
```

## Key Takeaways

- Not all GKE workloads should migrate (and that's OK)
- HTTP services are best candidates
- Start with low-risk services
- Test thoroughly before full migration
- Hybrid approaches work well
- Significant cost savings possible
- Less operational overhead
- May need code changes (PORT, health checks, storage)
- Use both GKE and Cloud Run together

## Recommended Approach

1. **Audit** your GKE services
2. **Identify** good candidates (HTTP, stateless, simple)
3. **POC** with one service
4. **Measure** results (cost, performance, operations)
5. **Decide**: Migrate all, hybrid, or stay on GKE
6. **Migrate** incrementally
7. **Monitor** and optimize

---

## Summary

You've completed the Cloud Run Advanced section! You should now understand:
- Infrastructure as code approaches (gcloud vs Terraform)
- VPC networking and private services
- Scaling strategies and optimization
- Common pitfalls and how to avoid them
- Migration strategies from GKE

Return to [main README](../README.md) for the full training overview.
