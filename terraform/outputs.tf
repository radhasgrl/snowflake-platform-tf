# Databases, schemas, warehouses, functional roles, grants and placeholder masking/row-access
# policies moved to DCM (see ../dcm/sources/definitions/) — their outputs moved with them.
# Terraform's remaining scope is the account/platform layer: the GitHub OIDC service
# identities below. One identity per engine per environment — see oidc_service_user.tf for
# why the old separate *_PLAN_SVC identities are no longer needed.

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

# Ingestion AWS infra (ingestion_aws_infra.tf) — migrated here from Repo 2's standalone
# aws/ Terraform root via `terraform import`.
output "ingestion_bucket_name" {
  value = aws_s3_bucket.ingestion_raw.bucket
}

output "ingestion_github_actions_role_arn" {
  value       = aws_iam_role.github_actions_ingestion.arn
  description = "Referenced by data-ingestion-raw's own workflows as role-to-assume"
}

output "ingestion_snowflake_storage_integration_role_arn" {
  value       = aws_iam_role.snowflake_storage_integration.arn
  description = "Referenced by data-ingestion-raw's sql/02_storage_integration.sql as STORAGE_AWS_ROLE_ARN"
}
