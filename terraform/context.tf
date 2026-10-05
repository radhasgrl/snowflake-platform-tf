# Standard naming context for all Snowflake objects in this environment.
# Mirrors the naming/tagging convention pattern used across the platform's
# reference AWS Terraform repos (single source of truth for env prefixing).
locals {
  env = upper(var.environment)

  # Standard comment suffix so every Terraform-managed object is identifiable in Snowflake
  managed_by_comment = "Managed by Terraform — snowflake-platform-tf"
}
