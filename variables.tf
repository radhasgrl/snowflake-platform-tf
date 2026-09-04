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
