{% macro normalize_resource(resource_type, resource_config) %}
  {#
    Normalize a desired-state config so it compares cleanly against the state
    read back from the warehouse (which may widen types, reformat, etc.).
    Dispatches to resource-specific normalize macros: normalize_{resource_type}

    If a resource type provides no normalize macro, the config is returned
    unchanged.
  #}

  {% set macro_name = 'normalize_' ~ resource_type %}

  {# Probe by indexing, not `macro_name in dbt_drift`: on dbt-fusion the `in`
     test against a macro namespace is always false, so every dispatch would
     report the resource type as unknown. #}
  {% if dbt_drift[macro_name] is not defined %}
    {{ return(resource_config) }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config)) }}

{% endmacro %}
