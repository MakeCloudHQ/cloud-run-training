# Hands-On Lab: Deploy Your First Cloud Run Service

In this lab, you'll deploy a simple web application to Cloud Run and explore its features.

## Lab Overview

**Time**: 30-40 minutes

**What you'll do:**
1. Deploy a pre-built container from Artifact Registry
2. Deploy a custom application from source
3. Explore revisions and traffic management
4. Configure basic settings
5. Test your deployed service

## Part 1: Deploy a Pre-Built Container (5 minutes)

Let's start by deploying a sample "hello world" container that Google provides.

### Step 1: Deploy the Container

```bash
gcloud run deploy hello \
    --image=us-docker.pkg.dev/cloudrun/container/hello \
    --region=europe-west2 \
    --project=my-project-id \
    --allow-unauthenticated
```

**Flags explained:**
- `hello` - Name of your service
- `--image` - Container image to deploy
- `--region` - Where to run the service
- `--allow-unauthenticated` - Make it publicly accessible

### Step 2: Wait for Deployment

You'll see output like:
```
Deploying container to Cloud Run service [hello] in project [my-project] region [europe-west2]
✓ Deploying... Done.
  ✓ Creating Revision...
  ✓ Routing traffic...
Done.
Service [hello] revision [hello-00001-abc] has been deployed and is serving 100 percent of traffic.
Service URL: https://hello-abc123-uc.a.run.app
```

### Step 3: Test Your Service

Click the Service URL 

**Expected output**: HTML page with "Cloud Run" branding

### Step 4: Explore in Console

