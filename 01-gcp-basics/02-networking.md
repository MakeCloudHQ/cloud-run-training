# Networking Basics

Understanding Google Cloud networking is essential for deploying services, especially Cloud Run with VPC connectivity.

## VPC (Virtual Private Cloud)

A VPC is your private network space within Google Cloud.

### Key Concepts

**Global Resource**: Unlike AWS, Google Cloud VPCs are global
- Spans all regions
- Subnets are regional (but VPC is global)

**Default VPC**: Every new project gets one
- Pre-configured subnets in each region
- Default firewall rules
- Good for getting started, but customize for production

### VPC Architecture

```
VPC (Global)
    ├── Subnet A (us-central1) - 10.128.0.0/20
    ├── Subnet B (europe-west1) - 10.132.0.0/20
    └── Subnet C (asia-east1) - 10.140.0.0/20
```

## Subnets

Subnets divide your VPC into smaller network segments.

**Characteristics:**
- Regional (exist in one region)
- Have an IP range (CIDR block)
- Resources attach to subnets
- Primary and secondary ranges

### Subnet Example

```bash
# Create a custom subnet
gcloud compute networks subnets create my-subnet \
    --network=my-vpc \
    --region=us-central1 \
    --range=10.0.1.0/24
```

### IP Addressing

**RFC 1918 Private Ranges** (commonly used):
- `10.0.0.0/8` - Large networks
- `172.16.0.0/12` - Medium networks
- `192.168.0.0/16` - Small networks

**Subnet Size Planning:**
- `/20` subnet = 4,094 usable IPs
- `/24` subnet = 254 usable IPs
- `/28` subnet = 14 usable IPs

Google Cloud reserves first 2 and last 2 IPs in each subnet.

## Types of VPCs

### 1. Default VPC (Auto Mode)

Created automatically with new projects.

**Characteristics:**
- One subnet per region automatically
- Predefined IP ranges
- Default firewall rules
- Good for: Learning, simple deployments

### 2. Custom VPC

You control everything.

**Characteristics:**
- Choose which regions get subnets
- Define your own IP ranges
- Custom firewall rules
- Good for: Production, complex networking

```bash
# Create custom VPC
gcloud compute networks create my-vpc \
    --subnet-mode=custom \
    --bgp-routing-mode=regional

# Add subnets as needed
gcloud compute networks subnets create my-subnet \
    --network=my-vpc \
    --region=us-central1 \
    --range=10.0.0.0/24
```

## Firewall Rules

Control traffic to and from your resources.

### How Firewall Rules Work

- Applied at VPC level
- Stateful (return traffic automatically allowed)
- Can allow or deny traffic
- Evaluated based on priority (0-65535, lower = higher priority)

### Common Firewall Patterns

**Allow SSH (for debugging):**
```bash
gcloud compute firewall-rules create allow-ssh \
    --network=my-vpc \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0
```

**Allow HTTP/HTTPS:**
```bash
gcloud compute firewall-rules create allow-web \
    --network=my-vpc \
    --allow=tcp:80,tcp:443 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=web-server
```

**Allow internal traffic:**
```bash
gcloud compute firewall-rules create allow-internal \
    --network=my-vpc \
    --allow=tcp:0-65535,udp:0-65535,icmp \
    --source-ranges=10.0.0.0/8
```

### Firewall Rule Components

- **Direction**: Ingress (incoming) or Egress (outgoing)
- **Priority**: 0-65535 (default: 1000)
- **Action**: Allow or Deny
- **Target**: Which resources this applies to (tags, service accounts, all)
- **Source/Destination**: IP ranges, tags, service accounts
- **Protocols and Ports**: tcp:80, udp:53, icmp, etc.

## Cloud NAT

Allows resources without external IPs to access the internet.

### Why Cloud NAT?

- Security: VMs/Cloud Run don't need public IPs
- Cost: Fewer public IPs needed
- Control: Centralized egress point

### Use Case for Cloud Run

Cloud Run services with VPC egress need NAT to access public internet:

```bash
# Create Cloud Router (required for NAT)
gcloud compute routers create my-router \
    --network=my-vpc \
    --region=us-central1

# Create NAT configuration
gcloud compute routers nats create my-nat \
    --router=my-router \
    --region=us-central1 \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips
```

