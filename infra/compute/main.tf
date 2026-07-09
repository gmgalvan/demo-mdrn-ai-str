data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = var.terraform_state_bucket
    key    = var.networking_state_key
    region = var.aws_region
  }
}

locals {
  name = "${var.project_name}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = data.terraform_remote_state.networking.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids

  eks_managed_node_groups = {
    demo = {
      name = "${local.name}-demo"

      # The generated IAM role name ("<name>-eks-node-group") is 44 chars,
      # fine as an exact name (64-char AWS limit) but over the 38-char cap
      # AWS enforces on IAM name_prefix specifically, which the module uses
      # by default.
      iam_role_use_name_prefix = false

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      disk_size = 20
    }
  }

  tags = local.tags
}
