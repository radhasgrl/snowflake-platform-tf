# SYSADMIN provider — manages databases, warehouses, schemas
provider "snowflake" {
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.snowflake_oidc_user
  role                       = "SYSADMIN"
  authenticator              = "WORKLOAD_IDENTITY"
  workload_identity_provider = "OIDC"
}

# USERADMIN provider — manages roles, users, and grants
provider "snowflake" {
  alias                      = "useradmin"
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.snowflake_oidc_user
  role                       = "USERADMIN"
  authenticator              = "WORKLOAD_IDENTITY"
  workload_identity_provider = "OIDC"
}

# SECURITYADMIN provider — manages masking and row access policies
provider "snowflake" {
  alias                      = "securityadmin"
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.snowflake_oidc_user
  role                       = "SECURITYADMIN"
  authenticator              = "WORKLOAD_IDENTITY"
  workload_identity_provider = "OIDC"
}
