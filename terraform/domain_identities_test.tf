# TEST-tier mirror of domain_identities.tf -- the same domain_onboarding module,
# instantiated a second time, fed by every domain file in domains/test/ instead of
# domains/dev/. No module code changes were needed: it was already written generically
# against a `domains` map + a subject-claim prefix, so onboarding a domain to TEST is the
# same "add one new file" operation as onboarding it to DEV, just in the other folder.
#
# A domain can exist in DEV without existing in TEST yet (or vice versa) -- the two module
# instantiations are completely independent, each driven by its own folder.
locals {
  domains_test = merge([
    for f in fileset("${path.module}/domains/test", "*.yaml") :
    yamldecode(file("${path.module}/domains/test/${f}"))
  ]...)
}

module "domain_onboarding_test" {
  source = "./modules/domain_onboarding"
  count  = local.env == "TEST" ? 1 : 0

  providers = {
    snowflake.useradmin = snowflake.useradmin
  }

  domains                       = local.domains_test
  github_account_subject_prefix = "radhasgrl@43290275"
}

# Address rename caused by adding `count` above -- see domain_identities.tf's identical
# comment for why each for_each key needs its own moved block.
moved {
  from = module.domain_onboarding_test.snowflake_execute.domain_dbt_service_user["customer"]
  to   = module.domain_onboarding_test[0].snowflake_execute.domain_dbt_service_user["customer"]
}
moved {
  from = module.domain_onboarding_test.snowflake_execute.domain_ingest_service_user["customer"]
  to   = module.domain_onboarding_test[0].snowflake_execute.domain_ingest_service_user["customer"]
}
