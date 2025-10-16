# Cloud Run Core Concepts

Deep dive into how Cloud Run works under the hood.

## Container-Based Execution

Cloud Run runs your code in containers.

### What's a Container?

A container packages your application with all its dependencies:
- Code
- Runtime (Python, Node.js, Go, etc.)
- System libraries
- Configuration files

**Key characteristics:**
- Isolated from host system
- Portable (runs anywhere containers run)
- Lightweight (shares host OS kernel)

### The Container Contract

Your container must:
1. **Listen on a port** specified by `PORT` environment variable
2. **Start within 4 minutes** (configurable, max 15 minutes)
3. **Respond to HTTP requests** on that port
4. **Be stateless** (can be stopped/started anytime)

**Example (Python):**
```python
import os
port = int(os.environ.get('PORT', 8080))
app.run(host='0.0.0.0', port=port)
```

### Dockerfile Basics

If using `--source`, Cloud Run uses buildpacks. For custom builds, you need a Dockerfile:

```dockerfile
# Start from base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Start the application
CMD ["python", "app.py"]
```

**Best practices:**
- Use official base images
- Multi-stage builds for smaller images
- Minimize layers
- Don't run as root
- Use `.dockerignore`

## The Request Lifecycle

Understanding what happens when a request arrives:

### 1. Request Arrives

Client sends HTTP request to your service URL:
```
https://my-service-abc123-uc.a.run.app/api/hello
```

### 2. Authentication Check (if required)

Cloud Run verifies the request has proper authentication:
- Bearer token with identity
- `run.invoker` permission
- Or `allUsers` allowed

### 3. Container Instance Selection

Cloud Run routes to a container instance:
- If instances exist: Route to one (load balanced)
- If no instances: Start a new one (**cold start**)
- If all busy and below max: Start additional instances

### 4. Request Handling

Container receives the request:
- Standard HTTP request with headers
- Cloud Run adds headers (e.g., `X-Cloud-Trace-Context`)
- Your code processes and responds

### 5. Response

Container sends HTTP response back:
- Status code (200, 404, 500, etc.)
- Headers
- Body

### 6. Container Lifecycle

After handling requests:
- Container stays alive for next request
- Idle timeout: ~15 minutes (may vary)
- Can serve multiple requests (concurrency)

## Auto-Scaling

Cloud Run automatically adjusts the number of container instances.

### How Scaling Works

```
Scaling = (Incoming requests) / (Concurrency per instance)
```

**Example:**
- Concurrency setting: 80 requests per instance
- Incoming rate: 800 requests/second
- Instances needed: 800 / 80 = 10 instances

### Scaling Parameters

**Max instances:**
```bash
--max-instances=100  # Max containers (default: 100)
```
- Limits scale-up
- Prevents runaway costs
- Prevents overwhelming downstream services

**Min instances:**
```bash
--min-instances=1  # Keep at least 1 running
```
- Eliminates cold starts for that minimum
- Costs money even when idle
- Use for latency-sensitive endpoints

**Concurrency:**
```bash
--concurrency=80  # Requests per instance (default: 80, max: 1000)
```
- How many requests one instance handles simultaneously
- Higher = fewer instances needed
- Lower = more instances, better isolation

### Cold Starts

**What is it?**
When no instances are running and a request arrives:
1. Cloud Run starts a new container
2. Container boots up
3. Application initializes
4. Request is handled

**Typical duration:** 100ms to 3 seconds
- Depends on: Container size, language, initialization code
- Python/Node: ~500ms
- Go: ~100-300ms
- Java: 1-3s (due to JVM startup)

**Mitigation strategies:**
1. **Min instances**: Keep instances warm
2. **Optimize container**: Smaller image, faster startup
3. **Lazy initialization**: Don't load everything at startup
4. **CPU boost**: Allocate more CPU during startup

### Scale to Zero

When there are no requests:
- Instances idle for ~15 minutes
- Then Cloud Run shuts them down
- Scale to zero = $0 cost when idle

**When to avoid scale to zero:**
- Latency-sensitive user-facing apps
- Real-time APIs
- Services with expensive initialization

Use min instances in these cases.

## Request Concurrency

How many requests can one container instance handle at once?

### Default Behavior

- Default: 80 concurrent requests per instance
- Max: 1000 concurrent requests

### Concurrency Models

