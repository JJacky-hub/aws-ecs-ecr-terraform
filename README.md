# AWS ECS Fargate Serverless Infrastructure via Terraform

Production-grade Infrastructure as Code (IaC) repository for deploying containerized applications to **AWS ECS Fargate** behind an **Application Load Balancer (ALB)** with **AWS ECR** and **CloudWatch** integration.

---

##  Architecture Overview

```text
                     [ Internet / HTTP Clients ]
                                  │
                                  ▼
                    [ Application Load Balancer ]
                        (ALB + Target Group)
                                  │
                                  ▼
                   [ AWS ECS Service (Fargate) ]
                 (Zero-Management Serverless Tasks)
                                  │
          ┌───────────────────────┴───────────────────────┐
          ▼                                               ▼
[ AWS ECR Repository ]                         [ CloudWatch Logs ]
(Private Docker Registry)                      (Centralized Logging)
```

---

##  Key Features

* **Serverless Compute:** Deploys Docker containers using AWS ECS Fargate (no EC2 instances to manage or patch).
* **High Availability & Routing:** Integrated Application Load Balancer (ALB) with automated target health checks.
* **Secure Image Registry:** Private AWS ECR repository configured with automated vulnerability scanning on image push (`scan_on_push = true`).
* **Centralized Observability:** Integrated AWS CloudWatch log group with retention policy to track stdout/stderr container outputs.
* **Least Privilege Access:** Granular IAM Execution Roles for seamless AWS ECR image pulls and CloudWatch logging.

---

##  Repository Structure

```text
.
├── Dockerfile           # Sample Nginx container configuration
├── main.tf              # Primary infrastructure code (ECR, ECS, ALB, IAM, CloudWatch)
├── variables.tf         # Parameterized configuration variables
├── providers.tf         # AWS Provider & Terraform version constraints
└── outputs.tf           # Exported ALB DNS endpoint & ECR Repository URL
```

---

##  Deployment Guide

### Prerequisites
* **Terraform** `>= 1.3.0`
* **AWS CLI** configured with proper credentials
* **Docker** installed and running locally

### 1. Provision ECR Repository
First, deploy only the container registry to get the repository URL:
```bash
terraform init
terraform apply -target=aws_ecr_repository.app_repo
```

### 2. Build & Push Docker Image
```bash
# Authenticate Docker to AWS ECR
aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin \$(terraform output -raw ecr_repository_url)

# Build and Tag the image
docker build -t demo-app .
docker tag demo-app:latest \$(terraform output -raw ecr_repository_url):latest

# Push to AWS ECR
docker push \$(terraform output -raw ecr_repository_url):latest
```

### 3. Deploy Full Infrastructure
Now run the full apply to deploy the ALB, ECS cluster, tasks, and logging:
```bash
terraform apply
```

After deployment is complete, fetch the Load Balancer URL to access your application:
```bash
echo \$(terraform output -raw alb_dns_name)
```

---

##  Cleanup

To avoid ongoing charges for AWS resources, completely destroy the provisioned infrastructure when finished:
```bash
terraform destroy
```
