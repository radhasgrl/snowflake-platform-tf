# Snowflake DataOps Platform — Terraform + DCM (Repo 1 of 3)

A fully automated Snowflake DataOps platform managed through **Terraform** (account/platform
layer) and **Snowflake DCM** (database object layer), with CI/CD via GitHub Actions and
Terraform remote state in AWS S3. This is Repo 1 (`snowflake-platform-tf`) of a 3-repo client
demo; see `MDP_Platform_Engineering_CICD_IaC_Repo_Architecture_v0.1.md` for the full repo
structure (Repo 2: `data-ingestion-raw` — Snowpipe ingestion into RAW; Repo 3:
`customer-domain-dbt` — dbt transformations for the Customer domain).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Folder Structure](#folder-structure)
3. [Prerequisites](#prerequisites)
4. [One-Time Bootstrap (run once, by hand)](#one-time-bootstrap-run-once-by-hand)
5. [CI/CD Pipeline (ongoing, automated)](#cicd-pipeline-ongoing-automated)
6. [History — Terraform → DCM Cutover](#history--terraform--dcm-cutover)
7. [Verification Guide](#verification-guide)
8. [Key Decisions](#key-decisions)
9. [Known Limitations (demo scope)](#known-limitations-demo-scope)
10. [What's Next](#whats-next)

---

## Architecture Overview

This repo is **Repo 1 ("infra-snowflake") of a 3-repo platform**, pairing Terraform with
Snowflake's native DCM (Database Change Management), per the ownership split agreed with
the client in `MDP_Platform_Engineering_CICD_IaC_Repo_Architecture_v0.1.md` §2.2:

- **Terraform** owns the account/platform layer for the whole 3-repo platform, not just
  this repo: GitHub OIDC service identities for all 4 engines (`GITHUB_DEV_TERRAFORM_SVC`,
  `GITHUB_DEV_DCM_SVC`, `GITHUB_DEV_DBT_SVC` for Repo 3, `GITHUB_DEV_INGEST_SVC` for Repo 2),
  plus the AWS infrastructure Repo 2's ingestion pipeline runs against (S3 bucket + 2 IAM
  roles — `ingestion_aws_infra.tf`). Repo 2 itself contains ingestion **code** only, no
  infrastructure.
- **DCM** owns the database object layer: databases, schemas, warehouses, tiered RBAC roles,
  DB grants, and placeholder masking/row-access policies (`sources/definitions/*.sql`).

Identities are scoped to **GitHub Environments** (`DEV-Terraform`, `DEV-DCM`, and each
downstream repo's own environment — `DEV-Ingest` in Repo 2, `DEV-dbt` in Repo 3), not to a
branch or event — see the OIDC rationale comment at the top of `oidc_service_user.tf`. This
decouples environment from branch so a future trunk-based TEST/UAT/PROD promotion flow
doesn't require re-architecting the identity model.

```
Developer / PR
     │
     ▼
GitHub Actions (CI/CD) — single pipeline, two engines, sequential jobs
 ├── terraform-plan.yml   (PR)    → plan job → dcm-plan job (needs: plan)
 └── terraform-apply.yml  (push)  → apply job → dcm-deploy job (needs: apply)
          │
          ├── Terraform: fetches state from S3 (ap-southeast-2), authenticates to
          │   Snowflake via GitHub OIDC / WORKLOAD_IDENTITY (no stored keys) and to AWS via
          │   GitHub OIDC (no stored access keys) — creates/updates the 4 GitHub OIDC
          │   service users and the ingestion AWS infra (S3 bucket + 2 IAM roles)
          └── DCM (snow CLI): authenticates as GITHUB_DEV_DCM_SVC via the same OIDC pattern —
              creates/updates databases, schemas, warehouses, tiered RBAC roles
              (persona -> functional -> database/warehouse roles), grants, and placeholder
              masking/row-access policies

AWS (ap-southeast-2 / Sydney)
 ├── S3 bucket: snowflake-platform-tf-state-525218385225
 │    └── workload/dev/terraform.tfstate   ← encrypted, versioned (Terraform's state only — DCM has no separate state file, it diffs its SQL definitions against live Snowflake metadata)
 └── S3 bucket: data-ingestion-raw-525218385225 + 2 IAM roles   ← Repo 2's ingestion infra,
      provisioned here (ingestion_aws_infra.tf), used by Repo 2's pipeline and Snowflake's
      storage integration

Snowflake Account: xygpmhm-gq04150
 ├── GITHUB_DEV_TERRAFORM_SVC — Terraform identity (OIDC, GitHub Environment DEV-Terraform)
 ├── GITHUB_DEV_DCM_SVC       — DCM identity (OIDC, GitHub Environment DEV-DCM)
 ├── GITHUB_DEV_INGEST_SVC    — Repo 2's identity (OIDC, least-privilege, scoped to ingestion only)
 ├── GITHUB_DEV_DBT_SVC       — Repo 3's identity (OIDC, least-privilege, scoped to dbt only)
 └── DCM-managed objects: DEV_CUSTOMER_DB (Customer domain — RAW/STAGING/MARTS/SHARED
     schemas), shared warehouses, tiered RBAC roles (DEV_CUSTOMER_DATA_ENGINEER_PRSN,
     DEV_CUSTOMER_INGEST_FNCRL, DEV_CUSTOMER_DB.RAW_SCRL_R/_W, DEV_INGEST_WH_WHRL_U/_M/_O,
     etc. — see sources/definitions/roles.sql, database_roles.sql, grants.sql), grants, and
     placeholder masking/row-access policies
```

---

## Folder Structure

This repo contains **3 separate Terraform root modules** (each with its own state, its own
`variables.tf`/`outputs.tf`), plus the DCM project. This isn't duplication — each one solves
a distinct, one-time bootstrapping problem that has to exist before the next can run:

```
.
├── bootstrap/                        # One-time, human-applied — never touched by CI
│   ├── state-backend/                # Root module #1: creates the S3 bucket this repo's
│   │   │                             #   OWN remote backend needs to exist before it can
│   │   │                             #   be configured. Must run before anything else.
│   │   ├── main.tf, variables.tf, outputs.tf, versions.tf
│   │   └── terraform.tfstate         # LOCAL state (there's no backend yet to point to)
│   └── oidc-identity/                # Root module #2: creates the GitHub OIDC trust + CI
│       │                             #   IAM role that CI itself needs to authenticate to
│       │                             #   AWS. Can't bootstrap a pipeline's own permissions
│       │                             #   using that same pipeline.
│       ├── main.tf, variables.tf, outputs.tf, versions.tf
│       └── terraform.tfstate         # LOCAL state, same reason as above
│
├── .github/
│   ├── CODEOWNERS                   # *.tf -> platform; /sources/ -> data engineering
│   ├── pull_request_template.md     # Layer(s) Affected + validation checklist
│   └── workflows/
│       ├── terraform-plan.yml      # plan job (Terraform) + dcm-plan job (DCM, parallel), on Pull Requests
│       └── terraform-apply.yml     # apply job (Terraform) + dcm-deploy job (DCM, needs: apply), on merge to main
│
├── manifest.yml                      # DCM project manifest (targets, account identifier)
├── sources/
│   └── definitions/                 # DCM SQL definitions — database object layer
│       ├── databases.sql
│       ├── schemas.sql
│       ├── warehouses.sql
│       ├── roles.sql                # Tier 1 persona, Tier 2 functional, Tier 4 warehouse roles
│       ├── database_roles.sql       # Tier 3 database roles (schema-scoped read/write)
│       ├── grants.sql               # wires Tier 3/4 -> Tier 2 -> Tier 1
│       ├── masking.sql
│       ├── row_access.sql
│       └── tables.sql               # RAW.CUSTOMERS — loaded by Repo 2 (data-ingestion-raw), read by Repo 3 (customer-domain-dbt)
│
├── oidc_service_user.tf             # Root module #3 (below) — GitHub OIDC identities (Terraform, DCM, dbt, ingestion engines)
├── dcm_home.tf                      #   — DEV_ADMIN_DB.DCM, the DCM project's own home
├── ingestion_aws_infra.tf           #   — Repo 2's S3 bucket + IAM roles (provisioned here, not in Repo 2)
├── removed.tf                       #   — one-time `removed` blocks for the DCM cutover
├── context.tf, providers.tf, terraform.tf, variables.tf, outputs.tf
│                                     # Root module #3: the ONGOING, CI-managed Terraform —
│                                     #   everything above this line changes repeatedly and
│                                     #   is deployed by terraform-apply.yml on every merge
├── env/
│   ├── dev/ (backend.hcl, dev.tfvars)
│   ├── qa/                          # scaffolded, not yet wired into any pipeline
│   └── prod/                        # scaffolded, not yet wired into any pipeline
│
├── .gitignore
├── .terraform-version              # Pins Terraform to 1.16.0
└── README.md
```

**Quick way to tell the 3 roots apart**: `bootstrap/state-backend/` and `bootstrap/oidc-identity/`
are each applied **once, by hand**, with local state, and never run by CI. Everything at repo
root (`variables.tf`, `outputs.tf`, `*.tf`, `manifest.yml`, `sources/`) is the **ongoing** root
module — remote (S3) state, deployed automatically by CI on every merge to `main`.

---

## Prerequisites

| Tool | Version used | Notes |
|---|---|---|
| Terraform | 1.16.0 | Pinned via `.terraform-version` |
| Snowflake CLI (`snow`) | 3.25.0 | Used by DCM's `snow dcm` commands in CI |
| AWS CLI | 2.36.33 | Only needed for the one-time bootstrap steps below |
| GitHub CLI (`gh`) | 2.98.0 | Convenience for managing the repo/PRs |
| Git | 2.55.0 | |

No Terraform/Snowflake credentials need to be installed or configured locally for day-to-day
work — the CI/CD pipeline authenticates entirely via GitHub OIDC (see below). Local
Terraform commands against the repo-root module will not work outside real GitHub Actions
runtime, because the Snowflake provider's `WORKLOAD_IDENTITY` authenticator requires a
genuine GitHub Actions-issued OIDC token (see [Verification Guide](#verification-guide)).

---

## One-Time Bootstrap (run once, by hand)

Two small, independent Terraform root modules exist solely to solve a chicken-and-egg
problem: the ongoing, CI-managed root module needs an S3 backend and a CI identity to
exist before it can run — and neither of those can create themselves. Both are applied
**once, manually, with local state**, and are never touched by CI afterward.

### 1. `bootstrap/state-backend/` — creates the S3 bucket for Terraform's own remote state

```powershell
cd bootstrap/state-backend
terraform init
terraform apply -auto-approve
```

Creates the S3 bucket (`snowflake-platform-tf-state-525218385225`, versioned, AES256-encrypted,
public access blocked) that the repo-root module's backend (`env/dev/backend.hcl`) points at.

### 2. `bootstrap/oidc-identity/` — creates the GitHub OIDC trust + CI IAM role

```powershell
cd bootstrap/oidc-identity
terraform init
terraform apply -auto-approve
```

Creates the GitHub OIDC provider (one per AWS account) and the IAM role
(`snowflake-platform-tf-github-oidc`) that CI assumes via `AssumeRoleWithWebIdentity` — no
stored AWS access keys anywhere. Deliberately run by a human, not by CI, since CI can't
bootstrap its own permissions using the permissions it doesn't have yet.

### 3. Repo-root module — first apply, from CI

Once both bootstrap stacks exist, the repo-root module (everything else in this repo) is
initialized and applied **by CI**, not locally:

```powershell
# from the repo root — only works inside real GitHub Actions (see Prerequisites above)
terraform init -backend-config="env/dev/backend.hcl"
```

Its first successful `terraform apply` creates the GitHub OIDC service users
(`GITHUB_DEV_TERRAFORM_SVC`, `GITHUB_DEV_DCM_SVC`, `GITHUB_DEV_DBT_SVC`,
`GITHUB_DEV_INGEST_SVC` — see `oidc_service_user.tf`) that every subsequent CI run, and
Repos 2/3's pipelines, authenticate as.

### Mandatory notes
- Both bootstrap stacks' local state files (`bootstrap/*/terraform.tfstate`) are **not**
  pushed to git (covered by `.gitignore`) — they're the only authoritative record of what's
  been applied, so never delete them without first confirming nothing live depends on them.
- The S3 state bucket region is `ap-southeast-2` (Sydney), matching the client's AWS region.

---

## CI/CD Pipeline (ongoing, automated)

Authentication for **every** ongoing pipeline run — Terraform, DCM, and both downstream
repos — is GitHub OIDC workload identity. There are no stored Snowflake credentials
(no RSA keys, no passwords) and no stored long-lived AWS access keys anywhere in this
repo's CI: AWS access is via the OIDC IAM role created above; Snowflake access is via each
service user's `WORKLOAD_IDENTITY` auth, with the OIDC token fetched fresh inside each job.

| Workflow | Trigger | What it does |
|---|---|---|
| `.github/workflows/terraform-plan.yml` | Pull Request | `terraform fmt -check` + `validate` + `plan` (posted as PR comment) **and** `DCM Plan` (parallel job) |
| `.github/workflows/terraform-apply.yml` | Push to `main` | `Terraform Apply`, then `DCM Deploy` (`needs: apply` — DCM can't authenticate until Terraform's identities exist) |

```
Pull Request opened
  └─► terraform-plan.yml
        ├── plan job:     fetches Snowflake OIDC token → terraform plan → posts PR comment
        └── dcm-plan job: authenticates as GITHUB_DEV_DCM_SVC via OIDC → snow dcm plan → posts PR comment
             (both jobs run in parallel — plan is read-only in both engines)

PR merged to main
  └─► terraform-apply.yml
        ├── apply job:       terraform apply -auto-approve
        └── dcm-deploy job:  snow dcm deploy   (needs: apply — runs after, not parallel)
```

Both workflows run under GitHub Environments `DEV-Terraform` and `DEV-DCM` respectively —
visible under **Settings → Environments** in the GitHub UI, each scoped to its own OIDC
service-user subject claim.

### Mandatory notes
- `workflow_dispatch:` is enabled on both workflows for manual triggering without needing a
  PR or push.
- This is deliberately **DEV-only** today — see [Known Limitations](#known-limitations-demo-scope).

---

## History — Terraform → DCM Cutover

Databases, schemas, warehouses, functional roles, and DB grants were originally defined as
Terraform resources. They were migrated to DCM (`sources/definitions/*.sql`) per the
ownership split in `MDP_Platform_Engineering_CICD_IaC_Repo_Architecture_v0.1.md` §2.2, using
`removed` blocks (`removed.tf`) so Terraform forgot them without destroying the live
Snowflake objects — DCM adopted the exact same objects with no disruption. Names were also
changed from generic to Customer-domain-scoped at the same time:

| Old (Terraform, generic) | Current (DCM, Customer-domain) |
|---|---|
| `DEV_LANDING_DB` / `DEV_ANALYTICS_DB` / `DEV_COMMON_DB` | `DEV_CUSTOMER_DB` (single domain database) |
| `DEV_LANDING_DB.RAW` | `DEV_CUSTOMER_DB.RAW` |
| `DEV_ANALYTICS_DB.STAGING` | `DEV_CUSTOMER_DB.STAGING` |
| `DEV_ANALYTICS_DB.MARTS` | `DEV_CUSTOMER_DB.MARTS` |
| `DEV_COMMON_DB.UTILS` | `DEV_CUSTOMER_DB.SHARED` |
| `DEV_DATA_ENGINEER` / `_ANALYST` / `_CONSUMER` / `DEV_DBT_RUNNER` | Tiered: `DEV_CUSTOMER_*_PRSN` → `DEV_CUSTOMER_*_FNCRL` → `DEV_CUSTOMER_DB.*_SCRL_*` / `DEV_*_WH_WHRL_*` |

Warehouses (`DEV_INGEST_WH`/`DEV_TRANSFORM_WH`/`DEV_REPORTING_WH`) were unchanged by this
move — they remain account-level shared compute, not domain-prefixed. The current, live
definitions for all of the above are `sources/definitions/databases.sql`, `schemas.sql`,
`warehouses.sql`, `roles.sql`, `database_roles.sql`, and `grants.sql` — treat those files,
not this table, as the source of truth going forward.

---

## Verification Guide

### On Snowflake

Log in to `https://xygpmhm-gq04150.snowflakecomputing.com` as `RADHAASINGH` and run:

```sql
-- Verify Customer domain database (DCM-managed, see sources/definitions/)
SHOW DATABASES LIKE '%DEV%';
-- Expect: DEV_CUSTOMER_DB, DEV_ADMIN_DB

-- Verify schemas
SHOW SCHEMAS IN DATABASE DEV_CUSTOMER_DB;    -- Expect: RAW, STAGING, MARTS, SHARED

-- Verify warehouses
SHOW WAREHOUSES LIKE '%DEV%';
-- Expect: DEV_INGEST_WH, DEV_TRANSFORM_WH, DEV_REPORTING_WH
```

### On AWS

```powershell
# Verify S3 bucket exists in Sydney
aws s3api head-bucket --bucket snowflake-platform-tf-state-525218385225 --region ap-southeast-2

# Verify versioning is enabled
aws s3api get-bucket-versioning --bucket snowflake-platform-tf-state-525218385225 --region ap-southeast-2
# Expected: { "Status": "Enabled" }

# Verify state file is present
aws s3 ls s3://snowflake-platform-tf-state-525218385225/workload/dev/ --region ap-southeast-2
# Expected: terraform.tfstate

# Verify encryption
aws s3api get-bucket-encryption --bucket snowflake-platform-tf-state-525218385225 --region ap-southeast-2
# Expected: AES256

# Verify no public access
aws s3api get-public-access-block --bucket snowflake-platform-tf-state-525218385225 --region ap-southeast-2
# Expected: all four values = true
```

### On GitHub

```powershell
# Verify both environments exist, each with its own OIDC-scoped identity
gh api repos/radhasgrl/snowflake-platform-tf/environments --jq '.environments[].name'
# Expected: DEV-Terraform, DEV-DCM

# Verify latest pipeline runs all passed
gh run list --repo radhasgrl/snowflake-platform-tf --limit 5
# Expected: all rows show success

# Manually trigger a plan run (no PR needed)
gh workflow run terraform-plan.yml --repo radhasgrl/snowflake-platform-tf
gh run list --repo radhasgrl/snowflake-platform-tf --limit 3
```

### Local Terraform verification — important limitation

`terraform plan`/`apply`/`import` against the **repo-root module** cannot be run locally —
the Snowflake provider's `WORKLOAD_IDENTITY` authenticator requires a genuine GitHub
Actions-issued OIDC token (fetched via `ACTIONS_ID_TOKEN_REQUEST_TOKEN`), which only exists
inside real GitHub Actions runtime. This blocks *every* command against that module, not
just ones touching Snowflake resources, since Terraform configures all declared providers
before running any operation. To verify the root module, use `workflow_dispatch` to run
`terraform-plan.yml`/`terraform-apply.yml` for real, or read the PR comment a real CI run
posts. The two `bootstrap/` stacks are the exception — they only use the AWS provider, so
`terraform plan` against them works locally with valid AWS credentials.

---

## Key Decisions

| Decision | Choice | Reason |
|---|---|---|
| IaC tool | Terraform 1.16.0 | Client requirement; not OpenTofu |
| Snowflake auth | GitHub OIDC workload identity (`WORKLOAD_IDENTITY` authenticator) | No stored keys or passwords anywhere — short-lived tokens fetched fresh per CI run |
| AWS auth | GitHub OIDC (`AssumeRoleWithWebIdentity`) | Same reasoning — no stored AWS access keys in CI |
| State storage | AWS S3 + `use_lockfile` | Secure, versioned, native S3 locking (Terraform ≥ 1.10) |
| State region | `ap-southeast-2` (Sydney) | Aligns with client's AWS region |
| Environment strategy | Single account, env-prefix naming | `DEV_`, `QA_`, `PROD_` prefixes on all objects — only `DEV_` is wired up today |
| Snowflake provider | `snowflakedb/snowflake ~> 2.0` | Resolved to v2.21.0 |
| CI/CD | GitHub Actions | Already used for source control |

---

## Known Limitations (demo scope)

Disclosed deliberately, not hidden — these are the honest boundaries of what this demo
build covers:

- **DEV-only.** `env/qa/` and `env/prod/` tfvars/backend configs are scaffolded but not
  wired into any pipeline. Extending to QA/PROD is a repeatable pattern (new GitHub
  Environment pair, new OIDC service-user pair, new DCM manifest target) — not a redesign.
- **Masking/row-access policies are inert placeholders** (`sources/definitions/masking.sql`,
  `row_access.sql`) — pass-through/allow-all, pending client-confirmed PII/RLS rules.
- **No human-identity path.** Every identity in this repo is a service account (OIDC
  workload identity); there's no SSO/SCIM/MFA/network-policy story modeled here.
- A legacy, currently-unused DynamoDB table (`bootstrap/state-backend/main.tf`) is still
  provisioned from an earlier design that predates `use_lockfile`-based S3 locking — a
  candidate for removal, not a functional dependency.

---

## What's Next

| Item | Scope | Status |
|---|---|---|
| RBAC | Tiered persona → functional → database/warehouse roles | ✅ Implemented (`sources/definitions/roles.sql`, `database_roles.sql`, `grants.sql`) |
| Masking / row-access policies | PII/RLS enforcement | 🟡 Scaffolded as placeholders; real rules pending client input |
| dbt integration | Repo 3 (`customer-domain-dbt`) — staging → marts | ✅ Implemented and verified end-to-end |
| Ingestion | Repo 2 (`data-ingestion-raw`) — Snowpipe S3 → RAW | ✅ Implemented and verified end-to-end |
| QA / PROD environments | Second+ environment tier, promotion flow | ⬜ Not started — pattern documented, not built |
| Schema migrations tooling (schemachange/Flyway) | Versioned migration history beyond DCM's own diffing | ⬜ Not started |