**NAT Diagram:**
```
Cloud Run Service (no public IP)
    ↓ (via VPC Connector)
VPC Subnet
    ↓ (via Cloud NAT)
Cloud Router
    ↓
Internet
```

## Connectivity Options

### 1. Public Internet

**Default for Cloud Run**: Services are accessible via public URLs
- Simplest option
- No VPC configuration needed
- Can still require authentication

### 2. VPC Connector (Serverless VPC Access)

Connects serverless services (Cloud Run, Cloud Functions) to VPC.

**Use Cases:**
- Access private databases (Cloud SQL, etc.)
- Connect to VMs in VPC
- Access internal services

```bash
# Create VPC connector
gcloud compute networks vpc-access connectors create my-connector \
    --network=my-vpc \
    --region=us-central1 \
    --range=10.8.0.0/28
```

**Limitations:**
- Regional resource
- Requires dedicated subnet range (/28)
- Has throughput limits (scale by adding connectors)

### 3. VPC Peering

Connect two VPCs directly.

**Use Cases:**
- Multi-project architectures
- Shared services
- Connect to partner networks

### 4. Cloud VPN / Interconnect

Connect Google Cloud to on-premises networks.

- **Cloud VPN**: Encrypted tunnel over internet
- **Cloud Interconnect**: Dedicated physical connection

## Private vs Public IPs

### External (Public) IPs

- Routable on the internet
- Cost per IP per month
- Can be ephemeral (changes) or static (reserved)

### Internal (Private) IPs

- Only accessible within VPC (or connected networks)
- RFC 1918 ranges
- Free
- Assigned from subnet range

### Cloud Run Specifics

**Ingress** (incoming traffic):
- Can be public (default)
- Can be restricted to internal VPC traffic
- Can be restricted to internal + Cloud Load Balancing

**Egress** (outgoing traffic):
- Default: Direct to internet (via public IP)
- Optional: Route through VPC (requires VPC Connector)

## DNS in Google Cloud

### Cloud DNS

Managed DNS service for public domains.

### Internal DNS

- Automatic for VMs in VPC
- VM names automatically get DNS entries
- Zone: `[region].c.[project-id].internal`

Example:
```
my-vm.us-central1-a.c.my-project.internal
```

### Private DNS for Cloud Run

Cloud Run services get public URLs by default:
```
https://my-service-abc123-uc.a.run.app
```

For internal-only access, use:
- Internal Application Load Balancer
- Private Service Connect

## Viewing Your Network Configuration

### Console

Navigate to: **VPC network** section
- VPC networks
- Subnets
- Firewall rules
- Routes

### gcloud Commands

```bash
# List VPCs
gcloud compute networks list

# List subnets
gcloud compute networks subnets list

# List firewall rules
gcloud compute firewall-rules list

# Describe a specific VPC
gcloud compute networks describe default
```

## Common Networking Patterns for Cloud Run

### 1. Public Service (Default)

```
Internet → Cloud Run (public URL)
```

Simplest setup, no VPC configuration needed.

### 2. Public Service with Private Dependencies

```
Internet → Cloud Run (public URL)
           ↓ (via VPC Connector)
           Private Cloud SQL
```

Requires VPC Connector and Cloud NAT.

### 3. Internal Service

```
Cloud Load Balancer (internal)
    ↓
Cloud Run (internal ingress only)
    ↓ (via VPC Connector)
VPC Resources
```

Fully private, accessed only within VPC or via VPN/Interconnect.

## Key Takeaways

- Google Cloud VPCs are global, subnets are regional
- Firewall rules are stateful and applied at VPC level
- Cloud NAT enables internet access for resources without public IPs
- VPC Connectors link Cloud Run to VPC resources
- Plan IP ranges carefully - they can't easily be changed later
- Default VPC is fine for learning, but customize for production

## Best Practices

1. **Use Custom VPCs** for production
2. **Plan IP ranges** before creating subnets (avoid overlaps)
3. **Least privilege firewall rules** (restrict source ranges)
4. **Use Cloud NAT** instead of giving everything public IPs
5. **Tag resources** for targeted firewall rules
6. **Enable VPC Flow Logs** for troubleshooting
7. **Use Shared VPC** for multi-project architectures

## Discussion Points

- Do you need VPC connectivity for your Cloud Run services?
- What private resources will Cloud Run need to access?
- Public vs internal ingress requirements?
- Network security requirements?

---

Next: [IAM (Identity and Access Management) →](./03-iam.md)
