data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../modules/vpc"

  name       = local.name
  aws_region = var.aws_region
  cidr       = var.vpc_cidr

  availability_zones   = local.azs
  public_subnet_count  = length(local.azs)
  private_subnet_count = length(local.azs)

  # This module only supports a single shared NAT Gateway (no per-AZ HA
  # mode), which matches this project's cost-conscious default anyway.
  enable_nat_gateway = var.single_nat_gateway

  # Off by default to avoid extra CloudWatch/IAM resources this demo
  # doesn't need; the S3 gateway endpoint is free, so it stays on.
  enable_flow_logs           = false
  enable_s3_gateway_endpoint = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  additional_tags = local.tags
}
