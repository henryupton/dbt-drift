{% macro normalize_resource(resource_type, resource_config) %}
  {#
    Normalize a desired-state config so it compares cleanly against the state
    read back from the warehouse (which may widen types, reformat, etc.).
    Dispatches to resource-specific normalize macros: normalize_{resource_type}

    If a resource type provides no normalize macro, the config is returned
    unchanged.
  #}

  {% set macro_name = 'normalize_' ~ resource_type %}

  {% if macro_name not in dbt_drift %}
    {{ return(resource_config) }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config)) }}

{% endmacro %}
