# USERADMIN provider — the only role this repo's Terraform resources still need going
# forward, now that databases/schemas/warehouses/roles/grants/masking/row-access policies
# have moved to DCM (../dcm/_template/sources/definitions/). Terraform's remaining scope is
# identity/OIDC bootstrap only (oidc_service_user.tf), which exclusively uses USERADMIN.
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

# AWS provider — for ingestion_aws_infra.tf (Repo 2's S3 bucket + IAM roles). Authenticates
# via the same GitHub OIDC role (snowflake-platform-tf-github-oidc) this repo's CI already
# uses for Terraform state access; bootstrap/oidc-identity/ grants it the additional,
# narrowly scoped permissions needed to manage these specific ingestion resources.
provider "aws" {
  region = "ap-southeast-2"
}
