# Cloud Run with Load Balancers

Learn how to put Cloud Run services behind Cloud Load Balancer for production deployments.

## Why Use a Load Balancer?

While Cloud Run provides a default `*.run.app` URL, production deployments often require more:

**Custom domains:**
- Use your own domain (e.g., `api.example.com`)
- Professional branding
- Easier migration between services

**Security:**
- Cloud Armor for DDoS protection
- Web Application Firewall (WAF) rules
- Rate limiting and IP filtering
- Bot detection

**Advanced routing:**
- Path-based routing (different services for different paths)
- Header-based routing
- URL rewriting and redirects

**Multi-region:**
- Global load balancing
- Automatic failover
- Latency-based routing

**SSL/TLS management:**
- Google-managed certificates
- Automatic renewal
- Modern TLS protocols

## Serverless Network Endpoint Groups (NEGs)

A **Serverless NEG** is how you connect Cloud Run to Cloud Load Balancer.

### What is a NEG?

A Network Endpoint Group is a configuration object that specifies a group of backend endpoints. For Cloud Run, a serverless NEG points to a specific Cloud Run service.

**Characteristics:**
- Regional resource (must match service region)
- Points to one Cloud Run service
- No IP addresses or ports to manage
- Automatically tracks service changes

**Example:**
```
NEG "my-api-neg" → Cloud Run Service "my-api" (europe-west2)
```

### Why NEGs?

Traditional load balancers route to IP addresses. Cloud Run services don't have fixed IPs - they're fully managed and serverless. Serverless NEGs bridge this gap by providing a stable reference that the load balancer can use.

## Load Balancer Architecture

### External Application Load Balancer

Route internet traffic to Cloud Run:

```
Internet
   ↓
Forwarding Rule (External IP: 34.120.1.5)
   ↓
Target HTTPS Proxy (SSL termination)
   ↓
URL Map (routing rules)
   ↓
Backend Service
   ↓
Serverless NEG
   ↓
Cloud Run Service
```

**Components:**

1. **Forwarding Rule** - External IP address that receives traffic
2. **Target Proxy** - Handles SSL/TLS, uses certificate
3. **URL Map** - Routing logic (which paths go where)
4. **Backend Service** - Configuration for the backend (timeouts, health checks)
5. **Serverless NEG** - Points to Cloud Run service

### Internal Application Load Balancer

Route VPC traffic to Cloud Run:

```
VPC Resources
   ↓
Forwarding Rule (Internal IP: 10.0.0.10)
   ↓
Target HTTPS Proxy
   ↓
URL Map
   ↓
Backend Service
   ↓
Serverless NEG
   ↓
Cloud Run Service (internal ingress)
```

Same components, but forwarding rule has internal IP and service uses internal ingress.

## Use Cases

### 1. Custom Domain with SSL

**Scenario:** Serve your API on `api.example.com` with automatic SSL.

**Setup:**
- External load balancer
- Google-managed SSL certificate for your domain
- DNS record pointing to load balancer IP

**Result:** Users access `https://api.example.com` instead of `https://my-service-xxx.run.app`

### 2. Cloud Armor Protection

**Scenario:** Protect public API from DDoS attacks and malicious traffic.

**Setup:**
- External load balancer
- Cloud Armor security policy attached to backend service
- Rules for rate limiting, geo-blocking, IP filtering

**Result:** Attacks are blocked at the edge, before reaching Cloud Run

### 3. Multi-Service Routing

**Scenario:** Different Cloud Run services for different URL paths.

**Setup:**
- External load balancer with multiple backend services
- URL map routes:
  - `/api/*` → API service
  - `/auth/*` → Auth service
  - `/admin/*` → Admin service

**Result:** One domain, multiple services behind it

### 4. Multi-Region Deployment

**Scenario:** Serve users from the closest region for low latency.

**Setup:**
- Global external load balancer
- Backend services in multiple regions (us, eu, asia)
- Each backend has serverless NEG pointing to regional Cloud Run service

**Result:** Automatic routing to nearest healthy region

### 5. Internal Service Access

**Scenario:** VMs in VPC need to access Cloud Run service privately.

**Setup:**
- Internal load balancer
- Cloud Run with internal ingress
- VMs access via internal IP (e.g., `https://10.0.0.10`)

**Result:** Fully private communication, no internet exposure

## Benefits Summary

| Feature | Direct Cloud Run | With Load Balancer |
|---------|------------------|-------------------|
| Custom domain | Via domain mapping | Via load balancer |
| SSL certificate | Auto-managed | Google-managed or custom |
| DDoS protection | Basic | Cloud Armor (advanced) |
| WAF rules | No | Yes (Cloud Armor) |
| Multi-region | Manual DNS | Automatic routing |
| Path routing | No | Yes |
| Header routing | No | Yes |
| CDN integration | No | Yes (Cloud CDN) |
| Advanced logging | Basic | Detailed (LB logs) |

## Load Balancer Types

### External Application Load Balancer

**Best for:**
- Public-facing services
- Custom domains
- Global distribution
- Need Cloud Armor

**Features:**
- Global or regional
- HTTP/HTTPS traffic
- Layer 7 (application layer)
- Content-based routing

