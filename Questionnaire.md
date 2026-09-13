# Client Engagement — Demo Guide & Questionnaire

Snowflake DataOps Platform | Terraform + GitHub Actions + AWS

---

## Demo Flow (Total: ~25 min)

### 1. Start with the "Why" — Architecture First *(2 min)*

Open the README on GitHub at `github.com/radhasgrl/snowflake-platform-tf` and walk through the architecture diagram.

**Key message to deliver:**
> *"Everything Snowflake touches — databases, schemas, warehouses, roles, policies — is declared as code. No one clicks in the UI. Changes go through a Pull Request, get a plan, get reviewed, then merge triggers the apply."*

---

### 2. GitHub — Show the Developer Workflow *(5 min)*

Navigate to `github.com/radhasgrl/snowflake-platform-tf` and walk through:

| What to show | Talking point |
|---|---|
| **Settings → Secrets and variables → Actions** | Show all 5 secrets are set, values hidden — *"Two of these (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) are already unused — the pipeline now authenticates to AWS via OIDC with zero stored credentials"* |
| **Actions tab** | Open a successful `terraform-apply.yml` run, point out the "Configure AWS credentials (OIDC)" and "Fetch Snowflake OIDC token" steps — *"No secret was read for either of these"* |
| **`.github/workflows/terraform-apply.yml`** | *"This file is what runs automatically on every merge to main — and it's the one we've already hardened to OIDC"* |

---

### 3. Terraform Code — The Single Source of Truth *(10 min)*

Walk through files in this order:

```
bootstrap/                    →  "One-time setup — creates the S3 state bucket in Sydney (ap-southeast-2)"
aws-oidc-bootstrap/            →  "One-time, human-applied — creates the AWS OIDC provider + IAM role"

terraform.tf                  →  "Version pin + partial S3 backend — state is remote, encrypted, versioned"
providers.tf                  →  "Three provider aliases, all hardcoded to GitHub OIDC workload identity — no key-pair fallback anywhere in the repo"
context.tf / locals.tf        →  "environment variable drives all naming — DEV_, QA_, PROD_"
databases.tf / schemas.tf     →  "Core Snowflake objects — databases and schemas"
warehouses.tf                 →  "Compute — environment-sized warehouses, auto-suspend by default"
roles.tf / grants.tf          →  "RBAC — functional roles and every privilege declared as code"
masking.tf / row_access.tf    →  "Security policy pattern — wired up now, real rules pending client input"
oidc_service_user.tf          →  "The OIDC identity the apply workflow authenticates as — no password, no key file"
env/dev/ (dev.tfvars + backend.hcl)  →  "Per-environment config — same code, different environment"
```

**Key message to deliver on `databases.tf`/`warehouses.tf`:**
> *"One variable change — `environment = prod` — and this entire stack provisions a production-grade Snowflake environment with correctly sized warehouses. No human intervention."*

---

### 4. AWS — Show the State *(3 min)*

Open the S3 console:
`https://ap-southeast-2.console.aws.amazon.com/s3/buckets/snowflake-platform-tf-state-525218385225`

| What to show | Talking point |
|---|---|
| `foundation/terraform.tfstate` file | *"Terraform's record of everything it has created"* |
| Version history of the state file | *"Every apply creates a new version — we can roll back to any point in time"* |
| Bucket properties | Encryption (AES256) and public access blocked |

---

### 5. Snowflake — Show the Result *(5 min)*

Open the Snowflake UI and navigate to:

| What to show | Talking point |
|---|---|
| **Data → Databases** | `DEV_LANDING_DB`, `DEV_ANALYTICS_DB`, `DEV_COMMON_DB` and their schemas |
| **Admin → Warehouses** | 3 DEV warehouses, all SUSPENDED (correct — they start on demand) |
| **Admin → Users** | `GITHUB_OIDC_TERRAFORM_SVC` / `GITHUB_OIDC_TERRAFORM_PLAN_SVC` — *"Service accounts, no password, no key file — GitHub's OIDC token is the only credential"* |
| **Admin → Roles** | `DEV_DATA_ENGINEER`, `DEV_DATA_ANALYST`, `DEV_DATA_CONSUMER`, `DEV_DBT_RUNNER` — *"Every grant is declared in Terraform, not clicked"* |
| Masking/Row Access policies (SQL: `SHOW MASKING POLICIES`, `SHOW ROW ACCESS POLICIES`) | *"The security policy pattern is wired up — the real rules are pending your answers to the questionnaire below"* |

**Closing message:**
> *"None of this was clicked. It was all applied by the pipeline when code merged to main."*

---

## Client Questionnaire

Use these questions before designing the greenfield platform.
Capture answers before any architecture decisions are made.

---

### Snowflake

