# Terraform-owned home for the DCM project object itself — deliberately kept separate from
# any database that DCM manages, so the DCM project's own container is never one of the
# objects DCM has to reconcile. Matches the infra-platform reference template's
# ADMIN_<ENV>.DCM.<PROJECT> pattern.
resource "snowflake_database" "admin" {
  provider     = snowflake.sysadmin
  name         = "DEV_ADMIN_DB"
  comment      = "Terraform-owned platform metadata home — currently hosts only the DCM project object"
  is_transient = false
}

resource "snowflake_schema" "admin_dcm" {
  provider = snowflake.sysadmin
  database = snowflake_database.admin.name
  name     = "DCM"
  comment  = "Home schema for the PLATFORM_DCM project object (manifest.yml)"
}

# TEST-tier mirror of the above — a genuinely separate admin database/schema, not shared
# with DEV_ADMIN_DB. Customer's TEST DCM project (dcm/domains/customer/manifest.yml's TEST
# target) homes into TEST_ADMIN_DB.DCM, just as its CUSTOMER/DEV target homes into
# DEV_ADMIN_DB.DCM -- keeping environment tiers fully isolated down to the DCM project
# container itself, not just the domain databases/warehouses/roles it manages.
resource "snowflake_database" "admin_test" {
  provider     = snowflake.sysadmin
  name         = "TEST_ADMIN_DB"
  comment      = "Terraform-owned platform metadata home for the TEST environment tier — currently hosts only DCM project objects"
  is_transient = false
}

resource "snowflake_schema" "admin_test_dcm" {
  provider = snowflake.sysadmin
  database = snowflake_database.admin_test.name
  name     = "DCM"
  comment  = "Home schema for TEST-tier DCM project objects (e.g. Customer's TEST target)"
}
