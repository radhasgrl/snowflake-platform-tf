-- Customer domain database. One database per domain (matching the infra-platform reference
-- template's <DOMAIN>_<ENV> convention), holding every data layer (raw/staging/marts/shared)
-- for this domain. A later second domain would get its own DEV_<DOMAIN>_DB, not a shared one.
DEFINE DATABASE DEV_CUSTOMER_DB
  COMMENT = 'Customer domain — raw, staging, marts and shared objects for this domain';
