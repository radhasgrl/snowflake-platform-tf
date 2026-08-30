locals {
  env = upper(var.environment)
}

# ─── Databases ───────────────────────────────────────────────────────────────

resource "snowflake_database" "landing" {
  name         = "${local.env}_LANDING_DB"
  comment      = "Raw / landing zone — untransformed source data"
  is_transient = false
}

resource "snowflake_database" "analytics" {
  name         = "${local.env}_ANALYTICS_DB"
  comment      = "Transformed and curated analytics layer"
  is_transient = false
}

resource "snowflake_database" "common" {
  name         = "${local.env}_COMMON_DB"
  comment      = "Shared utilities — UDFs, procedures, reference data"
  is_transient = false
}

# ─── Schemas ─────────────────────────────────────────────────────────────────

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

# ─── Warehouses ──────────────────────────────────────────────────────────────

resource "snowflake_warehouse" "ingest" {
  name                      = "${local.env}_INGEST_WH"
  comment                   = "Data loading and ingestion workloads"
  warehouse_size            = "XSMALL"
  warehouse_type            = "STANDARD"
  auto_suspend              = 60
  auto_resume               = true
  initially_suspended       = true
  enable_query_acceleration = false
}

resource "snowflake_warehouse" "transform" {
  name                      = "${local.env}_TRANSFORM_WH"
  comment                   = "dbt transformations and ELT workloads"
  warehouse_size            = var.environment == "prod" ? "SMALL" : "XSMALL"
  warehouse_type            = "STANDARD"
  auto_suspend              = 120
  auto_resume               = true
  initially_suspended       = true
  enable_query_acceleration = false
}

resource "snowflake_warehouse" "reporting" {
  name                      = "${local.env}_REPORTING_WH"
  comment                   = "BI tools and ad-hoc reporting queries"
  warehouse_size            = "XSMALL"
  warehouse_type            = "STANDARD"
  auto_suspend              = 60
  auto_resume               = true
  initially_suspended       = true
  enable_query_acceleration = false
}
