variable "snowflake_organization_name" {
  description = "Snowflake organization name"
  type        = string
  default     = "xygpmhm"
}

variable "snowflake_account_name" {
  description = "Snowflake account name"
  type        = string
  default     = "gq04150"
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "snowflake_oidc_user" {
  description = "Snowflake service user to authenticate as via GitHub OIDC workload identity. GITHUB_DEV_TERRAFORM_SVC, scoped to the DEV-Terraform GitHub Environment — used for both plan and apply, since the subject claim is now keyed on environment rather than push/pull_request."
  type        = string
  default     = "GITHUB_DEV_TERRAFORM_SVC"
}
