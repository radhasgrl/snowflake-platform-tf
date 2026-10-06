-- Tiered RBAC model (persona -> functional -> database/warehouse access roles), scoped to
-- this domain. Fully generic: the actual persona/functional role lists come from
-- manifest.yml's `personas`/`functional_roles`, not hardcoded here.
--
-- Database roles (Tier 3) are defined in database_roles.sql since DCM scopes
-- `DEFINE DATABASE ROLE` per-database. Composition lives in grants.sql.
-- Tier 4 (warehouse) roles are account-level/shared, not domain-specific — see
-- dcm/account/sources/definitions/warehouses.sql.

-- Tier 1: persona roles — granted to actual users/service identities
{{ define_persona_roles(domain, personas) }}

-- Tier 2: functional roles — capability-oriented, composed from Tier 3 (database) and
-- Tier 4 (warehouse) roles in grants.sql
{{ define_functional_roles(domain, functional_roles) }}
