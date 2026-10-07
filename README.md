# Snowflake DataOps Platform — Terraform + DCM (Repo 1 of 3)

A fully automated Snowflake DataOps platform managed through **Terraform** (account/platform
layer, folder: `terraform/`) and **Snowflake DCM** (database object layer, folder: `dcm/`),
with CI/CD via GitHub Actions and Terraform remote state in AWS S3. This is Repo 1
(`snowflake-platform-tf`) of a 3-repo client demo — Repo 2: `data-ingestion-raw` (Snowpipe
ingestion into RAW); Repo 3: `customer-domain-dbt` (dbt transformations for the Customer
domain). **This repo is the sole provisioner of resources for all 3 repos** — Repos 2 and 3
contain only code (SQL / dbt models) that runs against identities and objects this repo
creates; see [How Repo 1 Feeds Repos 2 & 3](#how-repo-1-feeds-repos-2--3) below.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Folder Structure](#folder-structure)
3. [How Repo 1 Feeds Repos 2 & 3](#how-repo-1-feeds-repos-2--3)
4. [Prerequisites](#prerequisites)
5. [One-Time Bootstrap (run once, by hand)](#one-time-bootstrap-run-once-by-hand)
6. [CI/CD Pipeline (ongoing, automated)](#cicd-pipeline-ongoing-automated)
7. [History — Terraform → DCM Cutover](#history--terraform--dcm-cutover)
8. [Verification Guide](#verification-guide)
9. [Key Decisions](#key-decisions)
10. [Known Limitations (demo scope)](#known-limitations-demo-scope)
11. [What's Next](#whats-next)

---

## Architecture Overview

This repo is **Repo 1 of a 3-repo platform**, pairing Terraform with Snowflake's native DCM
(Database Change Management):

- **Terraform** (`terraform/`) owns the account/platform layer for the whole 3-repo
  platform, not just this repo: GitHub OIDC service identities for all 4 engines
  (`GITHUB_DEV_TERRAFORM_SVC`, `GITHUB_DEV_DCM_SVC`, `GITHUB_DEV_DBT_SVC` for Repo 3,
  `GITHUB_DEV_INGEST_SVC` for Repo 2), plus the AWS infrastructure Repo 2's ingestion
  pipeline runs against (S3 bucket + 2 IAM roles — `terraform/ingestion_aws_infra.tf`).
  Repo 2 itself contains ingestion **code** only, no infrastructure.
- **DCM** (`dcm/`) owns the database object layer: databases, schemas, warehouses, tiered
  RBAC roles, DB grants, and placeholder masking/row-access policies
  (`dcm/_template/sources/definitions/*.sql`).

Identities are scoped to **GitHub Environments** (`DEV-Terraform`, `DEV-DCM`, and each
downstream repo's own environment — `DEV-Ingest` in Repo 2, `DEV-dbt` in Repo 3), not to a
branch or event — see the OIDC rationale comment at the top of
`terraform/oidc_service_user.tf`. This decouples environment from branch so a future
trunk-based TEST/UAT/PROD promotion flow doesn't require re-architecting the identity model.

```
Developer / PR
     │
     ▼
GitHub Actions (CI/CD) — 2 independent pipelines, one per engine, each its own files
 ├── terraform-plan.yml   (PR)    → plan job (terraform/)
 ├── terraform-apply.yml  (push)  → apply job (terraform/)
 ├── dcm-plan.yml         (PR)    → account-plan + detect-domains + dcm-plan jobs (dcm/)
 └── dcm-deploy.yml       (push)  → account-deploy + detect-domains + dcm-deploy jobs (dcm/)
          │
          ├── Terraform: fetches state from S3 (ap-southeast-2), authenticates to
          │   Snowflake via GitHub OIDC / WORKLOAD_IDENTITY (no stored keys) and to AWS via
          │   GitHub OIDC (no stored access keys) — creates/updates the 4 GitHub OIDC
          │   service users and the ingestion AWS infra (S3 bucket + 2 IAM roles)
          └── DCM (snow CLI): authenticates as GITHUB_DEV_DCM_SVC via the same OIDC pattern —
              creates/updates databases, schemas, warehouses, tiered RBAC roles
              (persona -> functional -> database/warehouse roles), grants, and placeholder
              masking/row-access policies. Each DCM job verifies its own identity exists
              before proceeding (see "CI/CD Pipeline" below) — DCM and Terraform are fully
              independent pipelines now, not sequenced via a same-file `needs:`.

AWS (ap-southeast-2 / Sydney)
 ├── S3 bucket: snowflake-platform-tf-state-525218385225
 │    └── workload/dev/terraform.tfstate   ← encrypted, versioned (Terraform's state only — DCM has no separate state file, it diffs its SQL definitions against live Snowflake metadata)
 └── S3 bucket: data-ingestion-raw-525218385225 + 2 IAM roles   ← Repo 2's ingestion infra,
      provisioned here (terraform/ingestion_aws_infra.tf), used by Repo 2's pipeline and
      Snowflake's storage integration

Snowflake Account: xygpmhm-gq04150
 ├── GITHUB_DEV_TERRAFORM_SVC — Terraform identity (OIDC, GitHub Environment DEV-Terraform)
 ├── GITHUB_DEV_DCM_SVC       — DCM identity (OIDC, GitHub Environment DEV-DCM)
 ├── GITHUB_DEV_INGEST_SVC    — Repo 2's identity (OIDC, least-privilege, scoped to ingestion only)
 ├── GITHUB_DEV_DBT_SVC       — Repo 3's identity (OIDC, least-privilege, scoped to dbt only)
 └── DCM-managed objects: DEV_CUSTOMER_DB (Customer domain — RAW/STAGING/MARTS/SHARED
     schemas), this domain's own dedicated warehouses, tiered RBAC roles
     (DEV_CUSTOMER_DATA_ENGINEER_PRSN, DEV_CUSTOMER_INGEST_FNCRL, DEV_CUSTOMER_DB.RAW_SCRL_R/_W,
     DEV_CUSTOMER_INGEST_WH_WHRL_U/_M/_O, etc. — see dcm/_template/sources/definitions/roles.sql,
     database_roles.sql, grants.sql, warehouses.sql), grants, and placeholder
     masking/row-access policies
```


---

## Folder Structure

This repo is split into exactly 2 top-level folders by *which engine owns the resource* —
`terraform/` for everything Terraform provisions, `dcm/` for everything DCM provisions.
Nothing Terraform-related lives outside `terraform/`; nothing DCM-related lives outside
`dcm/`.

```
.
├── terraform/
│   ├── bootstrap/                    # One-time, human-applied — never touched by CI
│   │   ├── state-backend/            # Root module #1: creates the S3 bucket this repo's
│   │   │   │                         #   OWN remote backend needs to exist before it can
│   │   │   │                         #   be configured. Must run before anything else.
│   │   │   └── main.tf, variables.tf, outputs.tf, versions.tf, terraform.tfstate (LOCAL)
│   │   └── oidc-identity/            # Root module #2: creates the GitHub OIDC trust + CI
│   │       │                         #   IAM role that CI itself needs to authenticate to
│   │       │                         #   AWS. Can't bootstrap a pipeline's own permissions
│   │       │                         #   using that same pipeline.
│   │       └── main.tf, variables.tf, outputs.tf, versions.tf, terraform.tfstate (LOCAL)
│   │
│   ├── env/
│   │   ├── dev/ (backend.hcl, dev.tfvars)
│   │   ├── qa/                       # scaffolded, not yet wired into any pipeline
│   │   └── prod/                     # scaffolded, not yet wired into any pipeline
│   │
│   ├── oidc_service_user.tf          # Platform-level OIDC identities (Terraform + DCM engines)
│   ├── domain_identities.tf          # Instantiates modules/domain_onboarding/ for every
│   │                                 #   domain in domains.yaml
│   ├── domains.yaml                  # Single source of truth — onboarding a domain = one
│   │                                 #   new top-level entry here, nothing else
│   ├── modules/
│   │   └── domain_onboarding/        # Reusable module: per-domain dbt + ingest OIDC
│   │       ├── main.tf               #   identity resources, for_each-driven over
│   │       └── variables.tf          #   var.domains (populated from domains.yaml)
│   ├── dcm_home.tf                   # DEV_ADMIN_DB.DCM, the DCM project's own home
│   ├── ingestion_aws_infra.tf        # Repo 2's S3 bucket + IAM roles (provisioned here, not in Repo 2)
│   ├── removed.tf                    # one-time `removed` blocks for the DCM cutover
│   ├── context.tf, providers.tf, terraform.tf, variables.tf, outputs.tf
│   │                                 # Root module #3: the ONGOING, CI-managed Terraform —
│   │                                 #   deployed by terraform-apply.yml on every merge
│   └── .terraform-version            # Pins Terraform to 1.16.0
│
├── dcm/
│   ├── account/                       # Account-level DCM project — genuinely
│   │   ├── manifest.yml               #   platform-wide (one CI/tooling warehouse),
│   │   └── sources/definitions/       #   hand-written (never repeated per domain, so no
│   │       └── warehouses.sql         #   templating needed) — matches the infra-platform
│   │                                 #   reference's own account-level dcm/manifest.yml.
│   ├── _template/                    # THE canonical, domain-agnostic template — never
│   │   ├── sources/                  #   duplicated per domain. Fully Jinja2-templated.
│   │   │   ├── definitions/
│   │   │   │   ├── databases.sql
│   │   │   │   ├── schemas.sql
│   │   │   │   ├── warehouses.sql    # per-domain workload warehouses + Tier 4 roles
│   │   │   │   ├── roles.sql         # Tier 1 persona, Tier 2 functional
│   │   │   │   ├── database_roles.sql # Tier 3 database roles (schema-scoped read/write)
│   │   │   │   ├── grants.sql        # wires Tier 3/4 -> Tier 2 -> Tier 1
│   │   │   │   ├── masking.sql
│   │   │   │   ├── row_access.sql
│   │   │   │   └── tables.sql        # RAW.CUSTOMERS — loaded by Repo 2, read by Repo 3
│   │   │   └── macros/
│   │   │       └── domain_macros.sql # reusable naming/role/grant macros, shared by every domain
│   │   └── _validate_render.py       # offline, Snowflake-free check that a domain's
│   │                                 #   manifest.yml renders cleanly against this template
│   ├── domains/
│   │   ├── customer/
│   │   │   ├── manifest.yml          # Customer's own config — schemas, personas, functional
│   │   │   │                         #   roles, warehouses, tables. Zero SQL. LIVE/deployed.
│   │   │   └── sources/              # SYNTHESIZED by sync-domain.sh from _template/ —
│   │   │                             #   gitignored, never committed, regenerated every run
│   │   └── procurement/
│   │       └── manifest.yml          # Domain #2 TEMPLATE — proves the pattern generalizes
│   │                                 #   beyond Customer. NOT wired into any workflow, NOT
│   │                                 #   deployed — see "Onboarding a New Domain" below.
│   ├── active_domains.json           # The "go live" switch — only domains listed here ever
│   │                                 #   get a dcm-plan/dcm-deploy CI job (Customer only
│   │                                 #   today; Procurement is deliberately absent)
│   ├── detect-changed-domains.sh     # diffs changed files -> which active domains' jobs
│   │                                 #   should run this CI run (keeps CI load flat at scale)
│   └── sync-domain.sh                # copies _template/ into dcm/domains/<domain>/sources/
│                                     #   immediately before every snow dcm plan/deploy
│
├── .github/
│   ├── CODEOWNERS                    # /terraform/ + terraform-*.yml -> platform;
│   │                                 #   /dcm/ + dcm-*.yml -> data engineering
│   ├── pull_request_template.md      # Layer(s) Affected + validation checklist
│   └── workflows/
│       ├── terraform-plan.yml        # Terraform-only: fmt/validate/plan, on PRs touching terraform/**
│       ├── terraform-apply.yml       # Terraform-only: apply, on push to main touching terraform/**
│       ├── dcm-plan.yml              # DCM-only: account-plan + detect-domains + dcm-plan
│       │                             #   matrix job(s), on PRs touching dcm/**
│       ├── dcm-deploy.yml            # DCM-only: account-deploy + detect-domains + dcm-deploy
│       │                             #   matrix job(s), on push to main touching dcm/**
│       └── dbt-build-reusable.yml    # workflow_call — centrally-maintained dbt build logic
│                                     #   called by every per-domain dbt repo (Repo 3+)
│
├── .gitignore
└── README.md
```

**Quick way to tell the 3 Terraform roots apart**: `terraform/bootstrap/state-backend/` and
`terraform/bootstrap/oidc-identity/` are each applied **once, by hand**, with local state,
and never run by CI. Everything else in `terraform/` is the **ongoing** root module —
remote (S3) state, deployed automatically by CI on every merge to `main`.

---

## How Repo 1 Feeds Repos 2 & 3

Repo 1 is the **only** repo of the 3 that provisions resources. Repos 2 and 3 never create
their own Snowflake users, roles, warehouses, or AWS infrastructure — they authenticate as
an identity Repo 1 already created, scoped to exactly the role Repo 1 granted, and run only
application-level code (SQL / dbt models) against objects Repo 1 already defined. If Repo 1
hasn't run yet, Repo 2/3's pipelines fail cleanly (user or role doesn't exist) rather than
silently drifting.

| What Repo 1 provisions (via `terraform/` + `dcm/`) | Consumed by |
|---|---|
| `GITHUB_DEV_INGEST_SVC` identity + `DEV_CUSTOMER_INGEST_SERVICE_PRSN` role | Repo 2 (`data-ingestion-raw`) authenticates as this identity to deploy/run its Snowpipe SQL |
| `GITHUB_DEV_DBT_SVC` identity + `DEV_CUSTOMER_DBT_SERVICE_PRSN` role | Repo 3 (`customer-domain-dbt`) authenticates as this identity to run `dbt build` |
| `DEV_CUSTOMER_DB.RAW.CUSTOMERS` table (`dcm/_template/sources/definitions/tables.sql`) | Repo 2 loads into it; Repo 3 reads it as a dbt source |
| `DEV_CUSTOMER_DB.STAGING` / `.MARTS` schemas, `DEV_CUSTOMER_TRANSFORM_WH` warehouse | Repo 3 builds its dbt models into these |
| S3 bucket `data-ingestion-raw-525218385225` + 2 IAM roles (`terraform/ingestion_aws_infra.tf`) | Repo 2's CI assumes one role to manage the bucket; Snowflake's storage integration assumes the other to read it |
| `.github/workflows/dbt-build-reusable.yml` (`workflow_call`) | Every per-domain dbt repo (Repo 3 and its future siblings) calls this instead of defining its own dbt build logic — see "Centrally-maintained CI for Repo 3" below |

**What Repo 2/3 developers can do independently** (no Repo 1 PR needed): add a new
pipe/stage reading from the same bucket into the same existing table (Repo 2); add a new
dbt model reading existing sources into the existing `STAGING`/`MARTS` schemas (Repo 3).

**What requires a Repo 1 PR first**: a new source needing its own new RAW table/schema, a
new AWS bucket or broader privileges, a new domain database, or standing up a brand-new
downstream repo for a new domain team — anything that doesn't exist yet in Repo 1's
Terraform/DCM definitions.

### Centrally-maintained CI for Repo 3

Repo 3 is **one GitHub repo per domain** — `customer-domain-dbt` today, a future
`procurement-domain-dbt` or similar later. Rather than each domain repo hand-maintaining
its own full copy of the dbt build pipeline (checkout, install dbt-snowflake, fetch an
OIDC token, configure `profiles.yml`, run `dbt build`, post a PR comment, clean up ephemeral
PR schemas), every domain repo's `.github/workflows/dbt-ci.yml` is a **thin wrapper** that
calls `.github/workflows/dbt-build-reusable.yml` in *this* repo:

```yaml
jobs:
  dbt:
    uses: radhasgrl/snowflake-platform-tf/.github/workflows/dbt-build-reusable.yml@main
    with:
      domain: customer
      dbt_project_name: customer_domain
      account: xygpmhm-gq04150
      user: GITHUB_DEV_DBT_SVC
      role: DEV_CUSTOMER_DBT_SERVICE_PRSN
      warehouse: DEV_CUSTOMER_TRANSFORM_WH
      database: DEV_CUSTOMER_DB
      schema: STAGING
      github_environment: DEV-dbt
```

Fixing a bug or adding a step to the dbt build process means editing
`dbt-build-reusable.yml` **once, here** — every domain repo referencing `@main` picks up
the change on its next run, with no PR needed in each individual domain repo. A domain
repo's own `dbt-ci.yml` only ever needs to change its own `with:` values (e.g. a new
domain's database/warehouse/role names), never the build logic itself.

---

## Prerequisites

| Tool | Version used | Notes |
|---|---|---|
| Terraform | 1.16.0 | Pinned via `terraform/.terraform-version` |
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

### 1. `terraform/bootstrap/state-backend/` — creates the S3 bucket for Terraform's own remote state

```powershell
cd terraform/bootstrap/state-backend
terraform init
terraform apply -auto-approve
```

Creates the S3 bucket (`snowflake-platform-tf-state-525218385225`, versioned, AES256-encrypted,
public access blocked) that the repo-root module's backend (`terraform/env/dev/backend.hcl`) points at.

### 2. `terraform/bootstrap/oidc-identity/` — creates the GitHub OIDC trust + CI IAM role

```powershell
cd terraform/bootstrap/oidc-identity
terraform init
terraform apply -auto-approve
```

Creates the GitHub OIDC provider (one per AWS account) and the IAM role
(`snowflake-platform-tf-github-oidc`) that CI assumes via `AssumeRoleWithWebIdentity` — no
stored AWS access keys anywhere. Deliberately run by a human, not by CI, since CI can't
bootstrap its own permissions using the permissions it doesn't have yet.

### 3. Repo-root module (`terraform/`) — first apply, from CI

Once both bootstrap stacks exist, the repo-root module (`terraform/`, minus `bootstrap/`) is
initialized and applied **by CI**, not locally:

```powershell
# from terraform/ — only works inside real GitHub Actions (see Prerequisites above)
terraform init -backend-config="env/dev/backend.hcl"
```

Its first successful `terraform apply` creates the GitHub OIDC service users
(`GITHUB_DEV_TERRAFORM_SVC`, `GITHUB_DEV_DCM_SVC` in `terraform/oidc_service_user.tf`;
`GITHUB_DEV_DBT_SVC`, `GITHUB_DEV_INGEST_SVC` via `modules/domain_onboarding/`, configured
in `terraform/domains.yaml`) that every subsequent CI run, and Repos 2/3's pipelines,
authenticate as.

### Mandatory notes
- Both bootstrap stacks' local state files (`terraform/bootstrap/*/terraform.tfstate`) are
  **not** pushed to git (covered by `.gitignore`) — they're the only authoritative record of
  what's been applied, so never delete them without first confirming nothing live depends
  on them.
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
| `.github/workflows/terraform-plan.yml` | Pull Request touching `terraform/**` | `terraform fmt -check` + `validate` + `plan` (posted as PR comment) |
| `.github/workflows/terraform-apply.yml` | Push to `main` touching `terraform/**` | `Terraform Apply` |
| `.github/workflows/dcm-plan.yml` | Pull Request touching `dcm/**` | `DCM Plan (account)` + `DCM Plan (<domain>)` matrix (posted as PR comments) |
| `.github/workflows/dcm-deploy.yml` | Push to `main` touching `dcm/**` | `DCM Deploy (account)` + `DCM Deploy (<domain>)` matrix |

**Terraform and DCM are two fully independent pipelines**, not one combined pipeline —
deliberately split into separate files (see "Why Terraform and DCM are separate pipelines"
below). A PR touching only `dcm/` never triggers a Terraform plan, and vice versa; each
tool's CI load, PR-check naming, and CODEOWNERS routing stay scoped to what actually
changed.

```
Pull Request touching terraform/**
  └─► terraform-plan.yml
        └── plan job: fetches Snowflake OIDC token → terraform plan → posts PR comment

Pull Request touching dcm/**
  └─► dcm-plan.yml
        ├── account-plan job:   snow dcm plan --target ACCOUNT --from account → posts PR comment
        │                       (always runs — one account-level project, not domain-gated)
        ├── detect-domains job: diffs changed files against dcm/active_domains.json
        └── dcm-plan job(s):    one per changed active domain (matrix) → snow dcm plan → posts PR comment
             (account-plan/detect-domains run in parallel; dcm-plan needs detect-domains)

Push to main touching terraform/**
  └─► terraform-apply.yml
        └── apply job: terraform apply -auto-approve

Push to main touching dcm/**
  └─► dcm-deploy.yml
        ├── account-deploy job: snow dcm deploy --target ACCOUNT --from account
        ├── detect-domains job: same diff logic as above
        └── dcm-deploy job(s):  one per changed active domain (matrix) → snow dcm deploy
```

A domain only ever gets a `dcm-plan`/`dcm-deploy` job if (a) its own `dcm/domains/<domain>/`
files changed, or (b) the shared `dcm/_template/` changed (which affects every domain), AND
(c) it's listed in `dcm/active_domains.json`. This is what keeps CI load flat as domains
scale into the hundreds — a PR touching one domain's manifest never replans/redeploys every
other domain too. See `dcm/detect-changed-domains.sh` and README's "Onboarding a New Domain"
section.

Each workflow runs under its own GitHub Environment (`DEV-Terraform` or `DEV-DCM`) —
visible under **Settings → Environments** in the GitHub UI, each scoped to its own OIDC
service-user subject claim.

### Why Terraform and DCM are separate pipelines

They used to live in two combined files (`terraform-plan.yml`/`terraform-apply.yml` also
contained the DCM jobs). Split apart because:

- **Misleading naming**: a file named `terraform-plan.yml` containing jobs called
  `DCM Plan (account)` is confusing on its own.
- **CODEOWNERS can't route by concern while files are shared** — `/terraform/` and `/dcm/`
  are owned by different teams at the source level; the workflow files now match that.
- **Wasted CI**: the combined files triggered on `paths: [terraform/**, dcm/**]` (an OR) —
  a DCM-only PR still ran a real `terraform plan` unconditionally. Each file's own path
  filter now scopes it to only the tool that actually changed.
- **Blast radius**: a typo in one tool's job definition can no longer affect the other's
  file/PR/review.

**The one real engineering wrinkle**: DCM authenticates as `GITHUB_DEV_DCM_SVC`, an
identity *Terraform itself creates*. In the combined file, `dcm-deploy` had `needs: apply`
to guarantee ordering. Splitting into separate files loses that free, same-file ordering
guarantee — so every DCM job now has its own **"Verify DCM identity is ready"** step that
authenticates and fails fast with a clear, actionable message
(`Terraform hasn't created this identity yet — run 'Terraform Apply' first`) instead of a
cryptic OIDC error, if the identity doesn't exist yet. This isn't a workaround: OIDC
workload-identity auth against a nonexistent user fails inherently — Snowflake has no way
to validate a token against a user that was never created — so this check simply converts
an unavoidable failure into a legible one. The trade-off: onboarding a domain that needs
*both* a brand-new identity (Terraform) *and* a brand-new manifest (DCM) in the same commit
means the two pipelines run concurrently rather than strictly sequenced — if DCM's job
happens to start before Terraform's finishes, it fails fast with the message above, and the
fix is a one-click workflow re-run. This is deliberately simpler than the alternative
(chaining `dcm-deploy.yml` off `terraform-apply.yml`'s completion via a `workflow_run`
trigger), which would restore automatic sequencing but adds real cross-workflow complexity
(separate trigger semantics, needing to check out `github.event.workflow_run.head_sha`
explicitly, and a real risk of double-triggering DCM deploy when both tools' paths change
in the same commit) for a case that's rare in steady-state domain operation (most day-to-day
changes touch only `dcm/`, since identities are typically created once per domain and
manifests iterated far more often).

### Mandatory notes
- `workflow_dispatch:` is enabled on all 4 workflows for manual triggering without needing a
  PR or push.
- This is deliberately **DEV-only** today — see [Known Limitations](#known-limitations-demo-scope).

---

## History — Terraform → DCM Cutover, then Domain Templating

Databases, schemas, warehouses, functional roles, and DB grants were originally defined as
Terraform resources. They were migrated to DCM, using `removed` blocks (`terraform/removed.tf`)
so Terraform forgot them without destroying the live Snowflake objects — DCM adopted the
exact same objects with no disruption. Names were also changed from generic to
Customer-domain-scoped at the same time:

| Old (Terraform, generic) | Current (DCM, Customer-domain) |
|---|---|
| `DEV_LANDING_DB` / `DEV_ANALYTICS_DB` / `DEV_COMMON_DB` | `DEV_CUSTOMER_DB` (single domain database) |
| `DEV_LANDING_DB.RAW` | `DEV_CUSTOMER_DB.RAW` |
| `DEV_ANALYTICS_DB.STAGING` | `DEV_CUSTOMER_DB.STAGING` |
| `DEV_ANALYTICS_DB.MARTS` | `DEV_CUSTOMER_DB.MARTS` |
| `DEV_COMMON_DB.UTILS` | `DEV_CUSTOMER_DB.SHARED` |
| `DEV_DATA_ENGINEER` / `_ANALYST` / `_CONSUMER` / `DEV_DBT_RUNNER` | Tiered: `DEV_CUSTOMER_*_PRSN` → `DEV_CUSTOMER_*_FNCRL` → `DEV_CUSTOMER_DB.*_SCRL_*` / `DEV_CUSTOMER_*_WH_WHRL_*` |

DCM's hand-written SQL was later rewritten into a reusable, Jinja2-templated structure
(`dcm/_template/`) so a new domain needs zero new SQL — only a new
`dcm/domains/<domain>/manifest.yml`. As part of that work, warehouses were also renamed from
generic/shared (`DEV_INGEST_WH`/`DEV_TRANSFORM_WH`/`DEV_REPORTING_WH`) to per-domain
(`DEV_CUSTOMER_INGEST_WH`/`DEV_CUSTOMER_TRANSFORM_WH`/`DEV_CUSTOMER_REPORTING_WH`) —
matching the reference architecture's convention that domain workload warehouses are never
shared across domains (only genuine platform/CI tooling warehouses would be, and this
platform doesn't currently have any). The current, live definitions for all of the above are
`dcm/_template/sources/definitions/databases.sql`, `schemas.sql`, `warehouses.sql`,
`roles.sql`, `database_roles.sql`, and `grants.sql`, with the actual per-domain values in
`dcm/domains/customer/manifest.yml` — treat those files, not this table, as the source of
truth going forward.

---

## Onboarding a New Domain

This is the actual, repeatable procedure for adding domain #2 (and #3...#200) — not a
hypothetical. `dcm/domains/procurement/manifest.yml` exists in this repo right now as a
**worked example**, built and validated exactly this way, but deliberately **not deployed**
(see "Known Limitations" below for why).

1. **Write `dcm/domains/<domain>/manifest.yml`.** Copy an existing domain's manifest, change
   `domain`, `domain_comment`, and the `schemas`/`warehouses`/`personas`/`functional_roles`/
   `tables` values to match the new domain. Give it its **own new `project_name`**
   (e.g. `DEV_ADMIN_DB.DCM.PROCUREMENT_DCM`) — brand-new domains always get a fresh DCM
   project; only Customer stayed on the pre-templating project for migration-safety
   reasons (see History above). No SQL is written by hand anywhere in this step.

2. **Validate it renders cleanly, offline, before touching Snowflake.**
   ```powershell
   cd dcm/_template
   python _validate_render.py ../domains/<domain>/manifest.yml <CONFIG_NAME>
   ```
   This runs the same Jinja2 macros DCM itself uses, in `StrictUndefined` mode, against
   every file in `sources/definitions/` — it catches the exact class of bug this project
   hit once for real (an optional manifest key missing a `| default(...)` guard) without
   ever creating or touching a live Snowflake object.

3. **Add one new top-level entry to `terraform/domains.yaml`** —
   `GITHUB_DEV_<DOMAIN>_DBT_SVC` (scoped to that domain's own dbt repo) and
   `GITHUB_DEV_<DOMAIN>_INGEST_SVC` (scoped to a new GitHub Environment in the shared
   ingestion repo, e.g. `DEV-Ingest-<Domain>`) — referenced by the manifest's
   `DBT_SERVICE`/`INGEST_SERVICE` persona `oidc_user` fields from step 1. Nothing in
   `terraform/modules/domain_onboarding/` ever needs to change — it's driven entirely by
   this file.

4. **Add one new entry to `dcm/active_domains.json`** — `{"name": "<domain>", "target":
   "<DOMAIN>"}`. This is the single switch that turns the domain "on" for CI: the
   `detect-domains` job in both workflows diffs changed files against this list and only
   creates a `dcm-plan`/`dcm-deploy` job (dynamic matrix, not a hand-copied job block) for
   domains that are both listed here *and* actually changed. A domain's manifest.yml can
   exist and be fully valid (like Procurement's) without ever running in CI — adding it to
   this file is the explicit, auditable "go live" step.

5. **Merge.** CI creates the new DCM project (`snow dcm create --if-not-exists`) and
   deploys it — same mechanism already verified live for Customer and for the Option B
   warehouse rename.

### Known Limitations (this section specifically)

`dcm/domains/procurement/manifest.yml` is intentionally a **template only** — steps 3 and 4
above have *not* been done for it, so it creates nothing in Snowflake. This is a deliberate
demo choice: proving the pattern generalizes (step 1-2, done and verified) without carrying
a second set of live identities/objects/repos that would need ongoing upkeep before this is
actually needed for a real client domain.

---


## Verification Guide

### On Snowflake

Log in to `https://xygpmhm-gq04150.snowflakecomputing.com` as `RADHAASINGH` and run:

```sql
-- Verify Customer domain database (DCM-managed, see dcm/_template/sources/definitions/)
SHOW DATABASES LIKE '%DEV%';
-- Expect: DEV_CUSTOMER_DB, DEV_ADMIN_DB

-- Verify schemas
SHOW SCHEMAS IN DATABASE DEV_CUSTOMER_DB;    -- Expect: RAW, STAGING, MARTS, SHARED

-- Verify warehouses (per-domain, not shared)
SHOW WAREHOUSES LIKE 'DEV_CUSTOMER%';
-- Expect: DEV_CUSTOMER_INGEST_WH, DEV_CUSTOMER_TRANSFORM_WH, DEV_CUSTOMER_REPORTING_WH
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
# Verify only the one actually-used secret exists (AWS_REGION) — no stored Snowflake
# credentials or static AWS access keys should be present
gh secret list --repo radhasgrl/snowflake-platform-tf
# Expected: AWS_REGION only

# Verify both environments exist, each with its own OIDC-scoped identity
gh api repos/radhasgrl/snowflake-platform-tf/environments --jq '.environments[].name'
# Expected: DEV-Terraform, DEV-DCM

# Verify latest pipeline runs all passed
gh run list --repo radhasgrl/snowflake-platform-tf --limit 5
# Expected: all rows show success

# Manually trigger a plan run (no PR needed)
gh workflow run terraform-plan.yml --repo radhasgrl/snowflake-platform-tf
gh workflow run dcm-plan.yml --repo radhasgrl/snowflake-platform-tf
gh run list --repo radhasgrl/snowflake-platform-tf --limit 3
```

### Local Terraform verification — important limitation

`terraform plan`/`apply`/`import` against the **repo-root module** (`terraform/`, minus
`bootstrap/`) cannot be run locally — the Snowflake provider's `WORKLOAD_IDENTITY`
authenticator requires a genuine GitHub Actions-issued OIDC token (fetched via
`ACTIONS_ID_TOKEN_REQUEST_TOKEN`), which only exists inside real GitHub Actions runtime.
This blocks *every* command against that module, not just ones touching Snowflake
resources, since Terraform configures all declared providers before running any operation.
To verify the root module, use `workflow_dispatch` to run
`terraform-plan.yml`/`terraform-apply.yml`/`dcm-plan.yml`/`dcm-deploy.yml` for real, or
read the PR comment a real CI run posts. The two `terraform/bootstrap/` stacks are the
exception — they only use the AWS provider, so `terraform plan` against them works locally
with valid AWS credentials.

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

- **DEV-only.** `terraform/env/qa/` and `terraform/env/prod/` tfvars/backend configs are
  scaffolded but not wired into any pipeline. Extending to QA/PROD is a repeatable pattern
  (new GitHub Environment pair, new OIDC service-user pair, new DCM manifest target) — not
  a redesign.
- **Masking/row-access policies are inert placeholders**
  (`dcm/_template/sources/definitions/masking.sql`, `row_access.sql`) — pass-through/allow-all,
  pending client-confirmed PII/RLS rules.
- **No human-identity path.** Every identity in this repo is a service account (OIDC
  workload identity); there's no SSO/SCIM/MFA/network-policy story modeled here.
- A legacy, currently-unused DynamoDB table (`aws_dynamodb_table.tf_lock` in
  `terraform/bootstrap/state-backend/main.tf`) is still provisioned from an earlier design
  that predates `use_lockfile`-based S3 locking. Confirmed unused by the current backend
  config — kept intentionally rather than destroyed, not a functional dependency.

---

## What's Next

| Item | Scope | Status |
|---|---|---|
| RBAC | Tiered persona → functional → database/warehouse roles | ✅ Implemented (`dcm/_template/sources/definitions/roles.sql`, `database_roles.sql`, `grants.sql`) |
| Masking / row-access policies | PII/RLS enforcement | 🟡 Scaffolded as placeholders; real rules pending client input |
| dbt integration | Repo 3 (`customer-domain-dbt`) — staging → marts | ✅ Implemented and verified end-to-end |
| Ingestion | Repo 2 (`data-ingestion-raw`) — Snowpipe S3 → RAW | ✅ Implemented and verified end-to-end |
| Domain #2+ onboarding pattern | `dcm/domains/procurement/manifest.yml` + `_validate_render.py` | 🟡 Template written and render-validated; deliberately not deployed (see "Onboarding a New Domain") |
| QA / PROD environments | Second+ environment tier, promotion flow | ⬜ Not started — pattern documented, not built |
| Schema migrations tooling (schemachange/Flyway) | Versioned migration history beyond DCM's own diffing | ⬜ Not started |
