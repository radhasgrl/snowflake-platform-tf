# Resources migrated from Terraform to DCM (databases, schemas, warehouses, functional
# roles, DB grants, masking/row-access policies) per the ownership split agreed with the
# client in MDP_Platform_Engineering_CICD_IaC_Repo_Architecture_v0.1.md §2.2.
#
# `removed` blocks (Terraform >= 1.7) forget these resources without destroying the live
# Snowflake objects — `../dcm/_template/sources/definitions/*.sql` now declares the exact same
# objects, so DCM adopts them on the next `snow dcm deploy` with no disruption. This file is
# applied once by `terraform apply`; it can be deleted in a follow-up change once the
# cutover is confirmed (the `removed` directive only matters for the single apply that
# forgets them).

removed {
  from = snowflake_database.landing
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_database.analytics
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_database.common
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_schema.landing_raw
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_schema.analytics_staging
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_schema.analytics_marts
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_schema.common_utils
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_warehouse.ingest
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_warehouse.transform
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_warehouse.reporting
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_account_role.functional
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_account_role.functional_to_sysadmin
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_privileges_to_account_role.warehouse_usage
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_privileges_to_account_role.securityadmin_policy_creation
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_privileges_to_account_role.database_usage
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_privileges_to_account_role.schema_usage
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_privileges_to_account_role.select_current_tables
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_privileges_to_account_role.select_future_tables
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_privileges_to_account_role.dbt_write_current_tables
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_grant_privileges_to_account_role.dbt_write_future_tables
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_masking_policy.placeholder_varchar
  lifecycle {
    destroy = false
  }
}

removed {
  from = snowflake_row_access_policy.placeholder_allow_all
  lifecycle {
    destroy = false
  }
}
