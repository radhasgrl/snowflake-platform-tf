resource "snowflake_schema" "landing_raw" {
  database = snowflake_database.landing.name
  name     = "RAW"
  comment  = "Initial landing area for all source ingestion"
}

resource "snowflake_schema" "analytics_staging" {
  database = snowflake_database.analytics.name
  name     = "STAGING"
  comment  = "Intermediate dbt models"
}

resource "snowflake_schema" "analytics_marts" {
  database = snowflake_database.analytics.name
  name     = "MARTS"
  comment  = "Final business-facing data marts"
}

resource "snowflake_schema" "common_utils" {
  database = snowflake_database.common.name
  name     = "UTILS"
  comment  = "Shared UDFs and stored procedures"
}
