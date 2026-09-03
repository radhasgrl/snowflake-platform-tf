# Placeholder row access policy — allows all rows through unconditionally.
# Wires up the policy + grant pattern so it can be demoed and attached to
# tables, without inventing RLS rules the client hasn't confirmed yet.
# TODO: replace the body expression once Questionnaire.md Q11 (RLS requirements) is answered.
resource "snowflake_row_access_policy" "placeholder_allow_all" {
  provider = snowflake.securityadmin
  depends_on = [
    snowflake_grant_privileges_to_account_role.securityadmin_policy_creation
  ]

  name     = "${local.env}_PLACEHOLDER_ALLOW_ALL_RAP"
  database = local.databases.common
  schema   = "UTILS"
  comment  = "Placeholder — allows all rows. Replace once row-level access rules are confirmed by the client."

  argument {
    name = "VAL"
    type = "VARCHAR"
  }

  body = "case when true then true else false end"
}
