variable "aws_region" {
  description = "AWS region for the OIDC provider and role"
  type        = string
  default     = "ap-southeast-2"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository"
  type        = string
  default     = "radhasgrl"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "snowflake-platform-tf"
}

variable "state_bucket_name" {
  description = "S3 bucket the pipeline needs read/write access to (Terraform state)"
  type        = string
  default     = "snowflake-platform-tf-state-525218385225"
}
