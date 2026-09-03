locals {
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
