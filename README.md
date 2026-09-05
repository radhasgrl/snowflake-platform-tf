# Snowflake DataOps Platform — Terraform

A fully automated Snowflake DataOps platform managed entirely through Terraform,
with CI/CD via GitHub Actions and remote state in AWS S3.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Folder Structure](#folder-structure)
3. [Phase 0 — Tools & Prerequisites](#phase-0--tools--prerequisites)
4. [Phase 1 — Authentication](#phase-1--authentication)
5. [Phase 2 — Terraform Remote State (AWS S3)](#phase-2--terraform-remote-state-aws-s3)
6. [Phase 3 — GitHub Actions CI/CD](#phase-3--github-actions-cicd)
7. [Phase 3.5 — OIDC Hardening](#phase-35--oidc-hardening)
8. [Phase 4 — Snowflake Foundation Objects](#phase-4--snowflake-foundation-objects)
9. [Phase 5 — RBAC & Security Policies](#phase-5--rbac--security-policies)
10. [Verification Guide](#verification-guide)
11. [Key Decisions](#key-decisions)
12. [New Session Setup](#new-session-setup)


---

## Architecture Overview

```
Developer / PR
     │
     ▼
GitHub Actions (CI/CD)
 ├── terraform-plan.yml   → runs on Pull Request  → posts plan as PR comment
 └── terraform-apply.yml  → runs on push to main  → applies to Snowflake
          │
          ├── AuthN to AWS       → OIDC (AssumeRoleWithWebIdentity) — both workflows, no stored AWS secret
          ├── AuthN to Snowflake → apply: OIDC (WORKLOAD_IDENTITY) | plan: RSA JWT key-pair (unchanged)
          └── Creates/manages Snowflake objects (databases, schemas, warehouses, RBAC…)

AWS (ap-southeast-2 / Sydney)
 └── S3 bucket: snowflake-platform-tf-state-525218385225
      ├── workload/dev/terraform.tfstate    ← encrypted, versioned
      ├── workload/qa/terraform.tfstate
      └── workload/prod/terraform.tfstate

Snowflake Account: xygpmhm-gq04150
 ├── TERRAFORM_SVC service user (RSA key-pair auth, no password)
 └── Managed objects: databases, schemas, warehouses, roles, grants…
```

This repository follows a single-root, domain-file layout — the same pattern
used across the platform's production AWS Terraform repositories (flat,
domain-named `.tf` files at the root, environment config in `env/<env>/`,
one state file per environment). `bootstrap/` remains an isolated, one-time
stack because it creates the S3 backend that everything else depends on.

---

## Folder Structure

```
.
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml      # Runs terraform plan on Pull Requests / manual dispatch
│       └── terraform-apply.yml     # Runs terraform apply on merge to main / manual dispatch
├── bootstrap/                      # One-time setup: creates the S3 state bucket (isolated stack)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── env/                             # Per-environment tfvars + backend config
│   ├── dev/
│   │   ├── dev.tfvars
│   │   └── backend.hcl
│   ├── qa/
│   │   ├── qa.tfvars
│   │   └── backend.hcl
│   └── prod/
│       ├── prod.tfvars
│       └── backend.hcl
├── terraform.tf                     # Version pin + partial S3 backend
├── providers.tf                     # SYSADMIN / USERADMIN / SECURITYADMIN provider aliases
├── context.tf                       # Environment naming context (local.env, comment standard)
├── variables.tf
├── locals.tf                        # Database/warehouse/role naming + grant maps
├── databases.tf                     # Snowflake databases
├── schemas.tf                       # Snowflake schemas
├── warehouses.tf                    # Snowflake warehouses
├── roles.tf                         # Functional roles + role hierarchy
├── grants.tf                        # Warehouse/database/schema/table grants
├── outputs.tf
├── .gitignore
├── .terraform-version              # Pins Terraform to 1.16.0
└── README.md
```

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
- Three provider aliases in [providers.tf](providers.tf) each use a different Snowflake role to enforce least-privilege:
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
| State file location | `s3://snowflake-platform-tf-state-525218385225/workload/<env>/terraform.tfstate` |

Each environment (`dev`, `qa`, `prod`) gets its own state key, its own backend
config file, and its own tfvars file — see [env/](env/).

### How it was done

The bootstrap module uses a **local** Terraform state (intentionally — it bootstraps the remote backend).

```powershell
cd bootstrap
terraform init
terraform apply -auto-approve
```

[terraform.tf](terraform.tf) then declares a **partial** S3 backend at the repo root, with per-environment values supplied at init time:

```hcl
backend "s3" {}
```

```powershell
# Backend config lives in env/<env>/backend.hcl, e.g. env/dev/backend.hcl:
#   bucket       = "snowflake-platform-tf-state-525218385225"
#   key          = "workload/dev/terraform.tfstate"
#   region       = "ap-southeast-2"
#   encrypt      = true
#   use_lockfile = true

terraform init -backend-config="env/dev/backend.hcl"
```

### Mandatory notes
- The bootstrap must be run **once only** before using the workload stack.
- The bootstrap state (`bootstrap/terraform.tfstate`) is local and **not** pushed to git (covered by `.gitignore`).
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

| Secret Name | What it holds | Status |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user `terraform-platform-svc` access key | ⚠️ Unused since Phase 3.5 (OIDC) — pending removal |
| `AWS_SECRET_ACCESS_KEY` | IAM user `terraform-platform-svc` secret key | ⚠️ Unused since Phase 3.5 (OIDC) — pending removal |
| `AWS_REGION` | `ap-southeast-2` | ✅ Still used (region for OIDC role assumption) |
| `SNOWFLAKE_ACCOUNT` | `xygpmhm-gq04150` | ✅ In use |
| `SNOWFLAKE_PRIVATE_KEY` | Full content of `tf_snow_key.p8` (RSA private key) | ✅ Still used by `terraform-plan.yml`; unused by `terraform-apply.yml` since Phase 3.5 |

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

### How the pipeline works (as originally built, Phase 3)

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

> See [Phase 3.5](#phase-35--oidc-hardening) below — `terraform-apply.yml`'s AWS and Snowflake
> authentication steps have since been replaced with OIDC. This section is kept
> as the historical record of how Phase 3 was originally delivered.

---

## Phase 3.5 — OIDC Hardening

Follows directly from the [Configure CI/CD Integrations with Snowflake](https://www.snowflake.com/en/developers/guides/configure-cicd-integrations-with-snowflake/)
guide and AWS's own recommended pattern for GitHub Actions — replacing long-lived
static secrets with short-lived, per-run OIDC tokens.

### What was created

| Item | Detail |
|---|---|
| AWS IAM OIDC provider | Trusts `token.actions.githubusercontent.com`, created via [aws-oidc-bootstrap/](aws-oidc-bootstrap) (human-applied, not by the pipeline's own IAM identity) |
| AWS IAM role | `snowflake-platform-tf-github-oidc` — trust policy scoped to this repo's actual `sub` claim format |
| Snowflake service user | `GITHUB_OIDC_TERRAFORM_SVC`, created via [oidc_service_user.tf](oidc_service_user.tf) — `WORKLOAD_IDENTITY` trust scoped to the push-to-main subject claim |
| Provider auth switch | `providers.tf` — all 3 provider aliases gated by `var.use_workload_identity`; `terraform-apply.yml` sets it `true`, `terraform-plan.yml` leaves it `false` (unchanged, still key-pair) |

### Status by workflow

| Workflow | AWS auth | Snowflake auth |
|---|---|---|
| `terraform-apply.yml` | ✅ OIDC (`AssumeRoleWithWebIdentity`) | ✅ OIDC (`WORKLOAD_IDENTITY`) |
| `terraform-plan.yml` | ✅ OIDC (`AssumeRoleWithWebIdentity`) | ⚪ Key-pair (`TERRAFORM_SVC`) — intentionally scoped out; see [Authentication-Authorization-Options.md](Authentication-Authorization-Options.md) for why |

### Key finding during implementation

GitHub's OIDC `sub` claim uses a newer, more secure format that includes stable
account/repo IDs — `repo:owner@ownerId/repo@repoId:ref:refs/heads/main` — not the
classic `repo:owner/repo:ref:...` pattern most examples online still show. Both
the AWS IAM trust policy and the Snowflake `WORKLOAD_IDENTITY` `SUBJECT` were
updated to match the actual claim (verified via a temporary debug step that
decoded the real token).

### Mandatory notes
- Snowflake's `SUBJECT` match is an **exact string**, unlike AWS IAM's `StringLike` wildcard — this is why `terraform-plan.yml` (a different `sub` claim, PR-triggered) needs its own separate Snowflake OIDC identity, not yet built.
- The AWS OIDC provider + role were applied by a human with elevated AWS access via CloudShell, never by the pipeline's own narrowly-scoped IAM user — see [Authentication-Authorization-Options.md](Authentication-Authorization-Options.md) for the reasoning.
- `.gitattributes` was added to force LF line endings on `.tf`/`.tfvars`/`.hcl` files — without it, a Windows checkout of a Linux-CI-applied `snowflake_execute` resource could show a false diff and attempt to needlessly drop/recreate a resource.
- `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` GitHub secrets are no longer read by either workflow but have not yet been deleted (pending final verification).

---

### Mandatory notes
- `workflow_dispatch:` is added to both workflows with an `environment` choice input (`dev`/`qa`/`prod`), so any environment can be planned or applied manually from the GitHub Actions UI.
- On a plain push to `main`, both workflows default to the `dev` environment.
- The private key is written to disk inside the runner at the exact path expected by [variables.tf](variables.tf) (`~/.ssh/snowflake/tf_snow_key.p8`).

---

## Phase 4 — Snowflake Foundation Objects

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

Code was written in [databases.tf](databases.tf), [schemas.tf](schemas.tf), and [warehouses.tf](warehouses.tf) and pushed to `main`.
The `terraform-apply.yml` pipeline triggered automatically and applied the changes to the `dev` environment.

```powershell
git add databases.tf schemas.tf warehouses.tf outputs.tf
git commit -m "feat: Phase 4 - Snowflake foundation databases, schemas, warehouses (DEV)"
git push origin main
# Pipeline ran and created all 10 resources in Snowflake
```

---

## Phase 5 — RBAC & Security Policies

### What was created

#### Functional Roles

| Terraform Resource | Snowflake Name | Purpose |
|---|---|---|
| `snowflake_account_role.functional["data_engineer"]` | `DEV_DATA_ENGINEER` | Full read/write across landing, analytics, and common schemas |
| `snowflake_account_role.functional["data_analyst"]` | `DEV_DATA_ANALYST` | Read access to staging and marts |
| `snowflake_account_role.functional["data_consumer"]` | `DEV_DATA_CONSUMER` | Read access to marts only |
| `snowflake_account_role.functional["dbt_runner"]` | `DEV_DBT_RUNNER` | Read/write on staging for dbt transformations |

All four roles are granted upward to `SYSADMIN` so ownership is never orphaned.

#### Grants

Every warehouse, database, schema, and table-level privilege is declared in
[grants.tf](grants.tf) — current-table and future-table `SELECT` grants are
both included, so new tables created later automatically inherit the correct
access for `data_analyst`/`data_consumer` without a manual grant.

#### Security Policy Pattern (Placeholders)

| Terraform Resource | Snowflake Name | Status |
|---|---|---|
| `snowflake_masking_policy.placeholder_varchar` | `DEV_PLACEHOLDER_VARCHAR_MASK` | No-op — passes VARCHAR values through unmasked |
| `snowflake_row_access_policy.placeholder_allow_all` | `DEV_PLACEHOLDER_ALLOW_ALL_RAP` | No-op — allows all rows through |

Both policies exist in [masking.tf](masking.tf) and [row_access.tf](row_access.tf)
so the attachment pattern is demo-able. Real masking/RLS rules are pending the
client's answers to `Questionnaire.md` (PII columns, row-level access rules).

Creating these policies required one additional grant: `SYSADMIN` owns
`DEV_COMMON_DB.UTILS`, so it must explicitly grant `CREATE MASKING POLICY` and
`CREATE ROW ACCESS POLICY` to `SECURITYADMIN` before `SECURITYADMIN` can create
anything there — see `securityadmin_policy_creation` in [grants.tf](grants.tf).

### How it was done

Code was written in [roles.tf](roles.tf), [grants.tf](grants.tf),
[masking.tf](masking.tf), and [row_access.tf](row_access.tf), pushed to `main`,
and applied automatically by `terraform-apply.yml` — same pipeline, same
`dev` environment, no new infrastructure required.

### Mandatory notes
- Masking and row access policies must be created by a role with the schema-level `CREATE MASKING POLICY`/`CREATE ROW ACCESS POLICY` privilege — not automatically available to `SECURITYADMIN` on schemas owned by `SYSADMIN`.
- The Terraform provider requires exactly one `on_account_object`/`on_schema` block per grant resource — looping with `for_each` over multiple objects in a single resource is not supported and will error with "Too many blocks".

---

## Verification Guide

### On Snowflake

Log in to `https://xygpmhm-gq04150.snowflakecomputing.com` as `RADHAASINGH` and run:

```sql
-- Verify service user exists with RSA auth
SHOW USERS LIKE 'TERRAFORM_SVC';
DESC USER TERRAFORM_SVC;   -- RSA_PUBLIC_KEY should be populated

-- Verify databases
SHOW DATABASES LIKE '%DEV%';
-- Expect: DEV_LANDING_DB, DEV_ANALYTICS_DB, DEV_COMMON_DB

-- Verify schemas
SHOW SCHEMAS IN DATABASE DEV_LANDING_DB;    -- Expect: RAW
SHOW SCHEMAS IN DATABASE DEV_ANALYTICS_DB; -- Expect: STAGING, MARTS
SHOW SCHEMAS IN DATABASE DEV_COMMON_DB;    -- Expect: UTILS

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

# Verify the GitHub OIDC provider and role exist (requires elevated AWS access)
aws iam list-open-id-connect-providers
aws iam get-role --role-name snowflake-platform-tf-github-oidc
```

### OIDC (Phase 3.5)

```sql
-- In Snowflake, verify the OIDC service user exists with WORKLOAD_IDENTITY configured
SHOW USERS LIKE 'GITHUB_OIDC_TERRAFORM_SVC';
DESC USER GITHUB_OIDC_TERRAFORM_SVC;   -- has_workload_identity should be TRUE
```

```powershell
# Confirm the latest terraform-apply.yml run authenticated via OIDC, not key-pair
& $gh run list --repo radhasgrl/snowflake-platform-tf --workflow terraform-apply.yml --limit 3
# Open a run and confirm the "Configure AWS credentials (OIDC)" and
# "Fetch Snowflake OIDC token" steps both succeeded
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

cd "C:\Users\radha.a.singh\OneDrive - Accenture\Documents\Snowflake_Platform_TF"

# Confirm backend points to Sydney and state is accessible (dev environment)
terraform init -backend-config="env/dev/backend.hcl"

# Confirm no drift — should show "No changes. Infrastructure is up-to-date."
terraform plan -var-file="env/dev/dev.tfvars"
```

---

## Key Decisions

| Decision | Choice | Reason |
|---|---|---|
| IaC tool | Terraform 1.16.0 | Client requirement; not OpenTofu |
| Snowflake auth (apply workflow) | OIDC `WORKLOAD_IDENTITY` | Short-lived, per-run token — no stored secret; Snowflake's current recommended CI/CD pattern |
| Snowflake auth (plan workflow) | RSA key pair JWT | Retained intentionally — Snowflake `SUBJECT` matching has no wildcard, so PR-triggered runs need a separate OIDC identity not yet built |
| AWS auth (both workflows) | OIDC `AssumeRoleWithWebIdentity` | No stored AWS secret; matches AWS's recommended GitHub Actions pattern |
| State storage | AWS S3 + `use_lockfile` | Secure, versioned, no DynamoDB required |
| State region | `ap-southeast-2` (Sydney) | Aligns with client's AWS region |
| Environment strategy | Single account, env-prefix naming | `DEV_`, `QA_`, `PROD_` prefixes on all objects |
| Repository layout | Single root stack, flat domain files | Matches the platform's production AWS Terraform repo conventions |
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
| Phase 3.5 | OIDC hardening — AWS (both workflows) + Snowflake (apply workflow) | 🟢 Live and verified; `terraform-plan.yml` Snowflake OIDC + secret cleanup still pending |
| Phase 5 | RBAC — functional roles, grants, masking policies, row access policies | 🟡 Foundation implemented; masking/RLS require client rules |
| Phase 6 | dbt integration + schema change migrations (schemachange/Flyway) | ⬜ Not started |
