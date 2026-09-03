resource "snowflake_warehouse" "ingest" {
  name                      = local.warehouses.ingest
  comment                   = "Data loading and ingestion workloads"
  warehouse_size            = "XSMALL"
  warehouse_type            = "STANDARD"
  auto_suspend              = 60
  auto_resume               = true
  initially_suspended       = true
  enable_query_acceleration = false
}

resource "snowflake_warehouse" "transform" {
  name                      = local.warehouses.transform
  comment                   = "dbt transformations and ELT workloads"
  warehouse_size            = var.environment == "prod" ? "SMALL" : "XSMALL"
  warehouse_type            = "STANDARD"
  auto_suspend              = 120
  auto_resume               = true
  initially_suspended       = true
  enable_query_acceleration = false
}

resource "snowflake_warehouse" "reporting" {
  name                      = local.warehouses.reporting
  comment                   = "BI tools and ad-hoc reporting queries"
  warehouse_size            = "XSMALL"
  warehouse_type            = "STANDARD"
  auto_suspend              = 60
  auto_resume               = true
  initially_suspended       = true
  enable_query_acceleration = false
}
