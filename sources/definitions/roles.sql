-- Tiered RBAC model (persona -> functional -> database/warehouse access roles), scoped to the
-- Customer domain, inspired by the infra-platform reference template's Tier 1-4 convention.
-- Database roles (Tier 3) are defined in database_roles.sql since DCM scopes
-- `DEFINE DATABASE ROLE` per-database. Composition lives in grants.sql.
--
-- Account roles, distinct from the CI/CD bootstrap roles that stay in Terraform
-- (GITHUB_DEV_TERRAFORM_SVC / GITHUB_DEV_DCM_SVC identities in oidc_service_user.tf).
--
-- Warehouses (DEV_INGEST_WH/DEV_TRANSFORM_WH/DEV_REPORTING_WH) are account-level shared
-- compute, not domain-specific — a second domain would reuse these same warehouses rather
-- than provisioning its own, so the Tier 4 warehouse roles below are not CUSTOMER-prefixed.

-- Tier 1: persona roles — granted to actual users/service identities
DEFINE ROLE DEV_CUSTOMER_DATA_ENGINEER_PRSN
  COMMENT = 'Tier 1 persona: engineers who land and maintain Customer domain RAW data';

DEFINE ROLE DEV_CUSTOMER_DATA_ANALYST_PRSN
  COMMENT = 'Tier 1 persona: analysts who query Customer domain curated marts';

DEFINE ROLE DEV_CUSTOMER_DATA_CONSUMER_PRSN
  COMMENT = 'Tier 1 persona: downstream/BI consumers of Customer domain curated marts';

DEFINE ROLE DEV_CUSTOMER_DBT_SERVICE_PRSN
  COMMENT = 'Tier 1 persona: the dbt service identity (Repo 3, customer-domain-dbt) that runs Customer domain transformations';

DEFINE ROLE DEV_CUSTOMER_INGEST_SERVICE_PRSN
  COMMENT = 'Tier 1 persona: the Snowpipe ingestion service identity (Repo 2, data-ingestion-raw) that loads Customer domain RAW data';

-- Tier 2: functional roles — capability-oriented, composed from Tier 3 (database) and
-- Tier 4 (warehouse) roles in grants.sql
DEFINE ROLE DEV_CUSTOMER_INGEST_FNCRL
  COMMENT = 'Tier 2 functional: land data into Customer domain RAW';

DEFINE ROLE DEV_CUSTOMER_TRANSFORM_FNCRL
  COMMENT = 'Tier 2 functional: read RAW/SHARED, read-write STAGING for the Customer domain';

DEFINE ROLE DEV_CUSTOMER_READER_FNCRL
  COMMENT = 'Tier 2 functional: read Customer domain curated MARTS';

-- Tier 4: warehouse roles — USAGE -> MONITOR -> OPERATE, chained in grants.sql. Account-level
-- shared compute, so these are not domain-prefixed.
DEFINE ROLE DEV_INGEST_WH_WHRL_U
  COMMENT = 'Tier 4 warehouse: USAGE on DEV_INGEST_WH';
DEFINE ROLE DEV_INGEST_WH_WHRL_M
  COMMENT = 'Tier 4 warehouse: MONITOR on DEV_INGEST_WH (includes USAGE)';
DEFINE ROLE DEV_INGEST_WH_WHRL_O
  COMMENT = 'Tier 4 warehouse: OPERATE on DEV_INGEST_WH (includes MONITOR+USAGE)';

DEFINE ROLE DEV_TRANSFORM_WH_WHRL_U
  COMMENT = 'Tier 4 warehouse: USAGE on DEV_TRANSFORM_WH';
DEFINE ROLE DEV_TRANSFORM_WH_WHRL_M
  COMMENT = 'Tier 4 warehouse: MONITOR on DEV_TRANSFORM_WH (includes USAGE)';
DEFINE ROLE DEV_TRANSFORM_WH_WHRL_O
  COMMENT = 'Tier 4 warehouse: OPERATE on DEV_TRANSFORM_WH (includes MONITOR+USAGE)';

DEFINE ROLE DEV_REPORTING_WH_WHRL_U
  COMMENT = 'Tier 4 warehouse: USAGE on DEV_REPORTING_WH';
DEFINE ROLE DEV_REPORTING_WH_WHRL_M
  COMMENT = 'Tier 4 warehouse: MONITOR on DEV_REPORTING_WH (includes USAGE)';
DEFINE ROLE DEV_REPORTING_WH_WHRL_O
  COMMENT = 'Tier 4 warehouse: OPERATE on DEV_REPORTING_WH (includes MONITOR+USAGE)';
