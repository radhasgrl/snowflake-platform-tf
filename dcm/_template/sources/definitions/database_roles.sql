-- Tier 3: database roles — schema-scoped read/write within this domain's database,
-- composed into Tier 2 functional roles in grants.sql. `DEFINE DATABASE ROLE` is scoped
-- per-database, so these live in their own file separate from the Tier 1/2/4 account roles
-- in roles.sql. Schema list (and which schemas get a write role) comes entirely from
-- manifest.yml's `schemas` config — nothing domain-specific hardcoded here.
{% set db = db_name(domain) %}
{% for schema in schemas %}
{{ define_schema_roles(db, schema) }}
{% endfor %}
