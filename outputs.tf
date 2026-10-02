output "ecr_repository_url" {
  description = "URL of the ECR repository to push Docker images"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "alb_dns_name" {
  description = "The permanent DNS name of the Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}
