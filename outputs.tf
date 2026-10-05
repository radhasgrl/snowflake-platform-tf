# Databases, schemas, warehouses, functional roles, grants and placeholder masking/row-access
# policies moved to DCM (see sources/definitions/) — their outputs moved with them. Terraform's
# remaining scope is the account/platform layer: the GitHub OIDC service identities below.
# One identity per engine per environment — see oidc_service_user.tf for why the old
# separate *_PLAN_SVC identities are no longer needed.

output "dev_terraform_oidc_user" {
  value = "GITHUB_DEV_TERRAFORM_SVC"
}

output "dev_dcm_oidc_user" {
  value = "GITHUB_DEV_DCM_SVC"
}

output "dev_dbt_oidc_user" {
  value = "GITHUB_DEV_DBT_SVC"
}

output "dev_admin_db_name" {
  value = snowflake_database.admin.name
}
