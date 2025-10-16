# Scaling Strategies

Master Cloud Run's auto-scaling to optimize performance and cost.

## How Auto-Scaling Works

Cloud Run automatically creates and destroys container instances based on incoming requests.

**Formula:**
```
Instances = ceil(Incoming requests / Concurrency per instance)
```

**Example:**
- 400 requests/second incoming
- 80 concurrent requests per instance
- Result: 5 instances

## Key Scaling Parameters

### 1. Min Instances

```bash
gcloud run services update my-service --min-instances=2
```

**What it does:**
- Keeps at least N instances always running
- Eliminates cold starts for those instances
- You pay even when idle

**When to use:**
- Latency-sensitive user-facing apps
- Expensive initialization (ML models, caches)
- Consistent traffic baseline
- SLA requirements for response time

**Cost implications:**
```
Cost = (min_instances × memory × hours) + request handling costs
```

Example: 1 instance, 512MB, 24/7 = ~$10-15/month (even with zero traffic)

**Strategy:**
- Start with 0
- Monitor cold starts
- Add min instances only if necessary
- Use minimum needed (often 1-2 is enough)

### 2. Max Instances

```bash
gcloud run services update my-service --max-instances=100
```

**What it does:**
- Caps maximum instances
- Prevents runaway costs
- Protects downstream services

**When to use:**
- Always! Set a reasonable limit
- Prevent quota exhaustion
- Protect databases from connection storms
- Cost control

**Determining max:**
```
Max instances = (DB max connections / connections per instance)

Example:
- Cloud SQL: 100 connections max
- App uses 5 connections per instance
- Max instances = 20
```

**Default:** 100 (can request increase to 1000)

### 3. Concurrency

```bash
gcloud run services update my-service --concurrency=80
```

**What it does:**
- Max simultaneous requests per instance
- Default: 80
- Range: 1-1000

**High concurrency (80-1000):**
- Fewer instances needed
- Lower cost
- Good for I/O-bound workloads (APIs, web servers)
- Requires thread-safe code

**Low concurrency (1-10):**
- More instances needed
- Better for CPU-intensive tasks
- Easier to reason about
- Better isolation

**Testing concurrency:**
```bash
# Load test with different concurrency values
# Monitor: CPU, memory, latency, error rate
hey -n 10000 -c 100 https://my-service.run.app
```

### 4. CPU Allocation

```bash
# CPU only during requests (default)
gcloud run services update my-service --cpu-throttling

# CPU always allocated
gcloud run services update my-service --no-cpu-throttling
```

**CPU throttling (default):**
- CPU available only during request processing
- Throttled between requests
- Cheaper
- Good for stateless HTTP services

**Always allocated:**
- CPU available all the time
- Even between requests
- More expensive
- Good for background processing, warming caches

**When to disable throttling:**
- Background workers
- Applications with startup tasks
- Services maintaining connections
- WebSocket servers

## Scaling Patterns

### Pattern 1: Scale to Zero (Cost Optimized)

**Configuration:**
```bash
gcloud run services update my-service \
    --min-instances=0 \
    --max-instances=100 \
    --concurrency=80
```

**Best for:**
- Development/staging environments
- Periodic workloads (nightly jobs)
- Low-traffic services
- Cost-sensitive deployments

**Trade-offs:**
- Cold starts on first request after idle
- Lower cost when idle

### Pattern 2: Always Warm (Performance Optimized)

**Configuration:**
```bash
gcloud run services update my-service \
    --min-instances=3 \
    --max-instances=100 \
    --concurrency=80
```

**Best for:**
- Production user-facing apps
- High-traffic services
- Latency-sensitive APIs
- Services with slow initialization

**Trade-offs:**
- Higher base cost
- No cold starts (for min instances)
- Faster response times

### Pattern 3: Hybrid (Balanced)

**Configuration:**
```bash
gcloud run services update my-service \
    --min-instances=1 \
    --max-instances=50 \
    --concurrency=100
```

**Best for:**
- Medium-traffic production services
- APIs with moderate SLAs
- Services with predictable baseline

**Trade-offs:**
- Minimal cold starts
- Reasonable cost
- Good balance

### Pattern 4: CPU-Intensive Workload

**Configuration:**
```bash
gcloud run services update my-service \
    --concurrency=1 \
    --cpu=2 \
    --memory=2Gi \
    --max-instances=20
```

**Best for:**
- Image processing
- Video transcoding
- Data transformation
- ML inference (non-GPU)

**Trade-offs:**
- Lower concurrency = more instances
- Higher resource allocation
- Better performance per request

