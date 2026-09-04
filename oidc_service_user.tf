# One-time creation of a service user trusting GitHub's OIDC issuer.
# SUBJECT is an exact match (Snowflake does not support wildcards here,
# unlike AWS IAM's StringLike condition) — scoped to push-to-main only,
# matching the terraform-apply workflow's actual sub claim.
resource "snowflake_execute" "github_oidc_service_user" {
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS GITHUB_OIDC_TERRAFORM_SVC
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for terraform-apply.yml (push to main)'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/snowflake-platform-tf@1351137236:ref:refs/heads/main'
      )
  SQL

  revert = "DROP USER IF EXISTS GITHUB_OIDC_TERRAFORM_SVC"
}

resource "snowflake_grant_account_role" "github_oidc_sysadmin" {
  provider  = snowflake.useradmin
  role_name = "SYSADMIN"
  user_name = "GITHUB_OIDC_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_oidc_service_user]
}

resource "snowflake_grant_account_role" "github_oidc_useradmin" {
  provider  = snowflake.useradmin
  role_name = "USERADMIN"
  user_name = "GITHUB_OIDC_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_oidc_service_user]
}

resource "snowflake_grant_account_role" "github_oidc_securityadmin" {
  provider  = snowflake.useradmin
  role_name = "SECURITYADMIN"
  user_name = "GITHUB_OIDC_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_oidc_service_user]
}
