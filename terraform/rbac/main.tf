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

  warehouse_grants = {
    for grant in flatten([
      for role_name, warehouses in {
        data_engineer = [local.warehouses.ingest, local.warehouses.transform]
        data_analyst  = [local.warehouses.reporting]
        data_consumer = [local.warehouses.reporting]
        dbt_runner    = [local.warehouses.transform]
        } : [
        for warehouse_name in warehouses : {
          key         = "${role_name}_${warehouse_name}"
          role_name   = role_name
          object_name = warehouse_name
          object_type = "WAREHOUSE"
        }
      ]
    ]) : grant.key => grant
  }

  database_grants = {
    for grant in flatten([
      for role_name, databases in {
        data_engineer = [local.databases.landing, local.databases.analytics, local.databases.common]
        data_analyst  = [local.databases.analytics]
        data_consumer = [local.databases.analytics]
        dbt_runner    = [local.databases.analytics, local.databases.common]
        } : [
        for database_name in databases : {
          key         = "${role_name}_${database_name}"
          role_name   = role_name
          object_name = database_name
          object_type = "DATABASE"
        }
      ]
    ]) : grant.key => grant
  }

  schema_grants = {
    for grant in flatten([
      for role_name, schemas in {
        data_engineer = [
          "${local.databases.landing}.RAW",
          "${local.databases.analytics}.STAGING",
          "${local.databases.analytics}.MARTS",
          "${local.databases.common}.UTILS",
        ]
        data_analyst  = ["${local.databases.analytics}.STAGING", "${local.databases.analytics}.MARTS"]
        data_consumer = ["${local.databases.analytics}.MARTS"]
        dbt_runner    = ["${local.databases.analytics}.STAGING", "${local.databases.analytics}.MARTS", "${local.databases.common}.UTILS"]
        } : [
        for schema_name in schemas : {
          key         = "${role_name}_${schema_name}"
          role_name   = role_name
          object_name = schema_name
        }
      ]
    ]) : grant.key => grant
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
  for_each = local.warehouse_grants

  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.functional[each.value.role_name].name

  on_account_object {
    object_type = each.value.object_type
    object_name = each.value.object_name
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
