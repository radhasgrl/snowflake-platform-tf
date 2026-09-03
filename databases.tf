resource "snowflake_database" "landing" {
  name         = local.databases.landing
  comment      = "Raw / landing zone — untransformed source data"
  is_transient = false
}

resource "snowflake_database" "analytics" {
  name         = local.databases.analytics
  comment      = "Transformed and curated analytics layer"
  is_transient = false
}

resource "snowflake_database" "common" {
  name         = local.databases.common
  comment      = "Shared utilities — UDFs, procedures, reference data"
  is_transient = false
}