### Pattern 5: High-Throughput API

**Configuration:**
```bash
gcloud run services update my-service \
    --concurrency=250 \
    --cpu=2 \
    --memory=1Gi \
    --min-instances=5 \
    --max-instances=100
```

**Best for:**
- High-traffic APIs
- I/O-bound workloads
- Microservices with fast operations

**Trade-offs:**
- High concurrency = fewer instances
- Must handle concurrent requests safely
- Cost-effective at scale

## Cold Start Optimization

### What is a Cold Start?

Time from request arrival to application ready when no instances running.

**Typical durations:**
- Go: 100-300ms
- Python: 300-800ms
- Node.js: 300-800ms
- Java: 1-3 seconds

### Reducing Cold Start Time

**1. Minimize container size:**
```dockerfile
# Before: 800MB
FROM python:3.11
COPY . .
RUN pip install -r requirements.txt

# After: 150MB
FROM python:3.11-slim
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
```

**2. Lazy initialization:**
```python
# Bad: Load at startup
model = load_model()  # Takes 5 seconds

app = Flask(__name__)

# Good: Load on first use
model = None

def get_model():
    global model
    if model is None:
        model = load_model()
    return model

@app.route('/')
def predict():
    m = get_model()
    return m.predict(data)
```

**3. Use CPU boost:**
```bash
gcloud run services update my-service --cpu-boost
```

Allocates more CPU during startup (Google Cloud Next 2023 feature).

**4. Min instances (nuclear option):**
```bash
--min-instances=1
```

Eliminates cold starts but costs more.

**5. Choose fast runtimes:**
- Go > Node.js/Python > Java
- Avoid heavy frameworks if possible

**6. Health checks:**
Ensure your app responds quickly to health checks:
```python
@app.route('/health')
def health():
    return "OK", 200
```

### Monitoring Cold Starts

```bash
# View startup latency in Cloud Logging
gcloud logging read 'resource.type="cloud_run_revision"
  protoPayload.serviceName="run.googleapis.com"
  protoPayload.methodName="google.cloud.run.v1.Revisions.StartContainer"' \
  --limit=50 --format=json
```

Or use Cloud Monitoring metrics:
- `run.googleapis.com/request_latencies` - Filter for p99
- `run.googleapis.com/container/startup_latencies` - Direct cold start metric

## Resource Allocation

### Memory

```bash
gcloud run services update my-service --memory=512Mi
```

**Options:** 128Mi to 32Gi (128Mi increments)

**Guidelines:**
- Start with 256Mi or 512Mi
- Monitor actual usage
- Scale up if OOM errors
- Scale down to save cost

**Finding right size:**
```bash
# Check actual memory usage
gcloud monitoring time-series list \
    --filter='metric.type="run.googleapis.com/container/memory/utilizations"'
```

**Cost per GB-hour:**
- First 2M vCPU-seconds free/month
- Then: $0.00001800 per GB-second

### CPU

```bash
gcloud run services update my-service --cpu=2
```

**Options:** 0.08 (80m) to 8 CPUs

**Default:**
- < 1Gi memory: 1 CPU
- ≥ 1Gi memory: Proportional

**When to increase:**
- CPU-bound operations
- Faster request processing
- Reduce latency

**When to decrease:**
- I/O-bound operations
- Save cost

### Request Timeout

```bash
gcloud run services update my-service --timeout=300
```

**Options:** 1 to 3600 seconds (1 hour max)
**Default:** 300 seconds (5 minutes)

**Considerations:**
- Longer timeout = longer billing if stuck
- Max 60 minutes per request
- Consider async processing for long tasks

## Load Testing

Essential for right-sizing configuration.

### Tools

**1. Apache Bench:**
```bash
ab -n 10000 -c 100 https://my-service.run.app/
```

**2. Hey (better):**
```bash
hey -n 10000 -c 100 -q 10 https://my-service.run.app/

# Sustained load
hey -z 5m -c 100 https://my-service.run.app/
```

**3. Locust (for complex scenarios):**
```python
from locust import HttpUser, task

class MyUser(HttpUser):
    @task
    def index(self):
        self.client.get("/")

    @task
    def api(self):
        self.client.post("/api/data", json={"test": "data"})
```

### What to Monitor

**During load test:**
1. **Request latency** - p50, p95, p99
2. **Error rate** - Should stay near 0%
3. **Instance count** - How many spawn?
4. **CPU utilization** - Is it maxed out?
5. **Memory utilization** - Any OOM errors?
6. **Request queuing** - Are requests waiting?