**High concurrency (80-1000):**
- Good for: I/O-bound workloads (APIs calling databases)
- Fewer instances needed
- Lower cost
- Requires thread-safe code

**Low concurrency (1-10):**
- Good for: CPU-intensive workloads
- More instances needed
- Better isolation
- Easier to reason about

**Example:**
```bash
# Set concurrency to 1 (one request per instance)
gcloud run services update my-service \
    --concurrency=1

# Set concurrency to max
gcloud run services update my-service \
    --concurrency=1000
```

### Concurrency vs Performance

**Too high:**
- Requests may queue/timeout
- Memory pressure
- CPU contention

**Too low:**
- More instances = higher cost
- More cold starts
- Underutilized resources

**Sweet spot:** Test with realistic load!

## CPU Allocation

Cloud Run offers two CPU allocation modes:

### 1. CPU Allocated Only During Request Handling (Default)

```bash
--cpu-throttling  # Default
```

**Behavior:**
- CPU available only while processing requests
- Throttled when no requests (container still running)
- Cheaper (only pay for CPU during requests)

**Good for:**
- Stateless HTTP services
- Services with no background work

### 2. CPU Always Allocated

```bash
--no-cpu-throttling
```

**Behavior:**
- CPU available all the time container is running
- Even when no requests
- More expensive

**Good for:**
- Background processing in container
- Long-running initialization
- Caching/background tasks

## Memory and CPU Resources

### Memory Allocation

```bash
--memory=512Mi  # Options: 128Mi to 32Gi
```

**Guidelines:**
- Start with 256Mi or 512Mi
- Monitor actual usage
- Scale up if OOM (out of memory) errors

**Memory includes:**
- Application code
- Loaded libraries
- In-memory data
- Buffers/caches

### CPU Allocation

```bash
--cpu=1  # Options: 0.08 (80m) to 8
```

**CPU units:**
- 1 CPU = 1 vCPU core
- Fractional CPUs available (0.5, 0.25, etc.)
- More CPU = faster request handling

**Default behavior:**
- Memory < 1Gi: 1 CPU
- Memory ≥ 1Gi: Proportional CPU allocation

### CPU Boost

```bash
--cpu-boost  # Allocate extra CPU during startup
```

Helps reduce cold start latency by giving more resources during initialization.

## Networking and Connectivity

### Ingress Control

Who can send requests to your service?

```bash
# Public internet (default)
--ingress=all

# Internal traffic + Cloud Load Balancing
--ingress=internal-and-cloud-load-balancing

# Only internal VPC traffic
--ingress=internal
```

**Use cases:**
- `all`: Public APIs, websites
- `internal-and-cloud-load-balancing`: Internal services with LB
- `internal`: Private services, no public access

### Egress Control

Where can your service send traffic?

**Default:** Direct to internet via Google's network

**VPC Egress:**
```bash
--vpc-egress=all-traffic  # Route all through VPC Connector
--vpc-egress=private-ranges-only  # Only private IPs through VPC
```

Requires VPC Connector setup.

### Custom Domains

Map your own domain to Cloud Run:

```bash
gcloud run domain-mappings create \
    --service=my-service \
    --domain=api.example.com
```

Automatically provisions TLS certificate.

## Security

### Service Identity

Every Cloud Run service runs as a service account:

```bash
# Deploy with specific service account
gcloud run deploy my-service \
    --service-account=my-sa@project.iam.gserviceaccount.com
```

**Default:** Compute Engine default service account
- Has broad permissions
- **Best practice:** Create dedicated service accounts

### Invoker Permissions

Control who can call your service:

```bash
# Public (anyone)
--allow-unauthenticated

# Require authentication (IAM)
--no-allow-unauthenticated
```

**Authenticated requests:**
```bash
# Get identity token
TOKEN=$(gcloud auth print-identity-token)

# Call service
curl -H "Authorization: Bearer $TOKEN" https://service-url
```

### Service-to-Service Authentication

Service A calling Service B:

1. Service A's service account needs `run.invoker` on Service B
2. Service A gets identity token
3. Sends token in `Authorization` header

**In code (Python):**
```python
import google.auth
import google.auth.transport.requests
import requests

def call_service(url):
    auth_req = google.auth.transport.requests.Request()
    credentials, project = google.auth.default()
    credentials.refresh(auth_req)

    response = requests.get(
        url,
        headers={'Authorization': f'Bearer {credentials.token}'}
    )
    return response.text
```

