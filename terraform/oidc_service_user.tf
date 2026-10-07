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

# TEST-tier platform identities — identical pattern to the DEV identities above, just a
# different GitHub Environment name in the SUBJECT claim (environment:TEST-Terraform /
# environment:TEST-DCM instead of environment:DEV-Terraform / environment:DEV-DCM). These
# are genuinely separate Snowflake users from their DEV counterparts: a TEST deploy must
# never be able to authenticate as, or be confused with, a DEV deploy. TEST-Terraform and
# TEST-DCM GitHub Environments (with a required-reviewer protection rule) are what actually
# gate when these identities' tokens can be minted at all -- see promote.yml.
resource "snowflake_execute" "github_test_terraform_service_user" {
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS GITHUB_TEST_TERRAFORM_SVC
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for the TEST-Terraform environment (promote.yml)'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/snowflake-platform-tf@1351137236:environment:TEST-Terraform'
      )
  SQL

  revert = "DROP USER IF EXISTS GITHUB_TEST_TERRAFORM_SVC"
}

resource "snowflake_grant_account_role" "github_test_terraform_sysadmin" {
  provider  = snowflake.useradmin
  role_name = "SYSADMIN"
  user_name = "GITHUB_TEST_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_test_terraform_service_user]
}

resource "snowflake_grant_account_role" "github_test_terraform_useradmin" {
  provider  = snowflake.useradmin
  role_name = "USERADMIN"
  user_name = "GITHUB_TEST_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_test_terraform_service_user]
}

resource "snowflake_grant_account_role" "github_test_terraform_securityadmin" {
  provider  = snowflake.useradmin
  role_name = "SECURITYADMIN"
  user_name = "GITHUB_TEST_TERRAFORM_SVC"

  depends_on = [snowflake_execute.github_test_terraform_service_user]
}

resource "snowflake_execute" "github_test_dcm_service_user" {
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS GITHUB_TEST_DCM_SVC
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for the TEST-DCM environment (promote.yml)'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/snowflake-platform-tf@1351137236:environment:TEST-DCM'
      )
  SQL

  revert = "DROP USER IF EXISTS GITHUB_TEST_DCM_SVC"
}

# See github_dev_dcm_service_user_defaults' identical comment above for why this is a
# separate resource and why secondary roles matter here.
resource "snowflake_execute" "github_test_dcm_service_user_defaults" {
  provider = snowflake.useradmin

  execute = "ALTER USER GITHUB_TEST_DCM_SVC SET DEFAULT_ROLE = SYSADMIN, DEFAULT_SECONDARY_ROLES = ('ALL')"
  revert  = "ALTER USER GITHUB_TEST_DCM_SVC UNSET DEFAULT_ROLE, DEFAULT_SECONDARY_ROLES"

  depends_on = [snowflake_execute.github_test_dcm_service_user]
}

resource "snowflake_grant_account_role" "github_test_dcm_sysadmin" {
  provider  = snowflake.useradmin
  role_name = "SYSADMIN"
  user_name = "GITHUB_TEST_DCM_SVC"

  depends_on = [snowflake_execute.github_test_dcm_service_user]
}

resource "snowflake_grant_account_role" "github_test_dcm_useradmin" {
  provider  = snowflake.useradmin
  role_name = "USERADMIN"
  user_name = "GITHUB_TEST_DCM_SVC"

  depends_on = [snowflake_execute.github_test_dcm_service_user]
}

resource "snowflake_grant_account_role" "github_test_dcm_securityadmin" {
  provider  = snowflake.useradmin
  role_name = "SECURITYADMIN"
  user_name = "GITHUB_TEST_DCM_SVC"

  depends_on = [snowflake_execute.github_test_dcm_service_user]
}

# Per-domain dbt/ingestion identities (Repo 3's and Repo 2's OIDC users) have moved to
# domain_identities.tf — a for_each-driven pattern so onboarding domain #2+ is one new map
# entry, not a hand-written copy of these two resources. See that file and README.md's
# "Onboarding a New Domain" section.
