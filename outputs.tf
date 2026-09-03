output "landing_db_name" {
  value = snowflake_database.landing.name
}

output "analytics_db_name" {
  value = snowflake_database.analytics.name
}

output "common_db_name" {
  value = snowflake_database.common.name
}

output "ingest_warehouse_name" {
  value = snowflake_warehouse.ingest.name
}

output "transform_warehouse_name" {
  value = snowflake_warehouse.transform.name
}

output "reporting_warehouse_name" {
  value = snowflake_warehouse.reporting.name
}

output "functional_role_names" {
  value = {
    for role_name, role in snowflake_account_role.functional : role_name => role.name
  }
}