## Revisions and Traffic Management

### Revision Creation

New revision created when you change:
- Container image
- Environment variables
- Memory/CPU settings
- Concurrency settings
- Service account
- VPC connector

**NOT created when you change:**
- IAM bindings
- Min/max instances (these are service-level, not revision)

### Revision Naming

Format: `{service}-{number}-{hash}`

Example: `my-service-00042-abc`

Can specify custom suffixes:
```bash
gcloud run deploy my-service \
    --revision-suffix=v1-2-0
```

Result: `my-service-v1-2-0-def`

### Traffic Patterns

**100% to latest (default):**
```bash
--to-latest
```

**Canary (gradual rollout):**
```bash
--to-revisions=new-revision=10,old-revision=90
```

Gradually increase new revision's percentage.

**Blue/Green:**
```bash
# Green (old) serving
--to-revisions=green-revision=100

# Deploy blue (new) with no traffic
gcloud run deploy my-service --no-traffic

# Cut over
--to-revisions=blue-revision=100
```

**A/B Testing:**
```bash
--to-revisions=variant-a=50,variant-b=50
```

### Rollback

```bash
# Get previous revision
PREV=$(gcloud run revisions list --service=my-service --limit=2 --format='value(name)' | tail -1)

# Route all traffic to it
gcloud run services update-traffic my-service --to-revisions=$PREV=100
```

## Logging and Monitoring

### Structured Logging

Write JSON logs for better querying:

```python
import json
import sys

def log(message, severity='INFO'):
    entry = {
        'severity': severity,
        'message': message,
    }
    print(json.dumps(entry), file=sys.stdout, flush=True)
```

### Request Logging

Cloud Run automatically logs requests:
- Request URL, method
- Response status, size
- Latency
- User agent

### Metrics

Available metrics:
- **Request count** - Total requests over time
- **Request latency** - p50, p95, p99
- **Instance count** - Number of running containers
- **Billable container time** - Instance-seconds charged
- **CPU utilization** - Percentage of allocated CPU used
- **Memory utilization** - Percentage of allocated memory used

Access via:
- Cloud Console
- Cloud Monitoring API
- Exported to Cloud Monitoring

## Billing

### What You Pay For

**Container instance time:**
- Billed in 100ms increments
- Only while instance is running
- If min-instances > 0, you pay even when idle

**CPU:**
- Based on allocated CPU
- If throttling enabled: Only during requests
- If not throttled: Entire time instance runs

**Memory:**
- Based on allocated memory
- Billed for time instance is running

**Networking:**
- Requests: Free within quota, then $0.40/million
- Egress (outbound): $0.12/GB (after first 1GB)

### Cost Optimization

1. **Scale to zero** when possible (min-instances=0)
2. **Right-size resources** (don't over-allocate memory/CPU)
3. **Use CPU throttling** if no background work needed
4. **Set max-instances** to prevent runaway costs
5. **Optimize cold starts** to reduce instance time
6. **Use high concurrency** to need fewer instances

### Pricing Calculator

Estimate costs: https://cloud.google.com/products/calculator

**Example:**
- 1 million requests/month
- 200ms average duration
- 512MB memory, 1 CPU
- ≈ $5-10/month

## Cloud Run vs Other Options

| Feature | Cloud Run | Cloud Run Jobs | GKE Autopilot | App Engine |
|---------|-----------|----------------|---------------|------------|
| Workload | HTTP services | Batch tasks | Any containers | HTTP services |
| Scaling | Auto (0-1000+) | Per job | Auto | Auto |
| Max duration | 60 min/request | 24 hours | No limit | 60 min |
| Configuration | Simple | Simple | Complex | Moderate |
| Control | Low | Low | High | Low |

**Choose Cloud Run when:**
- HTTP-based services
- Want simplicity
- Need scale-to-zero
- Standard container workload

## Key Takeaways

- Cloud Run is fully managed, container-based compute
- Containers must listen on `PORT`, respond to HTTP
- Auto-scales based on requests and concurrency
- Scale to zero saves costs when idle
- Revisions are immutable snapshots
- Traffic splitting enables safe deployments
- Right-sizing resources is important for cost and performance

---

Next: [Cloud Run Advanced Topics →](../03-cloud-run-advanced/)
