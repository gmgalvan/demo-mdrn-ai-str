output "repository_urls" {
  description = "Map of repository name to its ECR URL (image push/pull target, e.g. in CI or k8s manifests)."
  value       = { for name, repo in module.ecr : name => repo.repository_url }
}

output "registry_id" {
  description = "AWS account ID that owns the registry (same for every repository in this layer)."
  value       = data.aws_caller_identity.current.account_id
}
