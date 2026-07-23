{% macro managed_marker() %}
  {#
    Marker embedded in a resource's comment/metadata so dbt-drift can tell
    which warehouse objects it manages. Orphan detection only ever drops
    resources carrying this marker, so objects created outside dbt-drift are
    left untouched.
  #}
  {{ return('dbt-drift:managed') }}
{% endmacro %}
