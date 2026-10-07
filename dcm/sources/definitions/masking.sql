-- Placeholder masking policy — passes VARCHAR values through unmasked.
-- Policies are schema-scoped data-governance objects, not account-level "security/network
-- policy" (Terraform's remaining scope).
-- TODO: replace masking_expression once this domain's PII columns are confirmed by the client.
{% set db = db_name(domain) %}
DEFINE MASKING POLICY {{ db }}.{{ policy_schema }}.{{ env }}_PLACEHOLDER_VARCHAR_MASK AS (VAL VARCHAR) RETURNS VARCHAR ->
  VAL
  COMMENT = 'Placeholder — no masking applied yet. Replace once PII columns are confirmed by the client.';
