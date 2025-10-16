# Networking Basics

Understanding Google Cloud networking is essential for deploying secure, well-architected cloud infrastructure.

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
    ├── Subnet A (europe-west2) - 10.128.0.0/20
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

### 3. Shared VPC

A centralized VPC shared across multiple projects in an organization.

**Characteristics:**
- **Host Project**: Contains the shared VPC network
- **Service Projects**: Attach to the host project's network
- Centralized network administration
- Resource sharing across projects
- Good for: Enterprise architectures, team isolation with shared networking

**Benefits:**
- Centralized firewall and routing management
- Shared resources (Cloud NAT, VPN, etc.)
- Separation of concerns (network admins vs. app developers)
- Cost efficiency (shared egress paths)

## Firewall Rules

Control traffic to and from your resources.

### How Firewall Rules Work

- Applied at VPC level
- Stateful (return traffic automatically allowed)
- Can allow or deny traffic
- Evaluated based on priority (0-65535, lower = higher priority)

### Common Firewall Patterns

**Allow SSH from IAP (for debugging):**
- Source: `35.235.240.0/20` (Google's Identity-Aware Proxy)
- Protocol: TCP port 22
- More secure than allowing SSH from anywhere

**Allow HTTP/HTTPS:**
- Source: `0.0.0.0/0` (public internet)
- Protocols: TCP ports 80 and 443
- Use target tags to apply only to web servers

**Allow internal traffic:**
- Source: Your VPC CIDR range (e.g., `10.0.0.0/8`)
- Protocols: All TCP/UDP ports, ICMP
- Allows resources in VPC to communicate

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

- **Security**: Resources don't need public IPs
- **Cost**: Fewer public IPs needed (billed per IP)
- **Control**: Centralized egress point
- **Compliance**: Fixed egress IPs for allowlisting

### How it Works

1. Resources in VPC send traffic to internet
2. Traffic routes through Cloud Router
3. Cloud NAT translates private IPs to public IPs
4. Return traffic automatically routed back

**Requirements:**
- Cloud Router in the same region as your subnet
- NAT gateway configuration on the router
- Subnet must be in the VPC

**Use Cases:**
- VMs without public IPs downloading software
- Serverless services (Cloud Run, Cloud Functions) accessing external APIs
- Private GKE clusters accessing container registries

## VPC Connectivity Options

### 1. VPC Peering

Connect two VPCs directly for private communication.

**Use Cases:**
- Multi-project architectures
- Shared services between teams
- Connect to partner/vendor networks

**Characteristics:**
- Bi-directional traffic
- No IP address translation
- Transitive peering not supported
- Global (works across regions)

### 2. Shared VPC

Centralized VPC shared across multiple projects (covered earlier).

**Use Cases:**
- Enterprise organizations
- Centralized network management
- Team isolation with shared networking

### 3. Cloud VPN

Encrypted IPsec tunnel over the internet.

**Use Cases:**
- Hybrid cloud (connect to on-premises)
- Site-to-site connectivity
- Remote office connectivity

**Types:**
- **HA VPN**: 99.99% SLA, multiple tunnels
- **Classic VPN**: Single tunnel, lower SLA

### 4. Cloud Interconnect

Dedicated physical connection to Google Cloud.

**Use Cases:**
- High bandwidth requirements
- Lower latency needs
- Regulatory compliance (dedicated connection)

**Types:**
- **Dedicated Interconnect**: 10 Gbps or 100 Gbps circuits
- **Partner Interconnect**: Via service provider, flexible bandwidth

## Private vs Public IPs

### External (Public) IPs

- Routable on the internet
- Cost per IP per month (~$3-4/month if reserved)
- Can be ephemeral (changes on restart) or static (reserved)
- Used for: Load balancers, NAT gateways, VPN endpoints

### Internal (Private) IPs

- Only accessible within VPC (or connected networks)
- RFC 1918 ranges (10.x.x.x, 172.16.x.x, 192.168.x.x)
- Free
- Assigned automatically from subnet range
- Used for: VMs, GKE pods, internal load balancers

## DNS in Google Cloud

### Cloud DNS

Managed, authoritative DNS service for public domains.

**Features:**
- Low latency, global anycast network
- 100% uptime SLA
- DNSSEC support
- API and Terraform manageable

### Internal DNS (Zonal DNS)

Automatic DNS for resources in VPC:
- VM instances get automatic DNS names
- Zone format: `[zone].c.[project-id].internal`
- Example: `my-vm.europe-west2-a.c.my-project.internal`

### Private DNS Zones

Create custom internal DNS zones within your VPC:
- Custom domain names for internal resources
- Split-horizon DNS (different answers for internal vs external)
- Useful for service discovery

## Viewing Your Network Configuration

### Console

Navigate to: **VPC network** section in Cloud Console
- VPC networks: View all networks
- Subnets: Regional subnet configurations
- Firewall rules: Ingress/egress rules
- Routes: Routing tables
- VPC Network Peering: Connected networks

## Key Takeaways

- Google Cloud VPCs are **global**, subnets are **regional**
- Firewall rules are **stateful** and applied at the VPC level
- Cloud NAT enables internet access for resources without public IPs
- **Shared VPC** allows centralized network management across projects
- Plan IP ranges carefully - they can't easily be changed later
- Default VPC is fine for learning, but **custom VPCs** are recommended for production
- Multiple connectivity options: VPC Peering, VPN, Interconnect

## Best Practices

1. **Use Custom VPCs** for production workloads
2. **Plan IP ranges** before creating subnets (avoid overlaps, plan for growth)
3. **Least privilege firewall rules** - restrict source ranges, use tags
4. **Use Cloud NAT** instead of assigning public IPs to every resource
5. **Tag resources** for targeted firewall rule application
6. **Enable VPC Flow Logs** for network troubleshooting and security analysis
7. **Use Shared VPC** for multi-project enterprise architectures
8. **Document your network design** - subnet purposes, IP ranges, routing

## Network Security Considerations

- **Defense in depth**: Use multiple layers (firewall rules, IAM, service perimeters)
- **Principle of least privilege**: Only open necessary ports and protocols
- **Use private IPs** where possible, limit public exposure
- **Enable Private Google Access** for accessing Google APIs from private IPs
- **Consider VPC Service Controls** for additional security boundaries
- **Monitor network traffic** with VPC Flow Logs and Cloud Logging

---

Next: [IAM (Identity and Access Management) →](./03-iam.md)
