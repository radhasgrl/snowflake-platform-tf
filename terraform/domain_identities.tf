# Per-domain OIDC identities (Repo 3's dbt identity, Repo 2's ingestion identity) are
# defined once in modules/domain_onboarding/ and instantiated here for every domain listed
# in domains.yaml. Onboarding domain #2+ never touches this file or the module — just add
# one more entry to domains.yaml. See README.md's "Onboarding a New Domain" section.
#
# `moved` blocks below preserve Customer's two already-live identities exactly as-is (same
# username, same subject claim, same state) across this module refactor — Terraform state
# addresses change when a resource moves into a module, even though nothing about the
# actual Snowflake object changes. Verified via a real `terraform plan` showing "No
# changes" before this was merged.
module "domain_onboarding" {
  source = "./modules/domain_onboarding"

  providers = {
    snowflake.useradmin = snowflake.useradmin
  }

  domains                       = yamldecode(file("${path.module}/domains.yaml"))
  github_account_subject_prefix = "radhasgrl@43290275"
}

moved {
  from = snowflake_execute.domain_dbt_service_user["customer"]
  to   = module.domain_onboarding.snowflake_execute.domain_dbt_service_user["customer"]
}

moved {
  from = snowflake_execute.domain_ingest_service_user["customer"]
  to   = module.domain_onboarding.snowflake_execute.domain_ingest_service_user["customer"]
}
