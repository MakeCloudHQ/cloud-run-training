# Sample Cloud Run Application

A simple Flask web application for Cloud Run training.

## Features

- **Hello endpoint** (`/`) - Simple greeting with query parameters
- **Health check** (`/health`) - Returns service health status
- **Info endpoint** (`/info`) - Shows service metadata
- **Echo endpoint** (`/echo`) - Echoes back request details
- **Structured logging** - JSON logs for Cloud Logging
- **Environment variables** - Configurable via env vars

## Local Development

### Prerequisites

- Python 3.11+
- pip

### Run Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run the app
python app.py
```

The app will start on `http://localhost:8080`

### Test Endpoints

```bash
# Hello
curl http://localhost:8080/
curl http://localhost:8080/?name=Phil

# Health check
curl http://localhost:8080/health

# Info
curl http://localhost:8080/info

# Echo
curl http://localhost:8080/echo?test=value
curl -X POST http://localhost:8080/echo -d "test data"
```

## Docker

### Build Image

```bash
docker build -t cloud-run-sample .
```

### Run Container

```bash
docker run -p 8080:8080 -e PORT=8080 cloud-run-sample
```

### Test

```bash
curl http://localhost:8080/
```

## Deploy to Cloud Run

### Option 1: Deploy from Source (Easiest)

Cloud Run will build the container for you:

```bash
gcloud run deploy my-app \
    --source=. \
    --region=us-central1 \
    --allow-unauthenticated
```

### Option 2: Build and Deploy with Docker

```bash
# Set project ID
PROJECT_ID=$(gcloud config get-value project)

# Build and push to Artifact Registry
gcloud builds submit --tag gcr.io/$PROJECT_ID/cloud-run-sample

# Deploy
gcloud run deploy my-app \
    --image=gcr.io/$PROJECT_ID/cloud-run-sample \
    --region=us-central1 \
    --allow-unauthenticated
```

### Option 3: Use Dockerfile

```bash
gcloud run deploy my-app \
    --source=. \
    --region=us-central1 \
    --allow-unauthenticated
```

Cloud Run will detect and use the Dockerfile.

## Configuration

### Environment Variables

```bash
gcloud run services update my-app \
    --region=us-central1 \
    --set-env-vars="ENVIRONMENT=production,VERSION=2.0.0"
```

### Resources

```bash
gcloud run services update my-app \
    --region=us-central1 \
    --memory=512Mi \
    --cpu=1 \
    --max-instances=10
```

## Testing Deployed Service

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe my-app \
    --region=us-central1 \
    --format='value(status.url)')

# Test endpoints
curl $SERVICE_URL/
curl $SERVICE_URL/health
curl $SERVICE_URL/info
curl "$SERVICE_URL/echo?param1=value1&param2=value2"
```

## Cloud Run Specific Features

This app demonstrates Cloud Run best practices:

1. **PORT environment variable**: Required by Cloud Run
   ```python
   PORT = int(os.environ.get('PORT', 8080))
   ```

2. **Health check endpoint**: Good practice for monitoring
   ```python
   @app.route('/health')
   ```

3. **Structured logging**: Better integration with Cloud Logging
   ```python
   def log(message, severity='INFO'):
       entry = {'severity': severity, 'message': message}
       print(json.dumps(entry))
   ```

4. **Cloud Run metadata**: Accessed via environment variables
   ```python
   K_REVISION  # Cloud Run revision
   K_SERVICE   # Service name
   ```

5. **Stateless design**: No local file storage or state

## Experiments to Try

1. **Change the greeting message** and redeploy
2. **Add a new endpoint** (e.g., `/api/data`)
3. **Add environment variables** and use them in responses
4. **Test traffic splitting** between revisions
5. **Try different resource configurations** (memory, CPU)
6. **Add request logging** to track all requests
7. **Implement rate limiting** at the app level
8. **Add authentication** checks

## Common Issues

### App won't start
- Check logs: `gcloud run services logs read my-app`
- Verify PORT is read from environment
- Ensure container listens on 0.0.0.0

### Container too large
- Use `.dockerignore` to exclude unnecessary files
- Use slim base images (e.g., `python:3.11-slim`)
- Multi-stage builds for compiled languages

### Slow cold starts
- Reduce container size
- Minimize initialization code
- Consider min-instances for critical services

## Additional Resources

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Container Best Practices](https://cloud.google.com/architecture/best-practices-for-building-containers)
