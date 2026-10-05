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
3. [Phase 0 — Tools & Prerequisites](#phase-0--tools--prerequisites)
4. [Phase 1 — Authentication](#phase-1--authentication)
5. [Phase 2 — Terraform Remote State (AWS S3)](#phase-2--terraform-remote-state-aws-s3)
6. [Phase 3 — GitHub Actions CI/CD](#phase-3--github-actions-cicd)
7. [Phase 4 — Snowflake Foundation Objects](#phase-4--snowflake-foundation-objects)
8. [Verification Guide](#verification-guide)
9. [Key Decisions](#key-decisions)
10. [New Session Setup](#new-session-setup)

---

## Architecture Overview

This repo is **Repo 1 ("infra-snowflake") of a 3-repo platform**, pairing Terraform with
Snowflake's native DCM (Database Change Management), per the ownership split agreed with
the client in `MDP_Platform_Engineering_CICD_IaC_Repo_Architecture_v0.1.md` §2.2:

- **Terraform** owns the account/platform layer only: GitHub OIDC service identities
  (`GITHUB_DEV_TERRAFORM_SVC`, `GITHUB_DEV_DCM_SVC`).
- **DCM** owns the database object layer: databases, schemas, warehouses, tiered RBAC roles,
  DB grants, and placeholder masking/row-access policies (`sources/definitions/*.sql`).

Identities are scoped to **GitHub Environments** (`DEV-Terraform`, `DEV-DCM`), not to a
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
          │   Snowflake via GitHub OIDC / WORKLOAD_IDENTITY (no stored keys) — creates/updates
          │   the GITHUB_DEV_TERRAFORM_SVC and GITHUB_DEV_DCM_SVC service users
          └── DCM (snow CLI): authenticates as GITHUB_DEV_DCM_SVC via the same OIDC pattern —
              creates/updates databases, schemas, warehouses, tiered RBAC roles
              (persona -> functional -> database/warehouse roles), grants, and placeholder
              masking/row-access policies

AWS (ap-southeast-2 / Sydney)
 └── S3 bucket: snowflake-platform-tf-state-525218385225
      └── workload/dev/terraform.tfstate   ← encrypted, versioned (Terraform's state only — DCM has no separate state file, it diffs its SQL definitions against live Snowflake metadata)

Snowflake Account: xygpmhm-gq04150
 ├── GITHUB_DEV_TERRAFORM_SVC — Terraform identity (OIDC, GitHub Environment DEV-Terraform)
 ├── GITHUB_DEV_DCM_SVC       — DCM identity (OIDC, GitHub Environment DEV-DCM)
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

## Phase 0 — Tools & Prerequisites

### What was installed

| Tool | Version | Location |
|---|---|---|
| Terraform | 1.16.0 | `C:\tools\terraform\terraform.exe` |
| Snowflake CLI | 3.25.0 | Python 3.11 pip install |
| AWS CLI | 2.36.33 | winget |
| GitHub CLI | 2.98.0 | `C:\Program Files\GitHub CLI\gh.exe` |
| Git | 2.55.0 | Pre-installed |
| OpenSSL | (via Git) | `C:\Users\...\AppData\Local\Programs\Git\usr\bin\openssl.exe` |

### How it was done

```powershell
# Terraform — manual download, no admin rights needed
New-Item -ItemType Directory -Path C:\tools\terraform
# Download terraform_1.16.0_windows_amd64.zip from releases.hashicorp.com
# Extract terraform.exe to C:\tools\terraform\

# Snowflake CLI — via Python 3.11 (corporate SSL proxy workarounds required)
py -3.11 -m pip install snowflake-cli `
  --trusted-host pypi.org `
  --trusted-host pypi.python.org `
  --trusted-host files.pythonhosted.org

# AWS CLI
winget install Amazon.AWSCLI --source winget

# GitHub CLI
winget install GitHub.cli --source winget
```

### Mandatory notes
- **No admin rights**: Machine-level PATH writes are blocked. PATH must be set per session (see [New Session Setup](#new-session-setup)).
- **Corporate SSL proxy (Zscaler)**: All `pip install` commands require `--trusted-host` flags.
- **Terraform version conflict**: winget installs an older version. Always use the manually downloaded binary at `C:\tools\terraform\`.

---

## Phase 1 — Authentication

### What was created

| Item | Detail |
|---|---|
| RSA private key | `~/.ssh/snowflake/tf_snow_key.p8` (PKCS8, no passphrase) |
| RSA public key | `~/.ssh/snowflake/tf_snow_key.pub` |
| Snowflake service user | `TERRAFORM_SVC` — no password, RSA JWT auth only |
| Roles granted to TERRAFORM_SVC | `SYSADMIN`, `SECURITYADMIN`, `USERADMIN` |
| AWS CLI profile | IAM user `terraform-platform-svc` (Account: 525218385225, Region: ap-southeast-2) |
| GitHub auth | `gh auth login` as `radhasgrl` |

### How it was done

```powershell
# 1. Generate RSA key pair (via OpenSSL bundled with Git)
$openssl = "C:\Users\radha.a.singh\AppData\Local\Programs\Git\usr\bin\openssl.exe"
New-Item -ItemType Directory -Force -Path ~/.ssh/snowflake
& $openssl genrsa -out ~/.ssh/snowflake/tf_snow_key_raw.pem 2048
& $openssl pkey -in ~/.ssh/snowflake/tf_snow_key_raw.pem -out ~/.ssh/snowflake/tf_snow_key.p8
& $openssl rsa -in ~/.ssh/snowflake/tf_snow_key.p8 -pubout -out ~/.ssh/snowflake/tf_snow_key.pub
```

```sql
-- 2. Run in Snowflake worksheet as ACCOUNTADMIN
CREATE USER TERRAFORM_SVC
  TYPE = SERVICE
  RSA_PUBLIC_KEY = '<paste content of tf_snow_key.pub without header/footer lines>';

GRANT ROLE SYSADMIN     TO USER TERRAFORM_SVC;
GRANT ROLE SECURITYADMIN TO USER TERRAFORM_SVC;
GRANT ROLE USERADMIN    TO USER TERRAFORM_SVC;
```

```powershell
# 3. Configure AWS CLI
aws configure
# AWS Access Key ID: <terraform-platform-svc key>
# AWS Secret Access Key: <terraform-platform-svc secret>
# Default region: ap-southeast-2
# Default output format: json

# 4. Authenticate GitHub CLI
& "C:\Program Files\GitHub CLI\gh.exe" auth login
```

### Mandatory notes
- The public key pasted into Snowflake must have the `-----BEGIN PUBLIC KEY-----` / `-----END PUBLIC KEY-----` lines **removed** — paste only the base64 body.
- The private key file (`.p8`) must **never be committed** to git — it is covered by `.gitignore`.
- Three provider aliases in `providers.tf` (repo root) each use a different Snowflake role to enforce least-privilege:
  - Default provider → `SYSADMIN` (databases, schemas, warehouses)
  - `snowflake.useradmin` → role and user management
  - `snowflake.securityadmin` → masking and row access policies

---

## Phase 2 — Terraform Remote State (AWS S3)

### What was created

| Resource | Detail |
|---|---|
| S3 bucket | `snowflake-platform-tf-state-525218385225` (ap-southeast-2 / Sydney) |
| Bucket versioning | Enabled — all state versions retained |
| Bucket encryption | AES256 server-side encryption |
| Public access | All public access blocked |
| State locking | `use_lockfile = true` in S3 backend (no DynamoDB needed) |
| State file location | `s3://snowflake-platform-tf-state-525218385225/workload/dev/terraform.tfstate` |

### How it was done

The bootstrap module uses a **local** Terraform state (intentionally — it bootstraps the remote backend).

```powershell
cd bootstrap/state-backend
terraform init
terraform apply -auto-approve
```

The repo root's `terraform.tf` then uses that S3 backend via `env/dev/backend.hcl`:

```hcl
backend "s3" {}   # bucket/key/region supplied per-environment via -backend-config
```

```powershell
# from the repo root
terraform init -backend-config="env/dev/backend.hcl"
```

### Mandatory notes
- The bootstrap must be run **once only** before using the root module.
- The bootstrap state (`bootstrap/state-backend/terraform.tfstate`) is local and **not** pushed to git (covered by `.gitignore`).
- The S3 bucket was originally created in `eu-west-1` and later migrated to `ap-southeast-2` to align with the client's AWS region.

---

## Phase 3 — GitHub Actions CI/CD

### What was created

| Item | Detail |
|---|---|
| GitHub repository | `radhasgrl/snowflake-platform-tf` (private) |
| Workflow: plan | `.github/workflows/terraform-plan.yml` — triggers on Pull Request |
| Workflow: apply | `.github/workflows/terraform-apply.yml` — triggers on push to `main` |
| GitHub secrets | 5 secrets set (see table below) |

#### GitHub Secrets

| Secret Name | What it holds |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user `terraform-platform-svc` access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user `terraform-platform-svc` secret key |
| `AWS_REGION` | `ap-southeast-2` |
| `SNOWFLAKE_ACCOUNT` | `xygpmhm-gq04150` |
| `SNOWFLAKE_PRIVATE_KEY` | Full content of `tf_snow_key.p8` (RSA private key) |

### How it was done

```powershell
$gh = "C:\Program Files\GitHub CLI\gh.exe"

# Create repo
& $gh repo create radhasgrl/snowflake-platform-tf --private --source . --push

# Set secrets
& $gh secret set AWS_ACCESS_KEY_ID       --repo radhasgrl/snowflake-platform-tf
& $gh secret set AWS_SECRET_ACCESS_KEY   --repo radhasgrl/snowflake-platform-tf
Write-Output "ap-southeast-2" | & $gh secret set AWS_REGION --repo radhasgrl/snowflake-platform-tf
Write-Output "xygpmhm-gq04150" | & $gh secret set SNOWFLAKE_ACCOUNT --repo radhasgrl/snowflake-platform-tf
Get-Content ~/.ssh/snowflake/tf_snow_key.p8 | & $gh secret set SNOWFLAKE_PRIVATE_KEY --repo radhasgrl/snowflake-platform-tf
```

### How the pipeline works

```
Pull Request opened
  └─► terraform-plan.yml runs
        ├── Checks out code
        ├── Configures AWS credentials (for S3 state access)
        ├── Writes private key from secret → ~/.ssh/snowflake/tf_snow_key.p8
        ├── terraform init  (connects to S3 backend)
        ├── terraform plan  (shows what will change)
        └── Posts plan output as PR comment

PR merged to main
  └─► terraform-apply.yml runs
        ├── (same setup steps)
        └── terraform apply -auto-approve  (creates/updates Snowflake objects)
```

### Mandatory notes
- `workflow_dispatch:` is added to both workflows so they can be triggered manually from the GitHub Actions UI without needing a PR or push.
- The private key is written to disk inside the runner at the exact path expected by `terraform/foundation/variables.tf` (`~/.ssh/snowflake/tf_snow_key.p8`).

---

## Phase 4 — Snowflake Foundation Objects (superseded — now DCM-owned, see below)

> **Superseded**: the databases/schemas/warehouses described in this phase were originally
> Terraform resources. They have since moved to DCM (`sources/definitions/`) per the
> ownership split in `MDP_Platform_Engineering_CICD_IaC_Repo_Architecture_v0.1.md` §2.2, and
> were renamed to be Customer-domain-scoped. The tables below are kept for history; current
> names are:
>
> | Old (Terraform, generic) | Current (DCM, Customer-domain) |
> |---|---|
> | `DEV_LANDING_DB` / `DEV_ANALYTICS_DB` / `DEV_COMMON_DB` | `DEV_CUSTOMER_DB` (single domain database) |
> | `DEV_LANDING_DB.RAW` | `DEV_CUSTOMER_DB.RAW` |
> | `DEV_ANALYTICS_DB.STAGING` | `DEV_CUSTOMER_DB.STAGING` |
> | `DEV_ANALYTICS_DB.MARTS` | `DEV_CUSTOMER_DB.MARTS` |
> | `DEV_COMMON_DB.UTILS` | `DEV_CUSTOMER_DB.SHARED` |
> | `DEV_DATA_ENGINEER` / `_ANALYST` / `_CONSUMER` / `DEV_DBT_RUNNER` | Tiered: `DEV_CUSTOMER_*_PRSN` → `DEV_CUSTOMER_*_FNCRL` → `DEV_CUSTOMER_DB.*_SCRL_*` / `DEV_*_WH_WHRL_*` (see `sources/definitions/roles.sql`, `database_roles.sql`, `grants.sql`) |
>
> Warehouses (`DEV_INGEST_WH`/`DEV_TRANSFORM_WH`/`DEV_REPORTING_WH`) are unchanged — they
> remain account-level shared compute, not domain-prefixed.

### What was created

All resources are environment-prefixed using `var.environment` (default: `dev`).

#### Databases

| Terraform Resource | Snowflake Name | Purpose |
|---|---|---|
| `snowflake_database.landing` | `DEV_LANDING_DB` | Raw ingestion zone — untransformed source data |
| `snowflake_database.analytics` | `DEV_ANALYTICS_DB` | Transformed and curated analytics layer |
| `snowflake_database.common` | `DEV_COMMON_DB` | Shared utilities — UDFs, procedures, reference data |

#### Schemas

| Terraform Resource | Snowflake Location | Purpose |
|---|---|---|
| `snowflake_schema.landing_raw` | `DEV_LANDING_DB.RAW` | Initial landing area for all source ingestion |
| `snowflake_schema.analytics_staging` | `DEV_ANALYTICS_DB.STAGING` | Intermediate dbt models |
| `snowflake_schema.analytics_marts` | `DEV_ANALYTICS_DB.MARTS` | Final business-facing data marts |
| `snowflake_schema.common_utils` | `DEV_COMMON_DB.UTILS` | Shared UDFs and stored procedures |

#### Warehouses

| Terraform Resource | Snowflake Name | Size | Auto-suspend | Purpose |
|---|---|---|---|---|
| `snowflake_warehouse.ingest` | `DEV_INGEST_WH` | XSMALL | 60s | Data loading and ingestion |
| `snowflake_warehouse.transform` | `DEV_TRANSFORM_WH` | XSMALL (dev) / SMALL (prod) | 120s | dbt transformations |
| `snowflake_warehouse.reporting` | `DEV_REPORTING_WH` | XSMALL | 60s | BI tools and ad-hoc queries |

All warehouses start as `initially_suspended = true` — they only run when used.

### How it was done

Code was written in `terraform/foundation/main.tf` and pushed to `main`.
The `terraform-apply.yml` pipeline triggered automatically and applied the changes.

```powershell
git add terraform/foundation/
git commit -m "feat: Phase 4 - Snowflake foundation databases, schemas, warehouses (DEV)"
git push origin main
# Pipeline ran and created all 10 resources in Snowflake
```

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
aws s3 ls s3://snowflake-platform-tf-state-525218385225/foundation/ --region ap-southeast-2
# Expected: terraform.tfstate (approx 57 KB)

# Verify encryption
aws s3api get-bucket-encryption --bucket snowflake-platform-tf-state-525218385225 --region ap-southeast-2
# Expected: AES256

# Verify no public access
aws s3api get-public-access-block --bucket snowflake-platform-tf-state-525218385225 --region ap-southeast-2
# Expected: all four values = true
```

### On GitHub

```powershell
$gh = "C:\Program Files\GitHub CLI\gh.exe"

# Verify all 5 secrets are set
& $gh secret list --repo radhasgrl/snowflake-platform-tf
# Expected: AWS_ACCESS_KEY_ID, AWS_REGION, AWS_SECRET_ACCESS_KEY,
#           SNOWFLAKE_ACCOUNT, SNOWFLAKE_PRIVATE_KEY

# Verify latest pipeline runs all passed
& $gh run list --repo radhasgrl/snowflake-platform-tf --limit 5
# Expected: all rows show ✓

# Verify workflow files exist
& $gh api repos/radhasgrl/snowflake-platform-tf/contents/.github/workflows

# Manually trigger a plan run (no PR needed)
& $gh workflow run terraform-plan.yml --repo radhasgrl/snowflake-platform-tf
& $gh run list --repo radhasgrl/snowflake-platform-tf --limit 3
```

### Local Terraform verification

```powershell
# Session setup (required each new terminal)
$env:PATH = "C:\tools\terraform;C:\Users\radha.a.singh\AppData\Local\Programs\Python\Python311\Scripts;C:\Program Files\GitHub CLI;" + $env:PATH

cd "C:\Users\radha.a.singh\OneDrive - Accenture\Documents\Snowflake_Platform_TF\terraform\foundation"

# Confirm backend points to Sydney and state is accessible
terraform init

# Confirm no drift — should show "No changes. Infrastructure is up-to-date."
terraform plan
```

---

## Key Decisions

| Decision | Choice | Reason |
|---|---|---|
| IaC tool | Terraform 1.16.0 | Client requirement; not OpenTofu |
| Snowflake auth | RSA key pair JWT | No passwords; service account best practice |
| State storage | AWS S3 + `use_lockfile` | Secure, versioned, no DynamoDB required |
| State region | `ap-southeast-2` (Sydney) | Aligns with client's AWS region |
| Environment strategy | Single account, env-prefix naming | `DEV_`, `QA_`, `PROD_` prefixes on all objects |
| Snowflake provider | `snowflakedb/snowflake ~> 2.0` | Resolved to v2.20.0 |
| CI/CD | GitHub Actions | Already used for source control |

---

## New Session Setup

Each new PowerShell terminal requires these commands (PATH is not persisted without admin rights):

```powershell
$env:PATH = "C:\tools\terraform;C:\Users\radha.a.singh\AppData\Local\Programs\Python\Python311\Scripts;C:\Program Files\GitHub CLI;" + $env:PATH
Set-Alias -Name gh -Value "C:\Program Files\GitHub CLI\gh.exe"
Set-Location "C:\Users\radha.a.singh\OneDrive - Accenture\Documents\Snowflake_Platform_TF"
```

---

## What's Next

| Phase | Scope | Status |
|---|---|---|
| Phase 5 | RBAC — functional roles, grants, masking policies, row access policies | 🟡 Foundation implemented; masking/RLS require client rules |
| Phase 6 | dbt integration + schema change migrations (schemachange/Flyway) | ⬜ Not started |
