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
