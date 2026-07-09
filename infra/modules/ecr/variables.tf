variable "repository_name" {
  type        = string
  description = "Name of the ECR repository"
}

variable "scan_on_push" {
  type        = bool
  description = "Whether to scan on push"
}


variable "tags" {
  type        = map(string)
  description = "Tags to apply to the ECR repository"
  default     = {}
}

variable "manage_lifecycle_policy" {
  type        = bool
  description = "Whether this module manages its own lifecycle policy (expire untagged images after 30 days). Set to false to manage the lifecycle policy yourself outside the module."
  default     = true
}
