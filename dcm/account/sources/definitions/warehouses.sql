-- Account-level, platform/CI-tooling warehouse — matches the infra-platform reference's
-- own account-level DEPLOY_WH convention (dcm/manifest.yml's account_warehouses). This is
-- the ONE warehouse genuinely shared across the whole platform: used as the explicit
-- default warehouse for the Terraform and DCM CI identities' own connections
-- (GITHUB_DEV_TERRAFORM_SVC / GITHUB_DEV_DCM_SVC — see terraform-plan.yml/-apply.yml),
-- never by domain workloads (those get their own per-domain warehouses — see
-- dcm/sources/definitions/warehouses.sql).
--
-- Honest note: Terraform/DCM's own operations here are metadata/DDL only and don't
-- strictly require active compute to succeed (confirmed empirically — every CI run this
-- platform has done so far succeeded with no warehouse set at all). This warehouse exists
-- so CI has an explicit, intentional default rather than relying on undefined session
-- behavior, and so any future CI step that *does* need compute (e.g. a post-deploy
-- validation query) already has one to use.
DEFINE WAREHOUSE DEV_DEPLOY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Platform/CI tooling warehouse for Terraform + DCM''s own deploy/plan operations — never used by domain workloads.';

GRANT USAGE ON WAREHOUSE DEV_DEPLOY_WH TO ROLE SYSADMIN;
