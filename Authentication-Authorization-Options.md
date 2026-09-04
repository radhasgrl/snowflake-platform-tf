# Authentication & Authorization Options — Greenfield Snowflake Platform

A reference guide for presenting the available authentication and authorization
approaches for this platform, what we implemented in this proof-of-concept, and
why — intended as source material for a client-facing deck.

---

## Table of Contents

1. [Why This Matters](#why-this-matters)
2. [Authentication Options — Snowflake](#authentication-options--snowflake)
3. [Authentication Options — AWS](#authentication-options--aws)
4. [Authentication Options — GitHub Actions → Cloud](#authentication-options--github-actions--cloud)
5. [Authorization Options — Snowflake RBAC](#authorization-options--snowflake-rbac)
6. [What We Implemented in This POC](#what-we-implemented-in-this-poc)
7. [What We Recommend for Production](#what-we-recommend-for-production)
8. [Demo Talking Points](#demo-talking-points)
9. [Decision Matrix Summary](#decision-matrix-summary)

---

## Why This Matters

Every credential in this platform answers two questions:

- **Authentication (AuthN):** *"Who — or what — is this?"*
- **Authorization (AuthZ):** *"What is this identity allowed to do?"*

A DataOps platform has three authentication boundaries that all need answering
independently:

```
Human developer  →  GitHub           (AuthN: how does a person log into GitHub?)
GitHub Actions    →  AWS              (AuthN: how does a pipeline get AWS access?)
GitHub Actions    →  Snowflake        (AuthN: how does a pipeline get Snowflake access?)
Snowflake role    →  Snowflake object (AuthZ: what can a role see/change?)
```

This document walks through the realistic options for each boundary, market
practice, and what this proof-of-concept currently uses.

---

## Authentication Options — Snowflake

| Method | How it works | Best for | Trade-offs |
|---|---|---|---|
| **Username + Password** | Static credential, entered manually | Legacy / individual dev accounts | No MFA by default; password rotation burden; not suitable for automation |
| **Password + MFA (Duo)** | Password + push/TOTP second factor | Human interactive users | Strong for humans; not usable for CI/CD (no human to approve push) |
| **RSA Key-Pair (`SNOWFLAKE_JWT`)** | Public key registered on a Snowflake user; private key signs a JWT locally | Service accounts, CI/CD, Terraform | No password to leak; key rotation is a manual process; private key is still a long-lived secret that must be stored somewhere |
| **OAuth (Snowflake native / external IdP)** | Snowflake acts as an OAuth client or resource server; token-based | Application-to-Snowflake integrations (BI tools, custom apps) | Requires an OAuth integration object; more setup, but no shared secrets in application code |
| **SAML 2.0 / SSO** | Snowflake trusts an external Identity Provider (Okta, Azure AD, Ping) for human logins | Enterprise human users | Centralizes login/offboarding in the IdP; requires enterprise IdP already in place |
| **SCIM Provisioning** | Automated user/role lifecycle sync from IdP to Snowflake | Enterprise user lifecycle management | Removes manual `CREATE USER`/`DROP USER`; requires SCIM-capable IdP integration |
| **Workload Identity Federation (OIDC)** | CI/CD platform (GitHub/GitLab/Azure DevOps) issues a short-lived signed token; Snowflake validates issuer + subject claims — **no stored secret at all** | CI/CD pipelines (the modern recommended approach) | Newest method; requires `WORKLOAD_IDENTITY` support (Snowflake CLI ≥ 3.11); most secure option for pipelines |
| **Programmatic Access Tokens (PAT)** | Snowflake-issued token scoped to a user, with expiry | API/script access without a full key pair | Simpler than key-pair for short-lived scripts; still a bearer secret |

---

## Authentication Options — AWS

| Method | How it works | Best for | Trade-offs |
|---|---|---|---|
| **IAM User + Static Access Keys** | Long-lived Access Key ID + Secret Access Key | Legacy CI/CD, quick setup | Long-lived secret in GitHub Secrets; must be rotated manually; highest risk if leaked |
| **IAM Role + `AssumeRole`** | A trusted principal assumes a role for temporary credentials | Cross-account access, EC2/ECS workloads | Needs a trust policy; still requires an initial credential to call `AssumeRole` unless federated |
| **GitHub OIDC → IAM Role (`AssumeRoleWithWebIdentity`)** | GitHub issues a short-lived OIDC token; AWS IAM trusts GitHub's OIDC provider and hands out temporary credentials | CI/CD pipelines (AWS's recommended approach) | No stored AWS secret in GitHub at all; tokens expire in ~1 hour; requires one-time IAM OIDC provider + role setup |
| **AWS SSO / IAM Identity Center** | Centralized human access across multiple AWS accounts via an IdP | Human console/CLI access | Not applicable to unattended CI/CD pipelines |
| **Instance Profile / Task Role** | AWS compute (EC2, ECS, Lambda) assumes a role automatically | Workloads running inside AWS | Not applicable here — our pipeline runs on GitHub-hosted runners, not inside AWS |

---

## Authentication Options — GitHub Actions → Cloud

| Method | Used for | Notes |
|---|---|---|
| **Repository Secrets (static)** | Storing AWS keys / Snowflake private key today | Simple, but a real secret persists in GitHub until rotated |
| **GitHub OIDC token (`id-token: write`)** | Federating to AWS IAM and/or Snowflake `WORKLOAD_IDENTITY` | No stored secret; token scoped to `repo:org/repo:ref:refs/heads/main` (or similar) — an attacker without repo/branch access cannot mint a valid token |
| **Environment-scoped secrets + required reviewers** | Adding human approval gates before `prod` deploys | Works with either static secrets or OIDC; recommended regardless of auth method for production environments |
| **Self-hosted runners** | Running inside the client's private network (no public runner) | Needed if Snowflake/AWS resources are not reachable from public internet (e.g. PrivateLink only) |

---

## Authorization Options — Snowflake RBAC

Authentication answers "who is this?" — authorization answers "what can they do?"
Snowflake's model is entirely role-based:

| Mechanism | Purpose | Example in this platform |
|---|---|---|
| **Account Roles** | Named permission bundles, hierarchical (roles can be granted to other roles) | `DEV_DATA_ENGINEER`, `DEV_DATA_ANALYST`, `DEV_DATA_CONSUMER`, `DEV_DBT_RUNNER` |
| **System Roles** | Built-in top-level roles: `ACCOUNTADMIN`, `SYSADMIN`, `SECURITYADMIN`, `USERADMIN` | Used as the *provider identity* per operation type (least privilege) |
| **Database Roles** | Roles scoped to a single database (share-friendly, finer-grained) | Not yet used — candidate for multi-tenant data sharing scenarios |
| **Grants (`GRANT ... TO ROLE`)** | Attach specific privileges (`USAGE`, `SELECT`, `CREATE TABLE`, etc.) to a role, on a specific object | Warehouse/database/schema/table grants per functional role |
| **Column Masking Policies** | Dynamically redact/mask column values based on the querying role | Placeholder policy created; real PII rules pending client input |
| **Row Access Policies** | Dynamically filter which rows a role can see | Placeholder policy created; real RLS rules pending client input |
| **Network Policies** | Restrict which IP ranges/VPNs can connect at all, regardless of role | Not yet implemented — recommended before production |
| **Resource Monitors** | Cap compute spend per warehouse/account, independent of RBAC | Not yet implemented — recommended for cost governance |

---

## What We Implemented in This POC

| Boundary | Method Chosen | Why |
|---|---|---|
| Human → GitHub | Standard GitHub login (existing corporate GitHub account) | Already governed by the organization's existing GitHub policies |
| GitHub Actions → AWS | **IAM User + static Access Keys** (stored as GitHub Secrets) | Fastest to stand up for a sandbox/demo; proves the integration end-to-end |
| GitHub Actions → Snowflake | **RSA Key-Pair (`SNOWFLAKE_JWT`)** via a dedicated service user (`TERRAFORM_SVC`) | No password, no MFA prompt blocking automation; Snowflake's own quickstart-recommended method for Terraform service accounts |
| Snowflake → Object access | **Account Roles + Grants**, environment-prefixed (`DEV_`, `QA_`, `PROD_`), 4 functional roles granted to `SYSADMIN` | Least-privilege by function (engineer/analyst/consumer/dbt), fully declared in Terraform, auditable via git history |
| Terraform → Snowflake privilege separation | **3 provider aliases** (`SYSADMIN`, `USERADMIN`, `SECURITYADMIN`) | Matches Snowflake's built-in separation of duties — data objects, identity objects, and security objects are managed by different roles even within one Terraform run |

**Why static keys instead of OIDC in this POC:** speed of initial delivery. Both
AWS and Snowflake support OIDC-based workload identity federation, and this is
the next planned hardening step (tracked as a parked phase) before this pattern
is used for the client's production account.

---

## What We Recommend for Production

| Recommendation | Reason |
|---|---|
| **Migrate GitHub Actions → AWS to OIDC (`AssumeRoleWithWebIdentity`)** | Removes long-lived AWS keys from GitHub Secrets entirely |
| **Migrate GitHub Actions → Snowflake to OIDC (`WORKLOAD_IDENTITY`)** | Removes the long-lived RSA private key from GitHub Secrets entirely |
| **Enable SSO (SAML) for all human Snowflake logins** | Centralizes login/MFA/offboarding in the client's existing IdP (Okta / Azure AD / Ping) |
| **Enable SCIM provisioning from the IdP** | Automates role assignment and de-provisioning when staff join/leave — no manual `CREATE USER`/`DROP USER` |
| **Add Network Policies scoped to corporate IP ranges or PrivateLink** | Blocks Snowflake login attempts from outside approved networks, independent of credential compromise |
| **Add Resource Monitors per warehouse** | Prevents runaway compute spend regardless of who is authorized |
| **Replace placeholder masking/RLS with real policies** | Pending the client's answers on PII columns and row-level access rules (see `Questionnaire.md`) |
| **Environment-scoped GitHub deployment approvals for `prod`** | Adds a human approval gate before any production apply, regardless of auth method |

---

## Demo Talking Points

Use this structure when presenting to the client:

1. **"Here are all the ways this could be done"** — walk the three option tables above; this shows breadth of knowledge and that choices were deliberate, not accidental.
2. **"Here is what we picked for the proof-of-concept, and why"** — walk the *What We Implemented* table; emphasize speed-to-demo without compromising the core principle (no passwords, no shared human credentials, everything Terraform-declared).
3. **"Here is the upgrade path to production-grade security"** — walk the *What We Recommend* table; this shows the team already knows the gap between "POC-ready" and "enterprise production-ready" and has a plan to close it.
4. **Live demo** — show the RSA key-pair authentication working (`TERRAFORM_SVC` user, no password in Snowflake), show the GitHub Secrets page (values hidden, names only), and show a live pipeline run authenticating and applying changes end-to-end.

---

## Decision Matrix Summary

| Criterion | Static Keys (used today) | OIDC / Workload Identity (recommended next) |
|---|---|---|
| Secret stored long-term? | Yes | No |
| Requires manual rotation? | Yes | No — tokens expire automatically |
| Blast radius if GitHub is compromised | High — attacker gets a reusable credential | Low — token is short-lived and scoped to repo/branch |
| Setup complexity | Low | Moderate (one-time IdP trust configuration) |
| Snowflake CLI version required | Any | ≥ 3.11 |
| Fits this POC's timeline | ✅ Yes | Planned as next hardening step |
| Recommended for client production | ❌ No | ✅ Yes |
