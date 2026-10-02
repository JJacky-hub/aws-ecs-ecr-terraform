# AWS ECS Fargate Serverless Infrastructure via Terraform

Production-grade Infrastructure as Code (IaC) repository for deploying containerized applications to **AWS ECS Fargate** behind an **Application Load Balancer (ALB)** with **AWS ECR** and **CloudWatch** integration.

## 🏗️ Architecture Overview

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
