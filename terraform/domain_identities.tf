# Per-domain OIDC identities (Repo 3's dbt identity, Repo 2's ingestion identity) are
# defined once in modules/domain_onboarding/ and instantiated here for every domain file in
# domains/dev/. Onboarding domain #2+ never touches this file, the module, or any other
# domain's file -- just add one new terraform/domains/dev/<domain>.yaml. See README.md's
# "Onboarding a New Domain" section.
#
# `moved` blocks below preserve Customer's two already-live identities exactly as-is (same
# username, same subject claim, same state) across this module refactor — Terraform state
# addresses change when a resource moves into a module, even though nothing about the
# actual Snowflake object changes. Verified via a real `terraform plan` showing "No
# changes" before this was merged.
locals {
  # One file per onboarded domain (see domains/dev/customer.yaml's header comment) --
  # merge() combines each file's single top-level {domain_name: {...}} entry into one map,
  # exactly matching the shape the module's `domains` variable already expected when it was
  # a single yamldecode(file("domains.yaml")) call. fileset()'s "*.yaml" pattern
  # deliberately excludes "*.yaml.example" template files (see procurement.yaml.example) --
  # they can never be accidentally merged in and go live.
  domains_dev = merge([
    for f in fileset("${path.module}/domains/dev", "*.yaml") :
    yamldecode(file("${path.module}/domains/dev/${f}"))
  ]...)
}

module "domain_onboarding" {
  source = "./modules/domain_onboarding"
  count  = local.env == "DEV" ? 1 : 0

  providers = {
    snowflake.useradmin = snowflake.useradmin
  }

  domains                       = local.domains_dev
  github_account_subject_prefix = "radhasgrl@43290275"
}

# Address rename caused by adding `count` above to this module block -- for_each resources
# inside a now-counted module gain a `[0].` segment in their state address too, so each
# for_each key needs its own moved block (Terraform doesn't support wildcarding this).
#
# Only one `moved` block per resource is allowed to target a given final address (Terraform
# rejects "ambiguous move statements" otherwise) -- so the original pre-module moved blocks
# (from the bare snowflake_execute.domain_*_service_user["customer"] addresses) have been
# dropped here rather than chained: that rename already completed in a prior apply, so
# those addresses no longer exist in state to match against.
moved {
  from = module.domain_onboarding.snowflake_execute.domain_dbt_service_user["customer"]
  to   = module.domain_onboarding[0].snowflake_execute.domain_dbt_service_user["customer"]
}
moved {
  from = module.domain_onboarding.snowflake_execute.domain_ingest_service_user["customer"]
  to   = module.domain_onboarding[0].snowflake_execute.domain_ingest_service_user["customer"]
}
