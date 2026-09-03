# SYSADMIN provider — manages databases, warehouses, schemas
provider "snowflake" {
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = "TERRAFORM_SVC"
  role              = "SYSADMIN"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.snowflake_private_key_path)
}

# USERADMIN provider — manages roles, users, and grants
provider "snowflake" {
  alias             = "useradmin"
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = "TERRAFORM_SVC"
  role              = "USERADMIN"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.snowflake_private_key_path)
}

# SECURITYADMIN provider — manages masking and row access policies
provider "snowflake" {
  alias             = "securityadmin"
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = "TERRAFORM_SVC"
  role              = "SECURITYADMIN"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.snowflake_private_key_path)
}
