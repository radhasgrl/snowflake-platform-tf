# SYSADMIN provider — manages databases, warehouses, schemas
provider "snowflake" {
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.use_workload_identity ? var.snowflake_oidc_user : "TERRAFORM_SVC"
  role                       = "SYSADMIN"
  authenticator              = var.use_workload_identity ? "WORKLOAD_IDENTITY" : "SNOWFLAKE_JWT"
  workload_identity_provider = var.use_workload_identity ? "OIDC" : null
  private_key                = var.use_workload_identity ? null : file(var.snowflake_private_key_path)
}

# USERADMIN provider — manages roles, users, and grants
provider "snowflake" {
  alias                      = "useradmin"
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.use_workload_identity ? var.snowflake_oidc_user : "TERRAFORM_SVC"
  role                       = "USERADMIN"
  authenticator              = var.use_workload_identity ? "WORKLOAD_IDENTITY" : "SNOWFLAKE_JWT"
  workload_identity_provider = var.use_workload_identity ? "OIDC" : null
  private_key                = var.use_workload_identity ? null : file(var.snowflake_private_key_path)
}

# SECURITYADMIN provider — manages masking and row access policies
provider "snowflake" {
  alias                      = "securityadmin"
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.use_workload_identity ? var.snowflake_oidc_user : "TERRAFORM_SVC"
  role                       = "SECURITYADMIN"
  authenticator              = var.use_workload_identity ? "WORKLOAD_IDENTITY" : "SNOWFLAKE_JWT"
  workload_identity_provider = var.use_workload_identity ? "OIDC" : null
  private_key                = var.use_workload_identity ? null : file(var.snowflake_private_key_path)
}
