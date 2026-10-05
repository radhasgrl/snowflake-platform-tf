-- Customer domain schemas — one database (DEV_CUSTOMER_DB), layered by schema, matching the
-- infra-platform reference template's per-domain schema set (STAGING/MARTS/SHARED), with RAW
-- added as this domain's landing zone for Repo 2's Snowpipe ingestion.
DEFINE SCHEMA DEV_CUSTOMER_DB.RAW
  COMMENT = 'Landing zone for Snowpipe ingestion (Repo 2, data-ingestion-raw)';

DEFINE SCHEMA DEV_CUSTOMER_DB.STAGING
  COMMENT = 'Intermediate dbt models (Repo 3, customer-domain-dbt)';

DEFINE SCHEMA DEV_CUSTOMER_DB.MARTS
  COMMENT = 'Final business-facing data marts for the Customer domain';

DEFINE SCHEMA DEV_CUSTOMER_DB.SHARED
  COMMENT = 'Shared UDFs, procedures and reference data for the Customer domain';
