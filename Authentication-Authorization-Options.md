# CI/CD & DataOps Authentication and Authorization Options

Scope: this document covers **only the identities and permissions involved in
the automated pipeline** — not human SSO, MFA, or end-user login. Those are
separate IT/IAM topics. This is specifically the CI/CD ↔ Cloud ↔ Snowflake
trust chain that makes "DataOps" (infrastructure and data platform changes
delivered exclusively through pipelines) possible.

---

## Table of Contents

1. [The CI/CD Trust Chain](#the-cicd-trust-chain)
2. [Pipeline → Snowflake Authentication](#pipeline--snowflake-authentication)
3. [Pipeline → AWS Authentication](#pipeline--aws-authentication)
4. [Secrets Management Patterns](#secrets-management-patterns)
5. [Authorization-as-Code (Snowflake RBAC via Terraform)](#authorization-as-code-snowflake-rbac-via-terraform)
6. [Environment Promotion & Change Control](#environment-promotion--change-control)
7. [What We Implemented in This POC](#what-we-implemented-in-this-poc)
8. [What We Recommend for Production](#what-we-recommend-for-production)
9. [Demo Talking Points](#demo-talking-points)
10. [Decision Matrix Summary](#decision-matrix-summary)

---

## The CI/CD Trust Chain

DataOps means every Snowflake and AWS change is made **only** by a pipeline —
never by a human clicking in a console. That requires the pipeline itself to
authenticate as a non-human identity at two points:

```
Developer opens PR / merges to main
        │
        ▼
GitHub Actions runner (ephemeral, no persistent identity)
        │
        ├──► AuthN to AWS        → fetch/lock Terraform state in S3
        │
        └──► AuthN to Snowflake  → apply Terraform-declared RBAC + objects
                    │
                    └──► AuthZ inside Snowflake → role hierarchy decides
                         what SYSADMIN / USERADMIN / SECURITYADMIN
                         are each allowed to create
```

Every option below answers one of these three links in the chain.

---

## Pipeline → Snowflake Authentication

| Method | How it works | Fit for CI/CD | Trade-offs |
|---|---|---|---|
| **RSA Key-Pair (`SNOWFLAKE_JWT`)** | A dedicated `TYPE = SERVICE` user has a public key registered; the pipeline holds the private key and signs a JWT per connection | ✅ Standard pattern for Terraform-driven pipelines today | Private key is a long-lived secret — must be stored in GitHub Secrets and rotated manually |
| **Workload Identity Federation (OIDC)** | GitHub issues a short-lived signed token per run; the Snowflake service user has `WORKLOAD_IDENTITY` configured to trust GitHub's OIDC issuer + a specific repo/branch subject claim | ✅ Snowflake's current recommended approach for CI/CD | Requires Snowflake CLI ≥ 3.11; one-time setup of `WORKLOAD_IDENTITY` on the service user |
| **Programmatic Access Token (PAT)** | Snowflake issues a scoped, expiring bearer token tied to a user | ⚠️ Usable, but token still needs to be stored as a secret and manually refreshed before expiry | Simpler than key-pair to generate, but doesn't remove the "stored secret" problem |
| **Username + Password** | Static credential | ❌ Not viable — no MFA path for unattended automation, and passwords are the weakest secret class | Avoid entirely for pipelines |

**Key CI/CD distinction:** key-pair and PAT both require a **secret that exists
before and after the pipeline runs** (stored, rotated, revoked manually). OIDC
requires **no persisted secret** — the token is minted fresh per run and
expires in minutes.

---

## Pipeline → AWS Authentication

| Method | How it works | Fit for CI/CD | Trade-offs |
|---|---|---|---|
| **IAM User + Static Access Keys** | Long-lived Access Key ID + Secret Access Key stored as GitHub Secrets | ✅ Fastest to stand up | Highest blast radius if the repo/secrets are compromised; requires manual rotation |
| **GitHub OIDC → IAM Role (`AssumeRoleWithWebIdentity`)** | GitHub's OIDC token is exchanged for temporary AWS credentials via a trust policy scoped to `repo:org/repo:ref:refs/heads/main` | ✅ AWS's recommended approach for GitHub Actions | One-time setup: create an IAM OIDC identity provider + a role with a scoped trust policy; no long-lived AWS secret ever touches GitHub |
| **Self-Hosted Runner + Instance Profile** | A runner inside AWS (EC2/ECS) inherits credentials automatically from its instance/task role | ⚠️ Only applicable if the client requires runners inside their VPC (e.g. PrivateLink-only Snowflake access) | Adds infrastructure to maintain (the runner itself); not needed for GitHub-hosted runners |

---

## Secrets Management Patterns

Regardless of which authentication method is chosen, CI/CD secrets need a
storage and access-control strategy:

| Pattern | Description | When to use |
|---|---|---|
| **Repository Secrets** | Encrypted at rest by GitHub, injected as environment variables at runtime | Current approach — simplest, adequate for a private repo with a small pipeline surface |
| **Environment Secrets + Required Reviewers** | Secrets scoped to a named GitHub *Environment* (e.g. `production`), with mandatory human approval before the job can access them | Recommended before this pattern touches a client's production Snowflake account |
| **External Secrets Manager (AWS Secrets Manager / HashiCorp Vault)** | Pipeline authenticates once (via OIDC) to fetch short-lived secrets from a vault, rather than storing them directly in GitHub | Recommended for large enterprise clients with existing centralized secrets infrastructure |
| **No Secrets at All (OIDC end-to-end)** | Both the AWS and Snowflake links use workload identity federation — nothing sensitive is stored anywhere | The end-state goal — removes secret storage from the equation entirely |

---

## Authorization-as-Code (Snowflake RBAC via Terraform)

Authentication proves *who* the pipeline is; authorization determines *what it
is allowed to build*. In a DataOps model, authorization is not click-ops — it
is version-controlled, reviewed in pull requests, and applied identically
across environments.

| Mechanism | Purpose | How it's expressed in this repo |
|---|---|---|
| **Provider Role Separation** | The pipeline itself uses 3 different Snowflake roles depending on the operation type | `providers.tf` — default `SYSADMIN`, alias `useradmin`, alias `securityadmin` |
| **Functional Account Roles** | Business-facing roles reflecting job function, not individual people | `roles.tf` — `DEV_DATA_ENGINEER`, `DEV_DATA_ANALYST`, `DEV_DATA_CONSUMER`, `DEV_DBT_RUNNER` |
| **Role Hierarchy** | Every functional role is granted upward to `SYSADMIN`, so ownership/visibility is never orphaned | `snowflake_grant_account_role.functional_to_sysadmin` |
| **Grants-as-Code** | Every `USAGE`/`SELECT`/`INSERT` privilege is declared in Terraform, not issued manually | `grants.tf` — warehouse, database, schema, and table-level grants per role |
| **Column Masking / Row Access Policies** | PII protection and row-level filtering, declared and version-controlled like any other resource | `masking.tf`, `row_access.tf` — currently placeholders, pending client-confirmed rules |
| **Drift Detection** | Any manual change made outside Terraform is surfaced on the next `terraform plan`, not silently accepted | Built into every CI/CD pipeline run automatically |

---

## Environment Promotion & Change Control

DataOps extends authorization across environments, not just within one account:

| Practice | Description |
|---|---|
| **Environment-prefixed naming** | `DEV_`, `QA_`, `PROD_` — same Terraform code, different `var.environment` value, zero copy-pasted SQL |
| **Per-environment state isolation** | Each environment has its own Terraform state file (`workload/dev/`, `workload/qa/`, `workload/prod/`) so a `dev` mistake cannot corrupt `prod` |
| **Plan-before-apply on every PR** | `terraform plan` output is posted as a PR comment — reviewers see exactly what will change in Snowflake before approving |
| **Environment-gated apply** | (Recommended) `prod` applies require a named GitHub Environment with required reviewers, independent of who has repo write access |

---

## What We Implemented in This POC

| Link in the Chain | Method Chosen | Why |
|---|---|---|
| Pipeline → AWS | **IAM User + static Access Keys** | Fastest to stand up for a sandbox; proves the full pipeline end-to-end before investing in OIDC trust setup |
| Pipeline → Snowflake | **RSA Key-Pair (`SNOWFLAKE_JWT`)**, dedicated `TERRAFORM_SVC` service user | No password/MFA blocking automation; Snowflake's documented pattern for Terraform-driven service accounts |
| Secrets storage | **GitHub Repository Secrets** | Adequate for a private, single-team POC repository |
| Authorization inside Snowflake | **3 provider role aliases + 4 functional account roles, all grants declared in Terraform** | Least-privilege by function; every permission change is a reviewable diff |
| Environment strategy | **Single Snowflake account, environment-prefixed objects, per-environment Terraform state** | Matches the client's actual Snowflake trial account topology; ready to extend to `qa`/`prod` without restructuring |

---

## What We Recommend for Production

| Recommendation | Reason |
|---|---|
| **Migrate Pipeline → AWS to OIDC (`AssumeRoleWithWebIdentity`)** | Eliminates the long-lived AWS Access Key from GitHub Secrets |
| **Migrate Pipeline → Snowflake to OIDC (`WORKLOAD_IDENTITY`)** | Eliminates the long-lived RSA private key from GitHub Secrets |
| **Move to GitHub Environment secrets with required reviewers for `prod`** | Adds a human approval gate independent of authentication method |
| **Replace placeholder masking/RLS policies with real client-confirmed rules** | Currently no-op; PII/row-level rules pending `Questionnaire.md` answers |
| **Add Resource Monitors per warehouse** | Caps compute spend regardless of who/what is authorized to run queries |
| **Consider an external secrets manager if the client already runs one** | Avoids duplicating secret storage/rotation tooling the client has already standardized on |

---

## Demo Talking Points

1. **Show the trust chain diagram** — one pipeline run, two independent authentications (AWS + Snowflake), zero human credentials involved.
2. **Show GitHub Secrets (names only, values hidden)** — explain these are exactly the secrets the "What We Recommend" table proposes eliminating next.
3. **Show `providers.tf` and `roles.tf`** — explain that even the pipeline's own Snowflake access is split across 3 roles by operation type, mirroring least-privilege principles a security team will recognize immediately.
4. **Trigger a live pipeline run** — merge a trivial change, show the PR's plan comment, then show the apply creating/updating the real Snowflake object.
5. **Close with the Decision Matrix** — this is the "where we are vs. where we're going" slide.

---

## Decision Matrix Summary

| Criterion | Static Keys (used today) | OIDC / Workload Identity (recommended next) |
|---|---|---|
| Secret stored long-term? | Yes (GitHub Secrets) | No |
| Requires manual rotation? | Yes | No — tokens expire automatically per run |
| Blast radius if GitHub repo is compromised | High — attacker gets a reusable credential | Low — token is short-lived and scoped to repo/branch |
| One-time setup effort | Low | Moderate (IAM OIDC provider + trust policy; Snowflake `WORKLOAD_IDENTITY`) |
| Snowflake CLI version required | Any | ≥ 3.11 |
| Fits this POC's delivery timeline | ✅ Yes | Planned as the next hardening phase |
| Recommended before client production use | ❌ No | ✅ Yes |
