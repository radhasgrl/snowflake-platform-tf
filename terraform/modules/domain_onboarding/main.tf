# Per-domain OIDC identities for Repo 3 (dbt) and Repo 2 (ingestion) — one module
# instantiation covers every onboarded domain via `for_each`, driven entirely by the
# `domains` input variable (populated by merging every ../../domains/<tier>/*.yaml file,
# the actual single source of truth). Onboarding domain #2+ is: add one new
# ../../domains/dev/<domain>.yaml file — nothing in this
# module ever changes.

terraform {
  required_providers {
    snowflake = {
      source                = "snowflakedb/snowflake"
      configuration_aliases = [snowflake.useradmin]
    }
  }
}

# dbt identity — deliberately least-privilege, unlike the Terraform/DCM identities in
# ../../oidc_service_user.tf. This user gets no admin role grants from Terraform at all;
# DCM grants it only the DEV_<DOMAIN>_DBT_SERVICE_PRSN persona role it actually needs (see
# ../../../dcm/sources/definitions/grants.sql), demonstrating the tiered RBAC
# model in practice for a real downstream workload.
resource "snowflake_execute" "domain_dbt_service_user" {
  for_each = var.domains
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS ${each.value.dbt_service_user}
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for ${each.value.dbt_repo_label} — least-privilege, scoped to DEV_${upper(each.key)}_DBT_SERVICE_PRSN only'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:${var.github_account_subject_prefix}/${each.value.dbt_repo}@${each.value.dbt_repo_id}:environment:${each.value.dbt_github_environment}'
      )
  SQL

  revert = "DROP USER IF EXISTS ${each.value.dbt_service_user}"
}

# Ingestion identity — same least-privilege pattern as the dbt identity above. DCM grants it
# DEV_<DOMAIN>_INGEST_SERVICE_PRSN only (see
# ../../../dcm/sources/definitions/grants.sql), which in turn only carries
# DEV_<DOMAIN>_INGEST_FNCRL — enough to create/manage the storage integration, stage, file
# format and pipe, and load into that domain's RAW schema, nothing more. Repo 2
# (data-ingestion-raw) stays one shared repo across domains; what's per-domain here is the
# GitHub Environment (and therefore the OIDC subject claim) within that repo.
resource "snowflake_execute" "domain_ingest_service_user" {
  for_each = var.domains
  provider = snowflake.useradmin

  execute = <<-SQL
    CREATE USER IF NOT EXISTS ${each.value.ingest_service_user}
      TYPE = SERVICE
      COMMENT = 'GitHub Actions OIDC identity for ${each.value.ingest_repo_label} — least-privilege, scoped to DEV_${upper(each.key)}_INGEST_SERVICE_PRSN only'
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:${var.github_account_subject_prefix}/${each.value.ingest_repo}@${each.value.ingest_repo_id}:environment:${each.value.ingest_github_environment}'
      )
  SQL

  revert = "DROP USER IF EXISTS ${each.value.ingest_service_user}"
}
