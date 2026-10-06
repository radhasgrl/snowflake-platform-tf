# Per-domain OIDC identities for Repo 3 (dbt) and Repo 2 (ingestion) — one entry in
# `local.domains` per onboarded domain, instead of hand-writing a new pair of resources
# every time. Onboarding domain #2+ is: add one more map entry here (see the commented-out
# `procurement` example below), plus the matching persona `oidc_user` values in that
# domain's dcm/domains/<domain>/manifest.yml. See README.md's "Onboarding a New Domain"
# section for the full procedure.
#
# `moved` blocks below preserve Customer's two already-live identities exactly as-is
# (same username, same subject claim, same state) — this refactor changes where the
# resources are defined, not what they create. Verified via a real `terraform plan`
# showing "No changes" before this was merged.
locals {
  domains = {
    customer = {
      # Kept as the original hand-written name (predates this domain-prefixed convention)
      # rather than renamed, to avoid a disruptive live identity rename for zero benefit.
      dbt_service_user       = "GITHUB_DEV_DBT_SVC"
      dbt_repo               = "customer-domain-dbt"
      dbt_repo_label         = "customer-domain-dbt (Repo 3)"
      dbt_repo_id            = "1405522917"
      dbt_github_environment = "DEV-dbt"

      ingest_service_user       = "GITHUB_DEV_INGEST_SVC"
      ingest_repo               = "data-ingestion-raw"
      ingest_repo_label         = "data-ingestion-raw (Repo 2)"
      ingest_repo_id            = "1405785591"
      ingest_github_environment = "DEV-Ingest"
    }

    # Domain #2 (Procurement) — template only, not yet onboarded. Uncomment once
    # procurement-domain-dbt exists for real and its numeric GitHub repo ID is known
    # (`gh api repos/radhasgrl/procurement-domain-dbt --jq .id`), and once a
    # `DEV-Ingest-Procurement` GitHub Environment has been created in data-ingestion-raw.
    # procurement = {
    #   dbt_service_user       = "GITHUB_DEV_PROCUREMENT_DBT_SVC"
    #   dbt_repo               = "procurement-domain-dbt"
    #   dbt_repo_label         = "procurement-domain-dbt (Repo 3b)"
    #   dbt_repo_id            = "<fill in once that repo exists>"
    #   dbt_github_environment = "DEV-dbt"
    #
    #   ingest_service_user       = "GITHUB_DEV_PROCUREMENT_INGEST_SVC"
    #   ingest_repo               = "data-ingestion-raw"
    #   ingest_repo_label         = "data-ingestion-raw (Repo 2)"
    #   ingest_repo_id            = "1405785591"
    #   ingest_github_environment = "DEV-Ingest-Procurement"
    # }
  }
}

# dbt identity — deliberately least-privilege, unlike the Terraform/DCM identities in
# oidc_service_user.tf. This user gets no admin role grants from Terraform at all; DCM
# grants it only the DEV_<DOMAIN>_DBT_SERVICE_PRSN persona role it actually needs (see
# ../dcm/_template/sources/definitions/grants.sql), demonstrating the tiered RBAC model in
# practice for a real downstream workload.
resource "snowflake_execute" "domain_dbt_service_user" {
  for_each = local.domains
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS ${each.value.dbt_service_user}
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for ${each.value.dbt_repo_label} — least-privilege, scoped to DEV_${upper(each.key)}_DBT_SERVICE_PRSN only'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/${each.value.dbt_repo}@${each.value.dbt_repo_id}:environment:${each.value.dbt_github_environment}'
      )
  SQL

  revert = "DROP USER IF EXISTS ${each.value.dbt_service_user}"
}

# Ingestion identity — same least-privilege pattern as the dbt identity above. DCM grants it
# DEV_<DOMAIN>_INGEST_SERVICE_PRSN only (see ../dcm/_template/sources/definitions/grants.sql),
# which in turn only carries DEV_<DOMAIN>_INGEST_FNCRL — enough to create/manage the storage
# integration, stage, file format and pipe, and load into that domain's RAW schema, nothing
# more. Repo 2 (data-ingestion-raw) stays one shared repo across domains; what's per-domain
# here is the GitHub Environment (and therefore the OIDC subject claim) within that repo.
resource "snowflake_execute" "domain_ingest_service_user" {
  for_each = local.domains
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS ${each.value.ingest_service_user}
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for ${each.value.ingest_repo_label} — least-privilege, scoped to DEV_${upper(each.key)}_INGEST_SERVICE_PRSN only'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:radhasgrl@43290275/${each.value.ingest_repo}@${each.value.ingest_repo_id}:environment:${each.value.ingest_github_environment}'
      )
  SQL

  revert = "DROP USER IF EXISTS ${each.value.ingest_service_user}"
}

moved {
  from = snowflake_execute.github_dev_dbt_service_user
  to   = snowflake_execute.domain_dbt_service_user["customer"]
}

moved {
  from = snowflake_execute.github_dev_ingest_service_user
  to   = snowflake_execute.domain_ingest_service_user["customer"]
}
