output "repository_urls" {
  description = "Map of repository name to its ECR URL (image push/pull target, e.g. in CI or k8s manifests)."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "registry_id" {
  description = "AWS account ID that owns the registry (same for every repository in this layer)."
  value       = length(aws_ecr_repository.this) > 0 ? values(aws_ecr_repository.this)[0].registry_id : null
}
