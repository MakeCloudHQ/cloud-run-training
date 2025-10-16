# Discussion Topics

This section contains common questions, scenarios, and topics for group discussion. Use this as a guide for interactive Q&A.

## Project Organization

### Scenario 1: Multi-Environment Setup

**Question**: "We have dev, staging, and prod environments. Should we use separate projects?"

**Discussion Points:**
- Pros of separate projects:
  - Strong isolation (can't accidentally affect prod from dev)
  - Different IAM policies per environment
  - Separate billing/cost tracking
  - Independent API quotas
- Cons:
  - More overhead to manage
  - Need to duplicate some resources
- **Recommendation**: Separate projects for different environments is a best practice

### Scenario 2: Monorepo with Multiple Services

**Question**: "We have 10 microservices in one repository. One project or many?"

**Discussion Points:**
- Option 1: One project per environment
  - All services in `myapp-prod`, `myapp-dev`, etc.
  - Simpler management
  - Shared networking
  - Good when services are tightly coupled
- Option 2: One project per service per environment
  - `service-a-prod`, `service-a-dev`, `service-b-prod`, etc.
  - Maximum isolation
  - Complex to manage
  - Good for large organizations with many teams
- Option 3: Grouped by domain
  - `frontend-services-prod`, `backend-services-prod`, etc.
  - Balance between isolation and manageability

**Poll the room**: What feels right for your use case?

## Networking

### Scenario 3: Cloud Run + Cloud SQL

**Question**: "Our Cloud Run service needs to connect to Cloud SQL. How should we set up networking?"

**Discussion Points:**
1. Cloud SQL has built-in integration (easiest):
   ```bash
   gcloud run deploy my-service \
       --add-cloudsql-instances=my-project:europe-west2:my-instance
   ```
   - No VPC Connector needed
   - Use Unix socket connection
   - Recommended approach

2. Via VPC (if you need other VPC resources too):
   - Create VPC Connector
   - Configure Cloud SQL for private IP
   - Connect via private IP

**Follow-up**: What other private resources do you need to access?

### Scenario 4: Calling Third-Party APIs

**Question**: "Our service calls external APIs. Do we need VPC configuration?"

**Answer**: No! Cloud Run can call public internet by default.

**But consider**:
- If you route egress through VPC (for security/compliance)
- You'll need Cloud NAT for internet access
- Adds latency and cost
- Only do this if required by policy

### Scenario 5: Service-to-Service Communication

**Question**: "Service A needs to call Service B, both are Cloud Run. How do we handle auth?"

**Discussion Points:**

**Option 1: Service Account Identity**
```bash
# Service A's service account needs run.invoker on Service B
gcloud run services add-iam-policy-binding service-b \
    --member=serviceAccount:service-a@project.iam.gserviceaccount.com \
    --role=roles/run.invoker

# In Service A code, get identity token
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
    https://service-b-url
```

**Option 2: API Key/Secret**
- Use Secret Manager
- Less preferred (harder to audit)

**Option 3: Internal Load Balancer**
- Both services internal-only
- Behind shared load balancer

**Best practice**: Use service account identity (Option 1)

## IAM and Security

### Scenario 6: Developer Access

**Question**: "How should we give developers access to deploy to dev, but not prod?"

**Recommendation**:
1. Create Google Groups:
   - `developers@example.com` - All developers
   - `sre-team@example.com` - SRE/Ops team

2. Grant roles by environment:
   ```bash
   # Dev project - developers can deploy
   gcloud projects add-iam-policy-binding myapp-dev \
       --member=group:developers@example.com \
       --role=roles/run.developer

   # Prod project - only SRE can deploy
   gcloud projects add-iam-policy-binding myapp-prod \
       --member=group:sre-team@example.com \
       --role=roles/run.admin

   # Prod project - developers can view
   gcloud projects add-iam-policy-binding myapp-prod \
       --member=group:developers@example.com \
       --role=roles/run.viewer
   ```

3. Consider CI/CD:
   - Humans don't deploy to prod manually
   - CI/CD service account deploys after approvals

### Scenario 7: Third-Party Vendor Access

**Question**: "We need to give a vendor temporary access to help debug an issue."

**Discussion Points:**
- Create a Google Group for vendors
- Grant minimum necessary role (likely `roles/viewer`)
- Use IAM conditions for time-based access:
  ```bash
  --condition='title=Temporary Access,
               expression=request.time < timestamp("2024-12-31T23:59:59Z")'
  ```
- Audit their actions (Cloud Logging)
- Revoke access when done

### Scenario 8: Public API with Rate Limiting

**Question**: "We want a public API but need to prevent abuse."

**Options**:
1. Cloud Run + Cloud Armor (requires Load Balancer)
   - Rate limiting
   - IP blocking
   - DDoS protection

2. Cloud Run + API Gateway
   - API key management
   - Quotas per key
   - More complex

3. Application-level rate limiting
   - Implement in code
   - Use Redis/Memorystore
   - More flexible but more work

**Discussion**: What's your threat model?

## Cost Management

### Scenario 9: Cost Allocation

**Question**: "How can we track costs per team/service?"

**Strategies**:
1. **Separate projects per team**
   - Easy cost breakdown by project
   - More overhead to manage

2. **Labels on all resources**
   ```bash
   gcloud run deploy my-service \
       --labels=team=backend,cost-center=engineering,service=api
   ```
   - Cost breakdown by label in billing reports
   - Less isolation

3. **Combination approach**
   - Projects by environment
   - Labels by team/service within project

**Action item**: Decide on labeling strategy early

### Scenario 10: Cost Optimization

**Question**: "How do we control Cloud Run costs?"

**Discussion Points**:
- **CPU allocation**: CPU always allocated vs only during request
  ```bash
  --cpu-throttling  # Only allocate CPU during requests (default)
  --no-cpu-throttling  # Always allocate (for background tasks)
  ```
- **Min instances**: Costs even when idle (but faster response)
- **Max instances**: Prevents runaway costs
- **Memory/CPU limits**: Right-size your containers
- **Request timeout**: Prevent hanging requests from costing money

**Best practice**: Start conservative, scale up based on metrics

## Migration and Architecture

### Scenario 11: Migrating from VMs

**Question**: "We currently run on Compute Engine VMs. Should we move to Cloud Run?"

**Good candidates for Cloud Run:**
- Stateless applications
- HTTP-based services
- Microservices
- APIs
- Event-driven workloads
- Variable traffic patterns (benefit from scale-to-zero)

**Maybe not Cloud Run:**
- Need persistent local storage
- Long-running tasks (>1 hour per request)
- Need specific OS/kernel features
- Very specific performance requirements
- Existing VM-specific optimizations

**Migration approach**:
1. Start with one service (lowest risk)
2. Containerize if not already
3. Test thoroughly in dev
4. Monitor closely in prod
5. Learn and iterate

### Scenario 12: Migrating from GKE

**Question**: "We use GKE. What would we gain/lose with Cloud Run?"

**Gains**:
- Less infrastructure management
- Scale to zero (cost savings)
- Simpler deployments
- Per-request billing
- Built-in TLS/domains

**Loses**:
- Less control over infrastructure
- Some Kubernetes features not available
- Request timeout limits (1 hour max)
- Container size limits

**Consider**: Use both!
- Cloud Run for simple HTTP services
- GKE for complex workloads
- They can work together in same VPC

## Real-World Scenarios (Share Your Use Cases)

### Open Discussion

**Prompt the group:**
1. What are you currently running that you'd like to move to Cloud Run?
2. What concerns do you have?
3. What's your current deployment process?
4. What's your production traffic pattern?
5. Compliance or regulatory requirements?

### Common Concerns and Answers

**"Is Cloud Run production-ready?"**
- Yes! Many companies run critical workloads
- 99.95% SLA
- Auto-scaling handles traffic spikes
- Built by Google, runs on Google infrastructure

**"What about cold starts?"**
- Typical: 100-500ms
- Use min instances for critical paths
- Most users don't notice
- Improving over time

**"Can we use it with our existing VPC?"**
- Yes! VPC Connector for egress
- Internal Load Balancer for ingress
- Full VPC integration available

**"What about secrets and config?"**
- Secret Manager integration
- Environment variables
- Config files in container
- Multiple options available

**"Vendor lock-in concerns?"**
- Uses standard containers (Docker)
- Knative-based (open source)
- Can run containers elsewhere
- But will need to replicate some features

## Hands-On Exploration Time (15-20 minutes)

Give attendees time to:
1. Explore their project in the Console
2. Try gcloud commands from their terminal
3. Look at existing resources (if any)
4. Ask specific questions

**Prompts to explore**:
```bash
# See what you have access to
gcloud projects list

# Explore your project
gcloud services list --enabled
gcloud compute networks list
gcloud run services list --platform managed
gcloud iam service-accounts list

# Check your permissions
gcloud projects get-iam-policy $(gcloud config get-value project) \
    --flatten="bindings[].members" \
    --filter="bindings.members:user:$(gcloud config get-value account)"
```

## Wrap-Up Questions

Before moving to the next section:

1. Are the project/folder concepts clear?
2. Comfortable with VPC and networking basics?
3. Understand IAM roles and service accounts?
4. Any blocking questions before we deploy Cloud Run?

**Key takeaway**: You don't need to be experts, but you should have mental models of:
- How Google Cloud organizes resources
- How networking works at a high level
- How IAM controls access

---

Ready for hands-on? Let's move to: [Cloud Run Basics →](../02-cloud-run-basics/)
