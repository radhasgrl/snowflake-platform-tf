resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  provider = snowflake.useradmin
  for_each = local.warehouse_grants

  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.functional[each.value.role_name].name

  on_account_object {
    object_type = each.value.object_type
    object_name = each.value.object_name
  }
}

# SYSADMIN owns DEV_COMMON_DB.UTILS; SECURITYADMIN needs this privilege to create policies there
resource "snowflake_grant_privileges_to_account_role" "securityadmin_policy_creation" {
  provider = snowflake

  privileges        = ["CREATE MASKING POLICY", "CREATE ROW ACCESS POLICY"]
  account_role_name = "SECURITYADMIN"

  on_schema {
    schema_name = "${local.databases.common}.UTILS"
  }
}

resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  provider = snowflake.useradmin
  for_each = local.database_grants

  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.functional[each.value.role_name].name

  on_account_object {
    object_type = each.value.object_type
    object_name = each.value.object_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "schema_usage" {
  provider = snowflake.useradmin
  for_each = local.schema_grants

  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.functional[each.value.role_name].name

  on_schema {
    schema_name = each.value.object_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "select_current_tables" {
  provider = snowflake.useradmin
  for_each = {
    data_analyst  = "${local.databases.analytics}.MARTS"
    data_consumer = "${local.databases.analytics}.MARTS"
  }

  privileges        = ["SELECT"]
  account_role_name = snowflake_account_role.functional[each.key].name

  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = each.value
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "select_future_tables" {
  provider = snowflake.useradmin
  for_each = {
    data_analyst  = "${local.databases.analytics}.MARTS"
    data_consumer = "${local.databases.analytics}.MARTS"
  }

  privileges        = ["SELECT"]
  account_role_name = snowflake_account_role.functional[each.key].name

  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = each.value
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_write_current_tables" {
  provider = snowflake.useradmin

  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  account_role_name = snowflake_account_role.functional["dbt_runner"].name

  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "${local.databases.analytics}.STAGING"
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_write_future_tables" {
  provider = snowflake.useradmin

  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  account_role_name = snowflake_account_role.functional["dbt_runner"].name

  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "${local.databases.analytics}.STAGING"
    }
  }
}
