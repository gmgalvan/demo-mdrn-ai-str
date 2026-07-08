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

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway to keep demo costs low."
  type        = bool
  default     = true
}

