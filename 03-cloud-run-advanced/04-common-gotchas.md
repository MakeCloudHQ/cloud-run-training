# Common Gotchas and How to Avoid Them

Learn from others' mistakes! Here are the most common issues people encounter with Cloud Run and how to solve them.

## 1. Not Listening on PORT Environment Variable

### The Problem

```python
# WRONG
app.run(host='0.0.0.0', port=8080)
```

Cloud Run sets `PORT` dynamically. Hardcoding fails.

### The Solution

```python
# CORRECT
import os
port = int(os.environ.get('PORT', 8080))
app.run(host='0.0.0.0', port=port)
```

**Always read PORT from environment variable!**

### Symptoms
- Container starts but health checks fail
- "Container failed to start" error
- Service unreachable

---

## 2. Not Binding to 0.0.0.0

### The Problem

```python
# WRONG - Only listens on localhost
app.run(host='127.0.0.1', port=port)
```

Cloud Run needs to reach your app from outside the container.

### The Solution

```python
# CORRECT - Listens on all interfaces
app.run(host='0.0.0.0', port=port)
```

### Symptoms
- Container starts but doesn't respond to requests
- Health checks timeout
- 502 Bad Gateway errors

---

## 3. Stateful Applications

### The Problem

```python
# WRONG - State stored in memory
user_sessions = {}

@app.route('/login')
def login():
    user_sessions[user_id] = session_data
    # This data will be lost when instance stops!
```

**Cloud Run instances are ephemeral!** They can stop at any time.

### The Solution

Use external storage:

```python
# CORRECT - State in Redis/Memorystore
from redis import Redis
redis = Redis(host='10.0.0.5')

@app.route('/login')
def login():
    redis.set(f'session:{user_id}', session_data)
```

**Options for state:**
- Redis/Memorystore (cache)
- Firestore (NoSQL database)
- Cloud SQL (relational database)
- Cloud Storage (files)

### What You Can Store Locally
- Read-only configuration
- Loaded libraries
- Compiled code
- Temporary processing data (per-request)

### What You Cannot Store Locally
- User sessions
- Uploaded files
- Application state
- Anything that needs to persist

---

## 4. Database Connection Pooling Issues

### The Problem

```python
# WRONG - New connection per request
@app.route('/api/data')
def get_data():
    conn = psycopg2.connect(DB_URL)
    # This exhausts database connections!
    data = conn.execute("SELECT * FROM table")
    conn.close()
    return data
```

With high concurrency, you quickly exhaust database connections.

### The Solution

**Use connection pooling:**

```python
# CORRECT - Reuse connections
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DB_URL,
    poolclass=QueuePool,
    pool_size=5,  # Connections per instance
    max_overflow=2,
    pool_pre_ping=True  # Test connections before use
)

@app.route('/api/data')
def get_data():
    with engine.connect() as conn:
        result = conn.execute("SELECT * FROM table")
        return result.fetchall()
```

**Calculate pool size:**
```
max_instances = 20
pool_size_per_instance = 5
total_connections = 20 × 5 = 100

Ensure: total_connections < database_max_connections
```

**For Cloud SQL:**
- Use Cloud SQL Proxy or built-in connector
- Set reasonable pool sizes
- Set max-instances based on DB capacity

---

## 5. Long Request Timeouts

### The Problem

Background task in HTTP handler:

```python
@app.route('/process')
def process():
    # This takes 2 hours!
    for i in range(1000000):
        process_item(i)
    return "Done"
```

**Cloud Run max timeout: 60 minutes**

### The Solution

Use async processing:

```python
from google.cloud import tasks_v2

@app.route('/process')
def process():
    # Queue task instead
    client = tasks_v2.CloudTasksClient()
    task = {
        'http_request': {
            'http_method': 'POST',
            'url': f'{WORKER_URL}/process-item'
        }
    }
    client.create_task(parent=queue_path, task=task)
    return "Queued", 202

@app.route('/process-item', methods=['POST'])
def process_item():
    # Process single item (fast)
    # Gets called many times by Cloud Tasks
    return "OK"
```

**Alternatives:**
- Cloud Tasks (recommended)
- Cloud Pub/Sub
- Cloud Run Jobs (for batch processing)
- Cloud Workflows (for orchestration)

---

## 6. Large Container Images

### The Problem

```dockerfile
FROM ubuntu:latest  # 78MB base
RUN apt-get update && apt-get install -y \
    python3 python3-pip git curl wget vim emacs \
    # 50 packages later...

COPY . .  # Copies node_modules, .git, etc.
```

**Result:** 2GB+ image = slow cold starts

### The Solution

```dockerfile
# Use slim/alpine base
FROM python:3.11-slim  # Much smaller

# Install only what you need
RUN pip install --no-cache-dir -r requirements.txt

# Use .dockerignore
COPY . .
```

