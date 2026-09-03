locals {
  env = upper(var.environment)

  databases = {
    landing   = "${local.env}_LANDING_DB"
    analytics = "${local.env}_ANALYTICS_DB"
    common    = "${local.env}_COMMON_DB"
  }

  warehouses = {
    ingest    = "${local.env}_INGEST_WH"
    transform = "${local.env}_TRANSFORM_WH"
    reporting = "${local.env}_REPORTING_WH"
  }

  functional_roles = {
    data_engineer = "${local.env}_DATA_ENGINEER"
    data_analyst  = "${local.env}_DATA_ANALYST"
    data_consumer = "${local.env}_DATA_CONSUMER"
    dbt_runner    = "${local.env}_DBT_RUNNER"
  }
}

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

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  provider = snowflake.useradmin
  for_each = {
    data_engineer = [local.warehouses.ingest, local.warehouses.transform]
    data_analyst  = [local.warehouses.reporting]
    data_consumer = [local.warehouses.reporting]
    dbt_runner    = [local.warehouses.transform]
  }

  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.functional[each.key].name

  dynamic "on_account_object" {
    for_each = toset(each.value)
    content {
      object_type = "WAREHOUSE"
      object_name = on_account_object.value
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  provider = snowflake.useradmin
  for_each = {
    data_engineer = [local.databases.landing, local.databases.analytics, local.databases.common]
    data_analyst  = [local.databases.analytics]
    data_consumer = [local.databases.analytics]
    dbt_runner    = [local.databases.analytics, local.databases.common]
  }

  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.functional[each.key].name

  dynamic "on_account_object" {
    for_each = toset(each.value)
    content {
      object_type = "DATABASE"
      object_name = on_account_object.value
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "schema_usage" {
  provider = snowflake.useradmin
  for_each = {
    data_engineer = [
      "${local.databases.landing}.RAW",
      "${local.databases.analytics}.STAGING",
      "${local.databases.analytics}.MARTS",
      "${local.databases.common}.UTILS",
    ]
    data_analyst  = ["${local.databases.analytics}.STAGING", "${local.databases.analytics}.MARTS"]
    data_consumer = ["${local.databases.analytics}.MARTS"]
    dbt_runner    = ["${local.databases.analytics}.STAGING", "${local.databases.analytics}.MARTS", "${local.databases.common}.UTILS"]
  }

  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.functional[each.key].name

  dynamic "on_schema" {
    for_each = toset(each.value)
    content {
      schema_name = on_schema.value
    }
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
