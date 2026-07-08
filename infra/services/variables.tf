variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "modern-ai-strategies"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "repository_names" {
  description = "ECR repository names to create, one per service image pushed by CI."
  type        = list(string)
  default     = ["payment-api", "webui"]
}

variable "image_retention_count" {
  description = "Number of most recent images to keep per repository before expiring older ones."
  type        = number
  default     = 10
}
