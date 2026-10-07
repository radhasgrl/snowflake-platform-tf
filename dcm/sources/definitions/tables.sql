-- Domain-owned landing/working tables. Driven entirely by manifest.yml's `tables` list —
-- each entry names its schema, table name, comment, and columns. A domain with no tables
-- defined here simply omits the `tables` key (defaults to an empty list).
{% set db = db_name(domain) %}
{% for t in tables | default([]) %}
DEFINE TABLE {{ db }}.{{ t.schema }}.{{ t.name }} (
{% for c in t.columns %}
  {{ c.name }} {{ c.type }} COMMENT '{{ c.comment }}'{{ "," if not loop.last }}
{% endfor %}
)
COMMENT = '{{ t.comment }}';
{% endfor %}
