# 🏗️ Twodo App - Infrastructure (IaC)

This repository manages the AWS cloud infrastructure for the Twodo application using Terraform.

## 🚀 Architecture
The infrastructure follows a modular design to ensure scalability and security:
- **VPC**: Custom network with public subnets across 2 Availability Zones.
- **EKS**: Managed Kubernetes cluster (v1.31) with optimized Node Groups.
- **RDS**: Managed PostgreSQL instance with dedicated security groups.
- **Observability**: Integrated with Amazon CloudWatch for logs and Prometheus/Grafana for metrics.

## 📂 Directory Structure
- `vpc.tf` - Networking infrastructure and subnets.
- `eks.tf` - EKS cluster definition and node configuration.
- `rds.tf` - Database provisioning and connectivity.
- `cloudwatch.tf` - Logging and observability setup.
- `providers.tf` - AWS, Kubernetes, and Helm provider configurations.
- `variables.tf` - Infrastructure input variables.

## 🛠️ Deployment Instructions
1. Ensure AWS credentials are configured locally.
2. Initialize the project:
   ```bash
   terraform init