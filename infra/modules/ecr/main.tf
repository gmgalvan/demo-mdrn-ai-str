resource "aws_ecr_repository" "repository" {
  name = var.repository_name

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  count = var.manage_lifecycle_policy ? 1 : 0

  repository = aws_ecr_repository.repository.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}