**In Cloud Console:**
Go to Cloud Run > Service > Metrics

**Via gcloud:**
```bash
# Watch instance count
watch -n 2 'gcloud run services describe my-service \
    --region=us-central1 \
    --format="value(status.traffic[0].revisionName)" | \
    xargs -I {} gcloud run revisions describe {} \
    --region=us-central1 \
    --format="value(status.containerConcurrency)"'
```

## Cost Optimization Strategies

### 1. Right-Size Resources

Don't over-allocate:
```bash
# Check actual usage first!
gcloud monitoring time-series list \
    --filter='metric.type="run.googleapis.com/container/memory/utilizations"'

# Then adjust
gcloud run services update my-service --memory=512Mi  # Down from 1Gi
```

### 2. Optimize Concurrency

Higher concurrency = fewer instances:
```bash
# Test different values
gcloud run services update my-service --concurrency=100  # Up from 80
```

Monitor error rates and latency.

### 3. Use CPU Throttling

Default is on. Only disable if needed:
```bash
--cpu-throttling  # Cheaper
```

### 4. Scale to Zero When Possible

```bash
--min-instances=0
```

Especially for dev/staging.

### 5. Optimize Request Duration

Faster responses = less billable time:
- Cache results
- Optimize database queries
- Use connection pooling
- Async processing for long tasks

### 6. Set Appropriate Timeouts

```bash
--timeout=60  # Down from 300, if requests are fast
```

Don't pay for stuck requests.

### 7. Use Request-Based Pricing

Cloud Run charges per request + instance time.

**Optimization:**
- Batch operations where possible
- Reduce unnecessary requests
- Use caching (Cloud CDN, Redis)

## Scaling for Different Traffic Patterns

### Steady Traffic

```bash
# Predictable load
--min-instances=5 \
--max-instances=20 \
--concurrency=80
```

Keeps instances warm for consistent performance.

### Spiky Traffic

```bash
# Variable load with bursts
--min-instances=1 \
--max-instances=100 \
--concurrency=100
```

Allows rapid scale-up, minimal cost during quiet periods.

### Nightly Batch Jobs

```bash
# Runs once per day
--min-instances=0 \
--max-instances=50 \
--timeout=3600 \
--memory=2Gi
```

Scale to zero when not running.

### Global 24/7 Service

```bash
# Always available, worldwide
--min-instances=3 \  # Per region
--max-instances=100 \
--concurrency=80
```

Deploy to multiple regions with Global Load Balancer.

## Advanced: Gradual Rollout

Use traffic splitting for safe scaling changes:

```bash
# Deploy new config with no traffic
gcloud run deploy my-service \
    --image=gcr.io/my-project/image \
    --memory=1Gi \  # Changed from 512Mi
    --no-traffic

# Send 10% traffic
gcloud run services update-traffic my-service \
    --to-revisions=LATEST=10,PREVIOUS=90

# Monitor performance

# If good, gradually increase
gcloud run services update-traffic my-service \
    --to-revisions=LATEST=50,PREVIOUS=50

# Eventually 100%
gcloud run services update-traffic my-service --to-latest
```

## Monitoring and Alerting

### Key Metrics to Watch

1. **Request latency** (p99) - User experience
2. **Error rate** - Reliability
3. **Instance count** - Cost and capacity
4. **CPU utilization** - Resource efficiency
5. **Memory utilization** - Prevent OOM
6. **Container startup latency** - Cold starts

### Set Up Alerts

```bash
# Example: Alert on high error rate
gcloud alpha monitoring policies create \
    --notification-channels=CHANNEL_ID \
    --display-name="Cloud Run High Error Rate" \
    --condition-display-name="Error rate > 5%" \
    --condition-threshold-value=5 \
    --condition-threshold-duration=300s
```

## Key Takeaways

- Start with defaults, optimize based on data
- Load test before production
- Min instances = cost vs performance trade-off
- Max instances = cost control and protection
- Concurrency depends on workload type
- Monitor metrics continuously
- Cold starts can often be mitigated without min instances
- Right-size resources to minimize cost
- Different traffic patterns need different configurations

## Recommended Starting Point

For a new production service:

```bash
gcloud run deploy my-service \
    --image=gcr.io/my-project/image \
    --region=us-central1 \
    --memory=512Mi \
    --cpu=1 \
    --concurrency=80 \
    --min-instances=0 \  # Start here, adjust if needed
    --max-instances=20 \  # Based on your expected load
    --timeout=300 \
    --cpu-throttling
```

Then monitor and adjust!

---

Next: [Common Gotchas →](./04-common-gotchas.md)
