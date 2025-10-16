# Cloud Run Advanced

Deep dive into production-ready Cloud Run deployments and migration strategies.

## Duration: 1-2 hours

## Learning Objectives

By the end of this section, you should be able to:
- Compare gcloud CLI and Terraform for managing Cloud Run
- Configure VPC networking for Cloud Run services
- Design effective scaling strategies
- Identify and avoid common gotchas
- Plan migrations from GKE to Cloud Run

## Topics

1. [gcloud vs Terraform](./01-gcloud-vs-terraform.md) - Infrastructure as Code approaches
2. [VPC Networking](./02-vpc-networking.md) - Private networking and VPC integration
3. [Scaling Strategies](./03-scaling.md) - Performance and cost optimization
4. [Common Gotchas](./04-common-gotchas.md) - Avoiding pitfalls
5. [GKE Migration](./05-gke-migration.md) - Moving from GKE to Cloud Run

## Prerequisites

- Completed [Cloud Run Basics](../02-cloud-run-basics/)
- Understanding of containers and HTTP services
- Familiarity with infrastructure as code concepts (helpful but not required)

## Session Format

This section is more advanced and assumes you have experience deploying services. We'll cover:
- Production deployment patterns
- Real-world scenarios and solutions
- Trade-offs and decision-making
- Migration strategies

Feel free to ask questions and share your specific use cases throughout.

## Quick Reference

### When to Use What

**gcloud CLI:**
- Quick experiments
- One-off deployments
- Local development
- Learning/prototyping

**Terraform:**
- Production environments
- Multi-service deployments
- Team collaboration
- Repeatable infrastructure

**VPC Networking:**
- Need private databases (Cloud SQL, etc.)
- Internal service communication
- Compliance requirements
- Hybrid cloud scenarios

**Scaling Configuration:**
- Start simple: Use defaults
- Optimize after measuring
- Adjust based on traffic patterns
- Balance cost vs performance

---

Let's start with [gcloud vs Terraform →](./01-gcloud-vs-terraform.md)
