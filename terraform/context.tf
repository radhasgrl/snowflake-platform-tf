# Standard naming context for all Snowflake objects in this environment.
# Mirrors the naming/tagging convention pattern used across the platform's
# reference AWS Terraform repos (single source of truth for env prefixing).
#
# local.env also gates which tier's resources this apply actually manages (see the
# `count = local.env == "DEV" ? 1 : 0` / `"TEST"` conditionals in oidc_service_user.tf,
# dcm_home.tf, domain_identities.tf and domain_identities_test.tf) -- the same root module
# is applied against every tier's own state file (env/<tier>/backend.hcl), matching
# HashiCorp's documented "promote the same configuration across environments" practice
# (https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices): one DRY
# codebase, a specific git tag of it applied per environment, each environment's state
# only ever containing the resources gated on for that tier.
locals {
  env = upper(var.environment)

  # Standard comment suffix so every Terraform-managed object is identifiable in Snowflake
  managed_by_comment = "Managed by Terraform — snowflake-platform-tf"
}
