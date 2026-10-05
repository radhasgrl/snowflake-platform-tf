-- Placeholder masking policy — passes VARCHAR values through unmasked.
-- Policies are schema-scoped data-governance objects, not account-level "security/network
-- policy" (Terraform's remaining scope).
-- TODO: replace masking_expression once Questionnaire.md Q10 (PII columns) is answered.
DEFINE MASKING POLICY DEV_CUSTOMER_DB.SHARED.DEV_PLACEHOLDER_VARCHAR_MASK AS (VAL VARCHAR) RETURNS VARCHAR ->
  VAL
  COMMENT = 'Placeholder — no masking applied yet. Replace once PII columns are confirmed by the client.';
