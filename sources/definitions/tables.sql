-- The RAW table that data-ingestion-raw (Repo 2, Snowpipe) will load into, and that
-- customer-domain-dbt (Repo 3) will read as its source.
DEFINE TABLE DEV_CUSTOMER_DB.RAW.CUSTOMERS (
  CUSTOMER_ID NUMBER COMMENT 'Unique customer identifier',
  CUSTOMER_NAME VARCHAR COMMENT 'Customer display name'
)
COMMENT = 'Raw landing table for customer records, loaded by the Snowpipe ingestion pipeline';
