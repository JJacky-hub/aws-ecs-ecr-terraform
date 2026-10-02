variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-north-1"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "demo-app"
}

variable "environment" {
  description = "Environment stage"
  type        = string
  default     = "dev"
}
