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

variable "snowflake_private_key_path" {
  description = "Path to the RSA private key for TERRAFORM_SVC"
  type        = string
  default     = "~/.ssh/snowflake/tf_snow_key.p8"
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

variable "use_workload_identity" {
  description = "Use GitHub OIDC workload identity (GITHUB_OIDC_TERRAFORM_SVC) instead of RSA key-pair (TERRAFORM_SVC) for Snowflake auth"
  type        = bool
  default     = false
}

variable "snowflake_oidc_user" {
  description = "Snowflake service user to authenticate as when use_workload_identity is true. Differs per workflow: GITHUB_OIDC_TERRAFORM_SVC for apply (push to main), GITHUB_OIDC_TERRAFORM_PLAN_SVC for plan (pull_request) — Snowflake's WORKLOAD_IDENTITY subject match is exact, so each trigger needs its own service user."
  type        = string
  default     = "GITHUB_OIDC_TERRAFORM_SVC"
}