1. Open [Cloud Console](https://console.cloud.google.com)
2. Navigate to **Cloud Run**
3. Click on your **hello** service
4. Explore the interface:
   - **Metrics** - Requests, latency, errors
   - **Revisions** - List of deployments
   - **Logs** - Container logs
   - **YAML** - Service configuration

## Part 2: Deploy from Source Code (15 minutes)

Now let's deploy the sample application included in this training.

### Step 1: Set Default Project

Set your default project to avoid specifying `--project` on every command:

```bash
gcloud config set project my-project-id
```

Verify it's set:
```bash
gcloud config get-value project
```

### Step 2: Navigate to Sample App

```bash
cd 02-cloud-run-basics/sample-app
ls
```

You should see:
- `app.py` - Python Flask application
- `requirements.txt` - Python dependencies
- `Dockerfile` - Container build instructions

### Step 3: Understand the Application

Take a moment to look at `app.py`:
```python
from flask import Flask, request
import os

app = Flask(__name__)

@app.route('/')
def hello():
    name = request.args.get('name', 'World')
    return f'Hello {name}!'

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
```

**Key points:**
- Listens on port specified by `PORT` environment variable
- Cloud Run provides `PORT` automatically
- Simple HTTP endpoint

### Step 4: Verify Cloud Build Service Account Permissions

When deploying from source, Cloud Build needs permission to deploy to Cloud Run.

Get the default Cloud Build service account:
```bash
SA_EMAIL=$(gcloud builds get-default-service-account)
echo $SA_EMAIL
```

The output will look like: `[PROJECT-NUMBER]-compute@developer.gserviceaccount.com`

**Note**: Google Cloud now uses the Compute Engine default service account for Cloud Build by default. See [Cloud Build service account updates](https://cloud.google.com/build/docs/cloud-build-service-account-updates) for more details.

Grant the Cloud Run Builder role:
```bash
PROJECT_ID=$(gcloud config get-value project)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/run.builder"
```

This role allows Cloud Build to deploy Cloud Run services. It's usually auto-granted when you first use Cloud Build with Cloud Run, but it's good to verify!

### Step 5: Deploy from Source

Cloud Run can build your container automatically:

```bash
gcloud run deploy my-app \
    --source=. \
    --region=europe-west2 \
    --allow-unauthenticated
```

**What happens:**
1. Uploads source code
2. Builds container using Cloud Build
3. Pushes to Artifact Registry
4. Deploys to Cloud Run

This will take 1-2 minutes.

### Step 6: Test Your Custom Service

```bash
# Get the URL
SERVICE_URL=$(gcloud run services describe my-app \
    --region=europe-west2 \
    --format='value(status.url)')

echo $SERVICE_URL

# Test default
curl $SERVICE_URL

# Test with parameter
curl "$SERVICE_URL?name=Phil"
```

**Expected output:**
```
Hello World!
Hello Phil!
```

### Step 7: View Build Details

Check out what happened:

```bash
# List builds (in the same region as your Cloud Run service)
gcloud builds list --region=europe-west2 --limit=5

# View build logs for the most recent build
gcloud builds log $(gcloud builds list --region=europe-west2 --limit=1 --format='value(id)') \
    --region=europe-west2
```

## Part 3: Make Changes and Redeploy (10 minutes)

Let's update the application and create a new revision.

### Step 1: Modify the Application

Edit `app.py` and change the response:

```python
@app.route('/')
def hello():
    name = request.args.get('name', 'World')
    emoji = request.args.get('emoji', '👋')
    return f'{emoji} Hello {name}! Welcome to Cloud Run!'
```

### Step 2: Deploy the Update

```bash
gcloud run deploy my-app \
    --source=. \
    --region=europe-west2 \
    --allow-unauthenticated
```

### Step 3: View Revisions

```bash
gcloud run revisions list \
    --service=my-app \
    --region=europe-west2
```

You should see two revisions:
- `my-app-00001-xxx` - Original
- `my-app-00002-yyy` - Updated (serving 100% traffic)

### Step 4: Test the Update

```bash
curl "$SERVICE_URL?name=Team&emoji=🚀"
```

**Expected**: `🚀 Hello Team! Welcome to Cloud Run!`

## Part 4: Traffic Management (10 minutes)

Practice splitting traffic between revisions.

### Step 1: Get Revision Names

```bash
# List revisions and save names
REVISIONS=$(gcloud run revisions list \
    --service=my-app \
    --region=europe-west2 \
    --format='value(name)')

# Parse into variables
LATEST=$(echo "$REVISIONS" | head -1)
PREVIOUS=$(echo "$REVISIONS" | sed -n '2p')

echo "Latest: $LATEST"
echo "Previous: $PREVIOUS"
```

### Step 2: Split Traffic 50/50

```bash
gcloud run services update-traffic my-app \
    --region=europe-west2 \
    --to-revisions=$LATEST=50,$PREVIOUS=50
```

### Step 3: Test Traffic Split

Run this multiple times:
```bash
for i in {1..10}; do
    curl -s $SERVICE_URL
done
```

You should see responses from both revisions (with and without emoji).

### Step 4: Roll Back to Previous Version

```bash
gcloud run services update-traffic my-app \
    --region=europe-west2 \
    --to-revisions=$PREVIOUS=100
```

Test:
```bash
curl $SERVICE_URL
```

Should see the old version (without emoji).

### Step 5: Route Back to Latest

```bash
gcloud run services update-traffic my-app \
    --region=europe-west2 \
    --to-latest
```

## Part 5: Configuration and Environment Variables (10 minutes)

### Step 1: View Current Configuration

```bash
gcloud run services describe my-app \
    --region=europe-west2 \
    --format=yaml
```

### Step 2: Add Environment Variables

```bash
gcloud run services update my-app \
    --region=europe-west2 \
    --set-env-vars="ENVIRONMENT=production,VERSION=1.0.0"
```

### Step 3: Update App to Use Variables

Edit `app.py`:
```python
@app.route('/')
def hello():
    name = request.args.get('name', 'World')
    env = os.environ.get('ENVIRONMENT', 'unknown')
    version = os.environ.get('VERSION', 'unknown')
    return f'Hello {name}! (env: {env}, version: {version})'
```

Redeploy:
```bash
gcloud run deploy my-app \
    --source=. \
    --region=europe-west2 \
    --allow-unauthenticated
```

Test:
```bash
curl $SERVICE_URL
```

### Step 4: Adjust Resources

```bash
gcloud run services update my-app \
    --region=europe-west2 \
    --memory=512Mi \
    --cpu=1 \
    --max-instances=10 \
    --min-instances=0
```

**Configuration options:**
- `--memory`: 128Mi to 32Gi (increments of 128Mi)
- `--cpu`: 0.08 to 8 (CPU count)
- `--max-instances`: Maximum concurrent containers
- `--min-instances`: Minimum (0 = scale to zero)
- `--timeout`: Request timeout (default 300s, max 3600s)

### Step 5: View Service Details

```bash
gcloud run services describe my-app \
    --region=europe-west2
```

Check out:
- Current revision
- Traffic allocation
- Environment variables
- Resource limits
- URL

## Part 6: Monitoring and Logs (5 minutes)

### View Logs

```bash
# Stream logs
gcloud run services logs read my-app \
    --region=europe-west2 \
    --limit=50

# Follow logs in real-time (requires beta component)
gcloud beta run services logs tail my-app \
    --region=europe-west2
```

Generate some traffic while watching logs:
```bash
# In another terminal
for i in {1..20}; do curl $SERVICE_URL; sleep 1; done
```

### View Metrics in Console

1. Go to Cloud Console > Cloud Run > my-app
2. Click **Metrics** tab
3. Explore:
   - Request count
   - Request latency
   - Container instance count
   - Billable container time

### View Logs in Console

1. Click **Logs** tab
2. Filter by:
   - Severity
   - Time range
   - Text search

## Part 7: Clean Up (Optional)

If you want to remove the services:

```bash
# Delete services
gcloud run services delete hello --region=europe-west2 --quiet
gcloud run services delete my-app --region=europe-west2 --quiet

# Optionally delete images from Artifact Registry
gcloud artifacts repositories list
```

## Lab Challenges (Extra Credit)

Try these on your own:

1. **Add a new endpoint** to the app (e.g., `/health` for health checks)
2. **Deploy with authentication required** (remove `--allow-unauthenticated`)
3. **Use Cloud Build** to build container separately, then deploy
4. **Add Secret Manager** integration for sensitive config
5. **Deploy to multiple regions** and compare URLs

## Common Issues and Solutions

### Build Fails

**Error**: `requirements.txt not found`
- **Solution**: Make sure you're in the `sample-app` directory

### Permission Denied

**Error**: `User does not have permission to access service`
- **Solution**: Check IAM permissions (need `roles/run.developer`)

### Service Won't Start

**Error**: `Container failed to start`
- **Solution**: Check logs for application errors
- Verify the container listens on the `PORT` environment variable

### Can't Access Service URL

**Error**: 403 Forbidden
- **Solution**: Service not public. Run:
  ```bash
  gcloud run services add-iam-policy-binding my-app \
      --region=europe-west2 \
      --member=allUsers \
      --role=roles/run.invoker
  ```

## Key Takeaways

You've learned to:
- Deploy Cloud Run services from pre-built containers and source code
- Understand revisions and how they're created
- Split traffic between revisions (canary, rollback)
- Configure environment variables and resources
- View logs and metrics
- Make updates and manage deployments

## Next Steps

- [Learn more about Cloud Run concepts →](./concepts.md)
- [Explore the sample application code →](./sample-app/)
- [Move to Cloud Run Advanced topics →](../03-cloud-run-advanced/)

---

**Questions?** Now's a good time to discuss what you've learned!
