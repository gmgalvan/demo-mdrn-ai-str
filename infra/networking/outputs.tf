output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs for load balancers."
  value       = module.vpc.public_subnet_ids
}

output "aws_region" {
  description = "AWS region used by this layer."
  value       = var.aws_region
}

output "project_name" {
  description = "Project name used by this layer."
  value       = var.project_name
}

output "environment" {
  description = "Environment used by this layer."
  value       = var.environment
}

