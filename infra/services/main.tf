locals {
  name = "${var.project_name}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

module "ecr" {
  source = "../modules/ecr"

  for_each = toset(var.repository_names)

  repository_name = each.value
  scan_on_push    = true
  tags            = local.tags

  # Managed below instead: the module's built-in policy only expires
  # untagged images, but our CI always tags pushes (latest, sha-xxx), so
  # that policy would never fire and repos would grow unbounded.
  manage_lifecycle_policy = false
}

# Keep the registry from growing unbounded: GitHub Actions pushes on every
# build, so without this every PR/merge would leave an image behind forever.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = module.ecr

  repository = each.value.repository_name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.image_retention_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
