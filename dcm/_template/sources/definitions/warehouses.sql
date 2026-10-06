-- Tier 4: this domain's own dedicated workload warehouses. Per-domain, not shared — see the
-- header comment in dcm/_template/sources/macros/domain_macros.sql for why. Driven entirely
-- by manifest.yml's `warehouses` list.
{{ define_warehouses(domain, warehouses) }}

{{ define_warehouse_roles(domain, warehouses) }}
