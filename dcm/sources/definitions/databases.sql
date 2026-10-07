-- Domain database — one database per domain, holding every data layer (raw/staging/marts/
-- shared) for that domain. Fully generic: a new domain needs zero new SQL here, only a new
-- dcm/domains/<domain>/manifest.yml with its own `domain`/`domain_comment` values.
DEFINE DATABASE {{ db_name(domain) }}
  COMMENT = '{{ domain_comment }}';
