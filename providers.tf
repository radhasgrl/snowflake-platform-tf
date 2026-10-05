# ---------------------------------------------------------------------------------------
# TEMPORARY — default (unaliased) and securityadmin providers, kept only so `removed.tf`
# can resolve the provider configuration for resources still present in Terraform state
# from before the DCM migration (databases.tf/schemas.tf/warehouses.tf resources used the
# bare default provider; masking.tf/row_access.tf used `snowflake.securityadmin`). Terraform
# requires the original provider config to still exist to clean up an orphaned resource —
# see the "Provider configuration not present" error this fixed. DELETE both of these blocks
# in a follow-up PR once a `terraform plan` after this one merges shows no more orphans.
# ---------------------------------------------------------------------------------------
provider "snowflake" {
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.snowflake_oidc_user
  role                       = "SYSADMIN"
  authenticator              = "WORKLOAD_IDENTITY"
  workload_identity_provider = "OIDC"
}

provider "snowflake" {
  alias                      = "securityadmin"
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.snowflake_oidc_user
  role                       = "SECURITYADMIN"
  authenticator              = "WORKLOAD_IDENTITY"
  workload_identity_provider = "OIDC"
}

# USERADMIN provider — the only role this repo's Terraform resources still need going
# forward, now that databases/schemas/warehouses/roles/grants/masking/row-access policies
# have moved to DCM (sources/definitions/). Terraform's remaining scope is identity/OIDC
# bootstrap only (oidc_service_user.tf), which exclusively uses USERADMIN.
provider "snowflake" {
  alias                      = "useradmin"
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.snowflake_oidc_user
  role                       = "USERADMIN"
  authenticator              = "WORKLOAD_IDENTITY"
  workload_identity_provider = "OIDC"
}

# SYSADMIN provider — used only to create the small Terraform-owned "admin" database/schema
# that hosts the DCM project object (dcm_home.tf), so the DCM project's own container is
# never one of the databases DCM itself manages. Matches the infra-platform reference
# template's ADMIN_<ENV>.DCM.<PROJECT> pattern.
provider "snowflake" {
  alias                      = "sysadmin"
  organization_name          = var.snowflake_organization_name
  account_name               = var.snowflake_account_name
  user                       = var.snowflake_oidc_user
  role                       = "SYSADMIN"
  authenticator              = "WORKLOAD_IDENTITY"
  workload_identity_provider = "OIDC"
}
