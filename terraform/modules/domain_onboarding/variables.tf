variable "domains" {
  description = "Map of domain name -> per-domain OIDC identity config. One entry per onboarded domain. Populated from ../../domains.yaml (the actual single source of truth) via yamldecode in the root module — never hand-edited here."
  type = map(object({
    dbt_service_user          = string
    dbt_repo                  = string
    dbt_repo_label             = string
    dbt_repo_id                = string
    dbt_github_environment     = string
    ingest_service_user        = string
    ingest_repo                = string
    ingest_repo_label          = string
    ingest_repo_id             = string
    ingest_github_environment  = string
  }))
}

variable "github_account_subject_prefix" {
  description = "GitHub org/user handle + numeric account ID used in every domain identity's OIDC subject claim, e.g. 'radhasgrl@43290275'."
  type        = string
}
