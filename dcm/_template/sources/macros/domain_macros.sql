{# ============================================================
   Domain Templating Macros — snowflake-platform-tf
   Reusable across every domain's DCM project (dcm/domains/<domain>/).

   These macros exist so onboarding domain #2..#200 requires zero new SQL —
   only a new dcm/domains/<domain>/manifest.yml with that domain's own
   templating_config values. The macro bodies themselves never reference a
   specific domain name.

   Naming convention preserved exactly as the original hand-written Customer
   domain objects (verified via a zero-diff `snow dcm plan` before this was
   adopted) — e.g. env=DEV, domain=CUSTOMER renders identically to the
   original DEV_CUSTOMER_DB, DEV_CUSTOMER_DATA_ENGINEER_PRSN, etc.
============================================================ #}

{# --- Naming macros --- #}
{% macro db_name(domain) %}{{ env }}_{{ domain }}_DB{% endmacro %}

{% macro persona_name(domain, persona) %}{{ env }}_{{ domain }}_{{ persona }}_PRSN{% endmacro %}

{% macro functional_name(domain, func) %}{{ env }}_{{ domain }}_{{ func }}_FNCRL{% endmacro %}

{% macro schema_role_name(db, schema, level) %}{{ db }}.{{ schema }}_SCRL_{{ level }}{% endmacro %}

{% macro warehouse_role_name(purpose, level) %}{{ env }}_{{ purpose }}_WH_WHRL_{{ level }}{% endmacro %}

{% macro warehouse_name(purpose) %}{{ env }}_{{ purpose }}_WH{% endmacro %}

{# ============================================================
   Tier 1 / Tier 2 role definitions (persona / functional)
============================================================ #}

{% macro define_persona_roles(domain, personas) %}
{% for p in personas %}
DEFINE ROLE {{ persona_name(domain, p.name) }}
  COMMENT = 'Tier 1 persona: {{ p.comment }}';
{% endfor %}
{% endmacro %}

{% macro define_functional_roles(domain, functional_roles) %}
{% for f in functional_roles %}
DEFINE ROLE {{ functional_name(domain, f.name) }}
  COMMENT = 'Tier 2 functional: {{ f.comment }}';
{% endfor %}
{% endmacro %}

{# ============================================================
   Tier 3 database roles: schema-scoped read/write hierarchy (W includes R)
============================================================ #}

{% macro define_schema_roles(db, schema) %}
DEFINE DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_R
  COMMENT = 'Tier 3 database role: read-only on {{ domain }}.{{ schema.name }}{{ schema.r_comment_suffix | default("") }}';
{% if not schema.read_only %}
DEFINE DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_W
  COMMENT = 'Tier 3 database role: read-write on {{ domain }}.{{ schema.name }} (includes read){{ schema.w_comment_suffix | default("") }}';
{% endif %}
{% endmacro %}

{% macro grant_schema_read_privileges(db, schema) %}
GRANT USAGE ON DATABASE {{ db }} TO DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_R;
GRANT USAGE ON SCHEMA {{ db }}.{{ schema.name }} TO DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_R;
GRANT SELECT ON ALL TABLES IN SCHEMA {{ db }}.{{ schema.name }} TO DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_R;
GRANT SELECT ON FUTURE TABLES IN SCHEMA {{ db }}.{{ schema.name }} TO DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_R;
{% endmacro %}

{% macro grant_schema_write_privileges(db, schema) %}
GRANT DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_R TO DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_W;
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA {{ db }}.{{ schema.name }} TO DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_W;
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA {{ db }}.{{ schema.name }} TO DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_W;
{% if schema.write_create_privileges %}
-- Extra CREATE privilege(s) this schema's write role needs, e.g. CREATE VIEW for a schema
-- that hosts view-materialized models, CREATE STAGE/FILE FORMAT/PIPE for an ingestion
-- landing zone. Declared per-schema in manifest.yml, not hardcoded here.
GRANT {{ schema.write_create_privileges }} ON SCHEMA {{ db }}.{{ schema.name }} TO DATABASE ROLE {{ db }}.{{ schema.name }}_SCRL_W;
{% endif %}
{% endmacro %}

{# ============================================================
   Tier 2 -> Tier 3/4 composition: functional role grants
============================================================ #}

{% macro grant_functional_role_composition(domain, db, func) %}
{% for dbg in func.database_role_grants | default([]) %}
GRANT DATABASE ROLE {{ schema_role_name(db, dbg.schema, dbg.level) }} TO ROLE {{ functional_name(domain, func.name) }};
{% endfor %}
{% for whg in func.warehouse_grants | default([]) %}
GRANT ROLE {{ warehouse_role_name(whg.purpose, whg.level) }} TO ROLE {{ functional_name(domain, func.name) }};
{% endfor %}
{% endmacro %}

{# ============================================================
   Tier 1 <- Tier 2 composition: persona receives functional roles
============================================================ #}

{% macro grant_persona_composition(domain, persona) %}
{% for func_name in persona.functional_roles | default([]) %}
GRANT ROLE {{ functional_name(domain, func_name) }} TO ROLE {{ persona_name(domain, persona.name) }};
{% endfor %}
{% for whg in persona.extra_warehouse_grants | default([]) %}
GRANT ROLE {{ warehouse_role_name(whg.purpose, whg.level) }} TO ROLE {{ persona_name(domain, persona.name) }};
{% endfor %}
{% endmacro %}
