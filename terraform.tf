terraform {
  required_version = ">= 1.9"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend is partially configured here; bucket/key/region are supplied per
  # environment via `terraform init -backend-config=env/<env>/backend.hcl`
  backend "s3" {}
}
