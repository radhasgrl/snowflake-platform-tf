-- Placeholder row access policy — allows all rows through unconditionally.
-- See masking.sql for the ownership rationale.
-- TODO: replace the body expression once this domain's RLS requirements are confirmed by
-- the client.
{% set db = db_name(domain) %}
DEFINE ROW ACCESS POLICY {{ db }}.{{ policy_schema }}.{{ env }}_PLACEHOLDER_ALLOW_ALL_RAP AS (VAL VARCHAR) RETURNS BOOLEAN ->
  CASE WHEN TRUE THEN TRUE ELSE FALSE END
  COMMENT = 'Placeholder — allows all rows. Replace once row-level access rules are confirmed by the client.';