**.dockerignore:**
```
.git
.gitignore
node_modules
__pycache__
*.pyc
tests/
docs/
README.md
.env
```

**Multi-stage builds for compiled languages:**
```dockerfile
# Build stage
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o main .

# Runtime stage
FROM alpine:latest
COPY --from=builder /app/main /main
CMD ["/main"]
```

**Target: <500MB for fast cold starts**

---

## 7. Not Handling SIGTERM

### The Problem

Container receives SIGTERM but doesn't gracefully shutdown:

```python
# Doesn't handle shutdown signal
app.run()
# In-flight requests get killed!
```

### The Solution

```python
import signal
import sys

def signal_handler(sig, frame):
    print('Shutting down gracefully...')
    # Finish in-flight requests
    # Close connections
    sys.exit(0)

signal.signal(signal.SIGTERM, signal_handler)

app.run()
```

**Cloud Run shutdown sequence:**
1. Stops sending new requests
2. Sends SIGTERM
3. Waits up to 10 seconds
4. Sends SIGKILL (force stop)

**Best practices:**
- Listen for SIGTERM
- Stop accepting new requests
- Finish in-flight requests (max 10s)
- Close connections cleanly

---

## 8. Ignoring Cold Start Optimization

### The Problem

```python
# Loads huge ML model at startup
model = load_model('2GB_model.pkl')  # Takes 30 seconds
app = Flask(__name__)
```

**Result:** 30-second cold starts!

### Solutions

**Option 1: Lazy loading**
```python
model = None

def get_model():
    global model
    if model is None:
        model = load_model('model.pkl')
    return model

@app.route('/predict')
def predict():
    m = get_model()  # Only loads on first use
    return m.predict(data)
```

**Option 2: Min instances**
```bash
--min-instances=1  # Keep model loaded
```

**Option 3: Smaller model/optimizations**
- Quantize model
- Use TensorFlow Lite
- Use Cloud Run GPU (Alpha)

---

## 9. Synchronous Service-to-Service Chains

### The Problem

```
User → Service A → Service B → Service C → Service D
        (waits)     (waits)     (waits)
```

Each cold start adds to latency!

### The Solution

**Use async patterns:**

```python
# Instead of synchronous chain
result = await service_b(await service_c(data))

# Use pub/sub
publisher.publish(topic, data)
return "Processing", 202

# Or parallel calls
async with aiohttp.ClientSession() as session:
    results = await asyncio.gather(
        call_service_b(session, data),
        call_service_c(session, data),
        call_service_d(session, data)
    )
```

**Strategies:**
- Fan-out with Pub/Sub
- Parallel calls where possible
- Event-driven architecture
- Cache results

---

## 10. Not Setting max-instances

### The Problem

Traffic spike causes:
- 1000 instances spawn
- Database overwhelmed
- Quota exhausted
- Huge bill

### The Solution

**Always set max-instances:**

```bash
gcloud run services update my-service \
    --max-instances=20
```

**Calculate based on:**
- Database connection limit
- Downstream service capacity
- Budget constraints
- API quotas

---

## 11. Forgetting IAM for Service-to-Service Calls

### The Problem

```python
# WRONG - No auth
response = requests.get('https://internal-service.run.app/api')
# Returns 403 Forbidden!
```

Cloud Run enforces authentication by default.

### The Solution

```python
# CORRECT - Include identity token
import google.auth
from google.auth.transport.requests import Request

auth_req = Request()
credentials, project = google.auth.default()
credentials.refresh(auth_req)

response = requests.get(
    'https://internal-service.run.app/api',
    headers={'Authorization': f'Bearer {credentials.token}'}
)
```

**And grant IAM permissions:**
```bash
gcloud run services add-iam-policy-binding internal-service \
    --member=serviceAccount:caller@project.iam.gserviceaccount.com \
    --role=roles/run.invoker
```

---

## 12. Local File Writes

### The Problem

```python
# WRONG - Write to local filesystem
with open('/tmp/uploaded_file.pdf', 'wb') as f:
    f.write(data)
# File lost when instance stops!
```

### The Solution

**Write to Cloud Storage:**

```python
from google.cloud import storage

client = storage.Client()
bucket = client.bucket('my-bucket')
blob = bucket.blob('uploaded_file.pdf')
blob.upload_from_string(data)
```

**Exception:** `/tmp` for temporary per-request processing
```python
# OK for temporary processing
with open('/tmp/temp.pdf', 'wb') as f:
    f.write(data)
process_pdf('/tmp/temp.pdf')
os.remove('/tmp/temp.pdf')  # Clean up
```

**But remember:**
- `/tmp` is limited (varies, usually ~500MB)
- Not persisted between requests
- Clean up after yourself

