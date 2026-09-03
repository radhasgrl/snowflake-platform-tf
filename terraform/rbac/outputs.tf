output "functional_role_names" {
  value = {
    for role_name, role in snowflake_account_role.functional : role_name => role.name
  }
}
