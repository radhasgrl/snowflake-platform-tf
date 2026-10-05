-- Tier 3: database roles — schema-scoped read/write within the Customer domain database,
-- composed into Tier 2 functional roles in grants.sql. `DEFINE DATABASE ROLE` is scoped
-- per-database, so these live in their own file separate from the Tier 1/2/4 account roles
-- in roles.sql.

DEFINE DATABASE ROLE DEV_CUSTOMER_DB.RAW_SCRL_R
  COMMENT = 'Tier 3 database role: read-only on CUSTOMER.RAW';
DEFINE DATABASE ROLE DEV_CUSTOMER_DB.RAW_SCRL_W
  COMMENT = 'Tier 3 database role: read-write on CUSTOMER.RAW (includes read)';

DEFINE DATABASE ROLE DEV_CUSTOMER_DB.STAGING_SCRL_R
  COMMENT = 'Tier 3 database role: read-only on CUSTOMER.STAGING';
DEFINE DATABASE ROLE DEV_CUSTOMER_DB.STAGING_SCRL_W
  COMMENT = 'Tier 3 database role: read-write on CUSTOMER.STAGING (includes read)';

DEFINE DATABASE ROLE DEV_CUSTOMER_DB.MARTS_SCRL_R
  COMMENT = 'Tier 3 database role: read-only on CUSTOMER.MARTS';
DEFINE DATABASE ROLE DEV_CUSTOMER_DB.MARTS_SCRL_W
  COMMENT = 'Tier 3 database role: read-write on CUSTOMER.MARTS (includes read) - dbt builds dim_customers here';

DEFINE DATABASE ROLE DEV_CUSTOMER_DB.SHARED_SCRL_R
  COMMENT = 'Tier 3 database role: read-only on CUSTOMER.SHARED (shared UDFs/procedures)';
