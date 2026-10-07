-- Domain schemas — the set of schemas is declared per-domain in manifest.yml's `schemas`
-- list (each with its own name/comment/read_only/write_create_privileges), not hardcoded
-- here. Every domain gets whatever schema layering it configures.
{% set db = db_name(domain) %}
{% for schema in schemas %}
DEFINE SCHEMA {{ db }}.{{ schema.name }}
  COMMENT = '{{ schema.comment }}';
{% endfor %}