### Internal Application Load Balancer

**Best for:**
- Internal services accessed from VPC
- Private APIs
- Microservices communication
- Corporate applications

**Features:**
- Regional only
- HTTP/HTTPS traffic
- Private IP addresses
- VPC-only access

### When to Use Which?

**Use External ALB when:**
- Service needs to be accessed from internet
- You want custom domains
- You need Cloud Armor
- You want multi-region failover

**Use Internal ALB when:**
- Service should only be accessed from VPC
- You want private IP addressing
- VMs/GKE need to access Cloud Run
- Corporate network via VPN needs access

**Use Direct Cloud Run when:**
- Simple deployment
- Don't need custom domains
- Don't need Cloud Armor
- Single region is fine
- Cost optimization (no LB charges)

## Cost Considerations

### Load Balancer Costs

**Forwarding rules:**
- $0.025/hour per rule
- ~$18/month per load balancer

**Load balancer usage:**
- $0.008/GB for first 10 TB/month
- Decreases with volume

**Example cost:**
- 1 TB/month traffic through LB
- ~$26/month ($18 forwarding rule + $8 traffic)

### When It's Worth It

**Worth the cost:**
- Production services
- Need custom domains
- Need security features
- High-value traffic

**Not worth it:**
- Development/staging
- Low-traffic internal tools
- Tight budget constraints
- Simple services

## Configuration Options

### Backend Service Settings

**Timeout:**
- Default: 30 seconds
- Max: 86400 seconds (24 hours for Cloud Run)
- Set based on longest request time

**Session affinity:**
- None (default) - distribute evenly
- Client IP - same client to same instance
- Generated cookie - for stateful apps

**Connection draining:**
- Graceful shutdown timeout
- Default: 60 seconds

### URL Map Patterns

**Path-based routing:**
```
/api/*      → Backend Service A (API)
/admin/*    → Backend Service B (Admin)
/*          → Backend Service C (Frontend)
```

**Host-based routing:**
```
api.example.com     → Backend A
admin.example.com   → Backend B
www.example.com     → Backend C
```

**Header-based routing:**
```
Header: X-Version=v2 → Backend B (new version)
Default             → Backend A (stable version)
```

## Cloud Armor Integration

Cloud Armor provides security policies at the load balancer level.

**Common policies:**

**Rate limiting:**
```
Block clients exceeding 100 requests/minute
```

**Geo-blocking:**
```
Allow only from specific countries
Deny from high-risk regions
```

**IP filtering:**
```
Allowlist: Corporate IP ranges
Blocklist: Known malicious IPs
```

**OWASP rules:**
```
Block SQL injection attempts
Block XSS attacks
Block protocol attacks
```

**Bot management:**
```
Challenge suspicious traffic
Block automated scraping
Allow verified bots (Google, Bing)
```

## Best Practices

### 1. Use HTTPS Only

Always use HTTPS target proxy, never HTTP:
- Encrypts traffic
- Required for modern web
- Free Google-managed certificates

### 2. Enable Cloud Armor

Even basic rules provide value:
- Rate limiting prevents abuse
- Geo-blocking reduces attack surface
- OWASP rules catch common attacks

### 3. Configure Appropriate Timeouts

Match backend timeout to longest request:
- API: 30-60 seconds typical
- File uploads: Longer (300+ seconds)
- Streaming: Maximum (86400 seconds)

### 4. Use Health Checks Wisely

For Cloud Run, health checks are optional:
- Cloud Run handles instance health internally
- Add custom health endpoint for business logic checks
- Keep health checks lightweight

### 5. Monitor Load Balancer Metrics

Key metrics to watch:
- Request count and latency
- Backend response times
- Error rates (4xx, 5xx)
- Cloud Armor rule matches

### 6. Plan for Multi-Region Gradually

Start with single region:
- Simpler to manage
- Lower cost
- Add regions as traffic grows

### 7. Test Thoroughly

Before going live:
- Test SSL certificate provisioning
- Verify routing rules
- Test Cloud Armor policies
- Check timeout handling

## Limitations and Considerations

**SSL certificate provisioning:**
- Takes 15-60 minutes for Google-managed certs
- Requires DNS validation
- Domain must be publicly resolvable

**Regional constraints:**
- Serverless NEG must match Cloud Run region
- Internal LB is regional only
- Plan region placement carefully

**Request size limits:**
- URL: 2048 bytes
- Headers: 16 KB
- Request body: 32 MB (for POST)

**WebSocket support:**
- Supported but requires specific configuration
- Backend timeout must be sufficient
- Consider connection draining

**Cold start visibility:**
- Cold starts still occur in Cloud Run
- Load balancer can't prevent them
- Use min instances if needed

## Key Takeaways

- Load balancers enable custom domains, Cloud Armor, and advanced routing
- Serverless NEGs connect Cloud Run to load balancers
- External ALB for internet traffic, Internal ALB for VPC traffic
- Worth the cost for production services needing security/features
- Components: Forwarding Rule → Target Proxy → URL Map → Backend Service → NEG → Cloud Run
- Test thoroughly, especially SSL provisioning and routing rules

---

Next: [Load Balancer Hands-On Lab →](./load-balancer-lab.md)
