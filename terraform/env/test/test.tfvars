## Snowflake DataOps Platform — TEST environment

environment = "test"

# Without this, Terraform would silently keep authenticating as GITHUB_DEV_TERRAFORM_SVC
# (variables.tf's default) even when applying against this TEST backend/tfvars pair.
snowflake_oidc_user = "GITHUB_TEST_TERRAFORM_SVC"
