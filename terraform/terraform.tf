terraform {
  required_version = ">= 1.9"

  # Exact version pins (not ~>), matching industry practice for production infrastructure
  # repos (confirmed against a real client reference repo's convention) -- reproducibility
  # over automatic minor-version drift. Bump deliberately, verify via `terraform init
  # -upgrade` + a clean plan, rather than letting CI silently pick up a new minor version.
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "= 2.20.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"
    }
  }

  # Backend is partially configured here; bucket/key/region are supplied per
  # environment via `terraform init -backend-config=env/<env>/backend.hcl`
  backend "s3" {}
}