---

## 13. Environment Variable Confusion

### The Problem

```python
# Set in Dockerfile
ENV DATABASE_URL=postgres://localhost/db

# Expects it in Cloud Run but uses dev value!
```

### The Solution

**Never hardcode env vars in Dockerfile for environment-specific values.**

```bash
# Set in Cloud Run
gcloud run deploy my-service \
    --set-env-vars="DATABASE_URL=postgres://prod-db/db"
```

**Or use Secret Manager:**
```bash
gcloud run deploy my-service \
    --set-secrets="DATABASE_URL=db-url:latest"
```

**Dockerfile should only have defaults:**
```dockerfile
ENV PORT=8080  # OK - default
ENV LOG_LEVEL=INFO  # OK - default
# Don't put prod credentials here!
```

---

## 14. Not Using Health Checks

### The Problem

No health check endpoint → Cloud Run can't detect unhealthy instances.

### The Solution

```python
@app.route('/health')
def health():
    # Check database
    try:
        db.execute('SELECT 1')
    except:
        return 'Unhealthy', 503

    return 'OK', 200
```

**Configure startup/liveness probes:**
```yaml
# service.yaml
spec:
  template:
    spec:
      containers:
      - image: gcr.io/my-project/my-image
        startupProbe:
          httpGet:
            path: /health
          initialDelaySeconds: 0
          periodSeconds: 1
          failureThreshold: 3
```

---

## 15. Excessive Logging

### The Problem

```python
# Logs every request detail
@app.route('/api')
def api():
    print(f"Request received: {request.json}")
    print(f"Headers: {request.headers}")
    print(f"Query params: {request.args}")
    # Creates GBs of logs!
```

**Cloud Logging costs money!**

### The Solution

**Log strategically:**

```python
import logging
logging.basicConfig(level=logging.INFO)

@app.route('/api')
def api():
    # Log important events only
    if error:
        logging.error(f"Error processing request: {error}")

    # Use sampling for debug logs
    if random.random() < 0.01:  # 1% sampling
        logging.debug(f"Request details: {request.json}")
```

**Use structured logging:**
```python
import json
print(json.dumps({
    'severity': 'INFO',
    'message': 'Request processed',
    'request_id': request_id,
    'latency_ms': latency
}))
```

---

## 16. Incorrect Concurrency Settings

### The Problem

```python
# Flask with concurrency=100
# But using Gunicorn with 1 worker!

CMD gunicorn --workers=1 --threads=1 app:app
```

**Result:** Only handles 1 request at a time, others queue.

### The Solution

**Match workers/threads to concurrency:**

```bash
# concurrency=80, so:
CMD gunicorn --workers=1 --threads=80 --timeout=0 app:app
```

Or let Cloud Run set concurrency based on your workers:
```bash
# 4 workers, 20 threads each
CMD gunicorn --workers=4 --threads=20 app:app

# Then set:
--concurrency=80  # 4 × 20
```

**For async frameworks (FastAPI, etc.):**
```bash
# Single worker, event loop handles concurrency
CMD uvicorn main:app --host 0.0.0.0 --port $PORT

--concurrency=100  # Can be high
```

---

## 17. Not Testing Locally

### The Problem

Deploy to Cloud Run without testing locally → discover issues in production.

### The Solution

**Test with Docker locally:**

```bash
# Build
docker build -t my-service .

# Run locally
docker run -p 8080:8080 -e PORT=8080 -e ENV=dev my-service

# Test
curl http://localhost:8080
```

**Or use Cloud Code:**
- VS Code extension
- Run/debug Cloud Run locally
- Emulates Cloud Run environment

---

## Quick Troubleshooting Checklist

When things go wrong:

```bash
# 1. Check logs
gcloud run services logs read my-service --limit=50

# 2. Check service status
gcloud run services describe my-service --region=europe-west2

# 3. Check revision status
gcloud run revisions describe REVISION_NAME --region=europe-west2

# 4. Check IAM permissions
gcloud run services get-iam-policy my-service --region=europe-west2

# 5. Test local Docker image
docker run -p 8080:8080 -e PORT=8080 my-image

# 6. Check resource limits
# Look for OOM kills in logs
gcloud logging read 'resource.type="cloud_run_revision"
  severity=ERROR' --limit=50
```

---

## Key Takeaways

- **Always** read PORT from environment
- **Always** bind to 0.0.0.0
- **Never** store state locally
- **Always** use connection pooling
- **Always** set max-instances
- **Always** optimize container size
- Handle SIGTERM gracefully
- Use async patterns for long tasks
- Test locally before deploying
- Monitor logs and metrics

---

Next: [GKE Migration Strategies →](./05-gke-migration.md)
