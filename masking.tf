# Placeholder masking policy — passes VARCHAR values through unmasked.
# Wires up the policy + grant pattern so it can be demoed and attached to
# tables, without inventing PII rules the client hasn't confirmed yet.
# TODO: replace masking_expression once Questionnaire.md Q10 (PII columns) is answered.
resource "snowflake_masking_policy" "placeholder_varchar" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_grant_privileges_to_account_role.securityadmin_policy_creation
  ]

  name     = "${local.env}_PLACEHOLDER_VARCHAR_MASK"
  database = local.databases.common
  schema   = "UTILS"
  comment  = "Placeholder — no masking applied yet. Replace once PII columns are confirmed by the client."

  argument {
    name = "VAL"
    type = "VARCHAR"
  }

  body             = "VAL"
  return_data_type = "VARCHAR"
}
