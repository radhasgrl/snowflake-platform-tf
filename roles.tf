resource "snowflake_account_role" "functional" {
  provider = snowflake.useradmin
  for_each = local.functional_roles

  name    = each.value
  comment = "${each.key} role for the ${local.env} environment"
}

resource "snowflake_grant_account_role" "functional_to_sysadmin" {
  provider = snowflake.useradmin
  for_each = snowflake_account_role.functional

  role_name        = each.value.name
  parent_role_name = "SYSADMIN"
}
