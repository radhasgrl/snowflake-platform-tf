# GitHub Environment-scoped OIDC identities — one per engine (Terraform vs. DCM) per
# environment, matching the client workshop slides ("iQ - IaC Setup on Snowflake -
# Workshop 2 - Updated.pptx", Identity and Configuration Isolation) and the
# GITHUB_<ENV>_<ENGINE>_SVC naming convention used across the other reference repos.
#
# The SUBJECT claim is scoped to the GitHub Environment name (`environment:DEV-Terraform`,
# `environment:DEV-DCM`), not to a branch/event. This is deliberate: it decouples
# environment from branch, which trunk-based development (single `main` branch promoted
# through DEV/TEST/UAT/PROD) requires — a branch/event-scoped subject can't distinguish
# "this run is deploying to TEST" from "this run is deploying to PROD" when every
# environment deploys from the same branch. GitHub Environment protection rules (required
# reviewers, branch restrictions) become the per-environment gate instead.
#
# One identity per engine per environment is also enough now — unlike the old
# branch/event-scoped design, plan and deploy jobs for the same environment share the same
# GitHub Environment (and therefore the same subject claim), so a separate *_PLAN_SVC
# identity is no longer needed.

resource "snowflake_execute" "github_dev_terraform_service_user" {
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS GITHUB_DEV_TERRAFORM_SVC
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for the DEV-Terraform environment (plan + apply)'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/snowflake-platform-tf@1351137236:environment:DEV-Terraform'
      )
  SQL

  revert = "DROP USER IF EXISTS GITHUB_DEV_TERRAFORM_SVC"
}

resource "snowflake_grant_account_role" "github_dev_terraform_sysadmin" {
  provider  = snowflake.useradmin
  role_name = "SYSADMIN"
  user_name = "GITHUB_DEV_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_dev_terraform_service_user]
}

resource "snowflake_grant_account_role" "github_dev_terraform_useradmin" {
  provider  = snowflake.useradmin
  role_name = "USERADMIN"
  user_name = "GITHUB_DEV_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_dev_terraform_service_user]
}

resource "snowflake_grant_account_role" "github_dev_terraform_securityadmin" {
  provider  = snowflake.useradmin
  role_name = "SECURITYADMIN"
  user_name = "GITHUB_DEV_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_dev_terraform_service_user]
}

resource "snowflake_execute" "github_dev_dcm_service_user" {
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS GITHUB_DEV_DCM_SVC
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for the DEV-DCM environment (plan + deploy)'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/snowflake-platform-tf@1351137236:environment:DEV-DCM'
      )
  SQL

  revert = "DROP USER IF EXISTS GITHUB_DEV_DCM_SVC"
}

# Separate from the CREATE above so that setting/changing these properties never forces a
# destroy+recreate of the user itself ("CREATE OR ALTER USER" is not valid Snowflake syntax —
# the OR ALTER combinator isn't supported for USER objects). DEFAULT_ROLE/
# DEFAULT_SECONDARY_ROLES = ('ALL') matter here specifically: DCM runs as a single Snowflake
# session (unlike Terraform, which uses three separate per-role provider blocks), but still
# needs to create objects across all three privilege domains in that one session —
# databases/schemas/warehouses (SYSADMIN), roles (USERADMIN), and masking/row-access
# policies (SECURITYADMIN). Secondary roles make all three active at once.
resource "snowflake_execute" "github_dev_dcm_service_user_defaults" {
  provider = snowflake.useradmin

  execute = "ALTER USER GITHUB_DEV_DCM_SVC SET DEFAULT_ROLE = SYSADMIN, DEFAULT_SECONDARY_ROLES = ('ALL')"
  revert  = "ALTER USER GITHUB_DEV_DCM_SVC UNSET DEFAULT_ROLE, DEFAULT_SECONDARY_ROLES"

  depends_on = [snowflake_execute.github_dev_dcm_service_user]
}

resource "snowflake_grant_account_role" "github_dev_dcm_sysadmin" {
  provider  = snowflake.useradmin
  role_name = "SYSADMIN"
  user_name = "GITHUB_DEV_DCM_SVC"

  depends_on = [snowflake_execute.github_dev_dcm_service_user]
}

resource "snowflake_grant_account_role" "github_dev_dcm_useradmin" {
  provider  = snowflake.useradmin
  role_name = "USERADMIN"
  user_name = "GITHUB_DEV_DCM_SVC"

  depends_on = [snowflake_execute.github_dev_dcm_service_user]
}

resource "snowflake_grant_account_role" "github_dev_dcm_securityadmin" {
  provider  = snowflake.useradmin
  role_name = "SECURITYADMIN"
  user_name = "GITHUB_DEV_DCM_SVC"

  depends_on = [snowflake_execute.github_dev_dcm_service_user]
}

# dbt identity — deliberately least-privilege, unlike the two identities above. This user
# gets no admin role grants from Terraform at all; DCM grants it only the
# DEV_CUSTOMER_DBT_SERVICE_PRSN persona role it actually needs (see
# ../dcm/sources/definitions/grants.sql), demonstrating the tiered RBAC model in practice
# for a real downstream workload (Repo 3, customer-domain-dbt).
resource "snowflake_execute" "github_dev_dbt_service_user" {
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS GITHUB_DEV_DBT_SVC
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for customer-domain-dbt (Repo 3) — least-privilege, scoped to DEV_CUSTOMER_DBT_SERVICE_PRSN only'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/customer-domain-dbt@1405522917:environment:DEV-dbt'
      )
  SQL

  revert = "DROP USER IF EXISTS GITHUB_DEV_DBT_SVC"
}

# Ingestion identity (Repo 2, data-ingestion-raw) — same least-privilege pattern as the dbt
# identity above. DCM grants it DEV_CUSTOMER_INGEST_SERVICE_PRSN only (see
# ../dcm/sources/definitions/grants.sql), which in turn only carries
# DEV_CUSTOMER_INGEST_FNCRL — enough to create/manage the storage integration, stage, file
# format and pipe, and load into RAW, nothing more.
resource "snowflake_execute" "github_dev_ingest_service_user" {
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS GITHUB_DEV_INGEST_SVC
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for data-ingestion-raw (Repo 2) — least-privilege, scoped to DEV_CUSTOMER_INGEST_SERVICE_PRSN only'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/data-ingestion-raw@1405785591:environment:DEV-Ingest'
      )
  SQL

  revert = "DROP USER IF EXISTS GITHUB_DEV_INGEST_SVC"
}
