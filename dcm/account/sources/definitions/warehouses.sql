-- Account-level, shared compute — not domain-specific. Every domain's functional roles
-- reference these same warehouse roles (see grants.sql's warehouse_grants) rather than each
-- domain provisioning its own. Parameterized only by `env` (for future QA/PROD promotion),
-- never by `domain`.
--
-- NOTE: these objects are currently deployed via the same single DCM project as the first
-- onboarded domain (see dcm/domains/customer/manifest.yml) because splitting them into a
-- genuinely separate account-level DCM project requires safely re-homing already-DCM-managed
-- objects between projects — deferred until that's verified safe (planned for when the
-- second domain is onboarded). This file's *content* is already domain-independent; only
-- *which project deploys it* is still shared with Customer's project for now.

DEFINE WAREHOUSE {{ env }}_INGEST_WH
  WAREHOUSE_SIZE = 'XSMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Data loading and ingestion workloads';

DEFINE WAREHOUSE {{ env }}_TRANSFORM_WH
  WAREHOUSE_SIZE = 'XSMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND = 120
  AUTO_RESUME = TRUE
  COMMENT = 'dbt transformations and ELT workloads';

DEFINE WAREHOUSE {{ env }}_REPORTING_WH
  WAREHOUSE_SIZE = 'XSMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'BI tools and ad-hoc reporting queries';

-- Tier 4: warehouse access roles (USAGE -> MONITOR -> OPERATE), one trio per warehouse.
DEFINE ROLE {{ env }}_INGEST_WH_WHRL_U
  COMMENT = 'Tier 4 warehouse: USAGE on {{ env }}_INGEST_WH';
DEFINE ROLE {{ env }}_INGEST_WH_WHRL_M
  COMMENT = 'Tier 4 warehouse: MONITOR on {{ env }}_INGEST_WH (includes USAGE)';
DEFINE ROLE {{ env }}_INGEST_WH_WHRL_O
  COMMENT = 'Tier 4 warehouse: OPERATE on {{ env }}_INGEST_WH (includes MONITOR+USAGE)';

DEFINE ROLE {{ env }}_TRANSFORM_WH_WHRL_U
  COMMENT = 'Tier 4 warehouse: USAGE on {{ env }}_TRANSFORM_WH';
DEFINE ROLE {{ env }}_TRANSFORM_WH_WHRL_M
  COMMENT = 'Tier 4 warehouse: MONITOR on {{ env }}_TRANSFORM_WH (includes USAGE)';
DEFINE ROLE {{ env }}_TRANSFORM_WH_WHRL_O
  COMMENT = 'Tier 4 warehouse: OPERATE on {{ env }}_TRANSFORM_WH (includes MONITOR+USAGE)';

DEFINE ROLE {{ env }}_REPORTING_WH_WHRL_U
  COMMENT = 'Tier 4 warehouse: USAGE on {{ env }}_REPORTING_WH';
DEFINE ROLE {{ env }}_REPORTING_WH_WHRL_M
  COMMENT = 'Tier 4 warehouse: MONITOR on {{ env }}_REPORTING_WH (includes USAGE)';
DEFINE ROLE {{ env }}_REPORTING_WH_WHRL_O
  COMMENT = 'Tier 4 warehouse: OPERATE on {{ env }}_REPORTING_WH (includes MONITOR+USAGE)';

-- Tier 4 hierarchy (U -> M -> O) + privilege grants
GRANT ROLE {{ env }}_INGEST_WH_WHRL_U TO ROLE {{ env }}_INGEST_WH_WHRL_M;
GRANT ROLE {{ env }}_INGEST_WH_WHRL_M TO ROLE {{ env }}_INGEST_WH_WHRL_O;
GRANT USAGE ON WAREHOUSE {{ env }}_INGEST_WH TO ROLE {{ env }}_INGEST_WH_WHRL_U;
GRANT MONITOR ON WAREHOUSE {{ env }}_INGEST_WH TO ROLE {{ env }}_INGEST_WH_WHRL_M;
GRANT OPERATE ON WAREHOUSE {{ env }}_INGEST_WH TO ROLE {{ env }}_INGEST_WH_WHRL_O;

GRANT ROLE {{ env }}_TRANSFORM_WH_WHRL_U TO ROLE {{ env }}_TRANSFORM_WH_WHRL_M;
GRANT ROLE {{ env }}_TRANSFORM_WH_WHRL_M TO ROLE {{ env }}_TRANSFORM_WH_WHRL_O;
GRANT USAGE ON WAREHOUSE {{ env }}_TRANSFORM_WH TO ROLE {{ env }}_TRANSFORM_WH_WHRL_U;
GRANT MONITOR ON WAREHOUSE {{ env }}_TRANSFORM_WH TO ROLE {{ env }}_TRANSFORM_WH_WHRL_M;
GRANT OPERATE ON WAREHOUSE {{ env }}_TRANSFORM_WH TO ROLE {{ env }}_TRANSFORM_WH_WHRL_O;

GRANT ROLE {{ env }}_REPORTING_WH_WHRL_U TO ROLE {{ env }}_REPORTING_WH_WHRL_M;
GRANT ROLE {{ env }}_REPORTING_WH_WHRL_M TO ROLE {{ env }}_REPORTING_WH_WHRL_O;
GRANT USAGE ON WAREHOUSE {{ env }}_REPORTING_WH TO ROLE {{ env }}_REPORTING_WH_WHRL_U;
GRANT MONITOR ON WAREHOUSE {{ env }}_REPORTING_WH TO ROLE {{ env }}_REPORTING_WH_WHRL_M;
GRANT OPERATE ON WAREHOUSE {{ env }}_REPORTING_WH TO ROLE {{ env }}_REPORTING_WH_WHRL_O;
