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
  description = "Deployment environment (dev, qa, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

variable "snowflake_oidc_user" {
  description = "Snowflake service user to authenticate as via GitHub OIDC workload identity. Differs per workflow: GITHUB_OIDC_TERRAFORM_SVC for apply (push to main), GITHUB_OIDC_TERRAFORM_PLAN_SVC for plan (pull_request) — Snowflake's WORKLOAD_IDENTITY subject match is exact, so each trigger needs its own service user."
  type        = string
  default     = "GITHUB_OIDC_TERRAFORM_SVC"
}