| # | Question | Why it matters |
|---|---|---|
| 1 | Single Snowflake account or separate accounts per environment (dev/prod)? | Changes the entire Terraform folder and state structure |
| 2 | Existing naming conventions for databases, schemas, and warehouses? | Cannot rename after data is loaded |
| 3 | How many source systems / data domains will be onboarded? | Drives the number of databases and schemas |
| 4 | What environments are required? (Dev / QA / UAT / Prod?) | Determines the environment-prefix strategy |
| 5 | Are there existing Snowflake objects that must be brought under Terraform? | `terraform import` is required before Terraform can manage them |
| 6 | Any data residency requirements? (country, cloud region?) | Determines Snowflake cloud + region selection and AWS region for state |
| 7 | Which BI tool is in use? (Tableau, Power BI, Looker, ThoughtSpot?) | Drives `REPORTING_WH` sizing and dedicated service account needs |
| 8 | Is dbt in use today? Which version? Cloud or Core? | Determines scope of Phase 6 integration |

---

### RBAC / Security

| # | Question | Why it matters |
|---|---|---|
| 9 | What functional roles are needed? (Analyst, Engineer, Consumer, Admin?) | Drives the entire role hierarchy design |
| 10 | Which columns or tables contain PII or sensitive data? | Defines the scope of column masking policies |
| 11 | Is row-level security required? (e.g. region-based or team-based data access?) | Determines row access policy design and mapping tables |
| 12 | How are users provisioned today? (Active Directory / LDAP / SSO / SCIM / manual?) | SCIM integration vs Terraform-managed users |
| 13 | Are there compliance or audit requirements? (SOC 2, HIPAA, GDPR, ISO 27001?) | Drives query history retention, `ACCOUNT_USAGE` logging, data classification |
| 14 | Who owns role changes — the platform team or individual business units? | Determines governance model and approval workflow |

---

### AWS / Infrastructure

| # | Question | Why it matters |
|---|---|---|
| 15 | Single AWS account or multi-account landing zone (Control Tower / Organizations)? | Determines where the S3 state bucket and IAM roles live |
| 16 | Are there existing IAM Service Control Policies (SCPs) that restrict actions? | SCPs may block what the Terraform IAM user can do |
| 17 | Can GitHub Actions use OIDC to assume an IAM role (instead of static keys)? | Eliminates long-lived credentials and secret rotation risk |
| 18 | Is VPC / AWS PrivateLink to Snowflake required? | Changes the Snowflake account URL and network configuration |
| 19 | Which AWS region is the primary region for the client? | State bucket, DynamoDB lock, and all AWS resources must align |

---

### GitHub / CI/CD

| # | Question | Why it matters |
|---|---|---|
| 20 | GitHub Enterprise (self-hosted) or GitHub Cloud? | Affects runner setup, OIDC trust configuration, and SSO |
| 21 | Self-hosted runners or GitHub-hosted runners? | Self-hosted runners need network access to Snowflake and AWS |
| 22 | Are branch protection rules and approval gates required on main? | Enforces plan-before-apply and mandatory reviewer workflow |
| 23 | Multiple teams or multiple repos contributing to the platform? | Drives Terraform module strategy and state isolation per team |
| 24 | Existing CI/CD tooling beyond GitHub Actions? (Jenkins, Azure DevOps, Harness?) | May require pipeline adapters or parallel toolchain |
| 25 | Does the client's AWS account already have a GitHub OIDC identity provider configured (from another project)? | Avoids creating a duplicate/conflicting OIDC provider when migrating off static IAM keys |
| 26 | Who holds `ACCOUNTADMIN` access in Snowflake to create a new `WORKLOAD_IDENTITY` service user? | This one-time setup step cannot be done by Terraform — needs a named human owner |
| 27 | Is a change-freeze or formal approval process required before modifying how the pipeline authenticates to production systems? | OIDC migration changes the trust boundary of every future deployment |
| 28 | Should each environment (dev/qa/prod) have its own scoped trust identity, or is one shared identity acceptable? | Determines whether OIDC migration needs one IAM role/Snowflake user per environment, or just one overall |

---

## What to Emphasise for a Large Client

| Point | What to say |
|---|---|
| **It scales** | Adding a new data domain is one `snowflake_database` + `snowflake_schema` block. No tickets, no manual work. |
| **RBAC is implemented** | Phase 5 roles, grants, and the masking/row-access policy pattern are live and Terraform-managed — real PII/RLS rules are the only piece pending your answers above. |
| **Environment promotion is code** | `QA_` and `PROD_` environments are created by changing one variable — not by repeating manual steps across environments. |
| **State is the safety net** | Terraform knows exactly what exists in Snowflake. Any manual change made outside Terraform is detected on the next `plan`. |
| **No credentials in code** | No private keys, no AWS access keys — both AWS and Snowflake authenticate the pipeline via short-lived GitHub OIDC tokens. Only non-secret account identifiers live in GitHub Secrets. |
