-- Grants. Tiered RBAC composition for this domain: Tier 3 (database roles) + Tier 4
-- (warehouse roles, domain-owned) -> Tier 2 (functional roles) -> Tier 1 (persona
-- roles). See roles.sql / database_roles.sql for the role definitions this file wires
-- together. Fully generic — every name is derived via macros from manifest.yml config,
-- nothing domain-specific is hardcoded in this file.
{% set db = db_name(domain) %}

-- Visibility: persona roles report up to SYSADMIN (consistent with the rest of this project)
{% for p in personas %}
GRANT ROLE {{ persona_name(domain, p.name) }} TO ROLE SYSADMIN;
{% endfor %}

-- Least-privilege grants to the actual CI/service identities (Terraform-created in
-- oidc_service_user.tf, Repo 1) — demonstrates the tiered RBAC model end-to-end for real
-- downstream workloads. Only personas with an `oidc_user` configured get this grant.
{% for p in personas %}
{% if p.oidc_user | default(false) %}
GRANT ROLE {{ persona_name(domain, p.name) }} TO USER {{ p.oidc_user }};
{% endif %}
{% endfor %}

-- Lets SECURITYADMIN create masking/row-access policies in this domain's policy schema
-- (conventionally SHARED).
GRANT CREATE MASKING POLICY, CREATE ROW ACCESS POLICY ON SCHEMA {{ db }}.{{ policy_schema }} TO ROLE SECURITYADMIN;

-- Tier 4: this domain's own warehouse role hierarchy (USAGE -> MONITOR -> OPERATE) +
-- privilege grants. Per-domain, not shared — see warehouses.sql.
{% for wh in warehouses %}
{{ grant_warehouse_privileges(domain, wh) }}
{% endfor %}

-- Tier 3: database role hierarchy (write includes read) + privilege grants, per schema
{% for schema in schemas %}
{{ grant_schema_read_privileges(db, schema) }}
{% if not (schema.read_only | default(false)) %}
{{ grant_schema_write_privileges(db, schema) }}
{% endif %}
{% endfor %}

-- Tier 2: functional roles composed from Tier 3 (database) + Tier 4 (warehouse) roles
{% for f in functional_roles %}
{{ grant_functional_role_composition(domain, db, f) }}
{% if f.needs_create_integration | default(false) %}
-- STORAGE INTEGRATION is an account-level object (bridges to an external cloud account) —
-- CREATE INTEGRATION is only grantable at the account level, not per-schema/database.
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE {{ functional_name(domain, f.name) }};
{% endif %}
{% if f.needs_create_schema | default(false) %}
-- Transformation tools (e.g. dbt) run a CREATE SCHEMA IF NOT EXISTS check against their
-- target schema at the start of every invocation, even when the schema already exists.
-- CREATE SCHEMA is only grantable at the database level in Snowflake, so this lives here
-- rather than on a narrower Tier 3 database role.
GRANT CREATE SCHEMA ON DATABASE {{ db }} TO ROLE {{ functional_name(domain, f.name) }};
{% endif %}
{% endfor %}

-- Tier 1: personas receive the functional roles (and any extra warehouse grants) they need
{% for p in personas %}
{{ grant_persona_composition(domain, p) }}
{% endfor %}
