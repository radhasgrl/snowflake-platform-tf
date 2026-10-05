-- Placeholder row access policy — allows all rows through unconditionally.
-- See masking.sql for the ownership rationale.
-- TODO: replace the body expression once Questionnaire.md Q11 (RLS requirements) is answered.
DEFINE ROW ACCESS POLICY DEV_CUSTOMER_DB.SHARED.DEV_PLACEHOLDER_ALLOW_ALL_RAP AS (VAL VARCHAR) RETURNS BOOLEAN ->
  CASE WHEN TRUE THEN TRUE ELSE FALSE END
  COMMENT = 'Placeholder — allows all rows. Replace once row-level access rules are confirmed by the client.';
