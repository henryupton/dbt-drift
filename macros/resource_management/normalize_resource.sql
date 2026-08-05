{% macro normalize_resource(resource_type, resource_config) %}
  {#
    Normalize a desired-state config so it compares cleanly against the state
    read back from the warehouse (which may widen types, reformat, etc.).
    Dispatches to resource-specific normalize macros: normalize_{resource_type}

    If a resource type provides no normalize macro, the config is returned
    unchanged.
  #}

  {{ return(dbt_drift.dispatch_resource(
      resource_type, 'normalize', resource_config=resource_config,
      required=false, fallback=resource_config
  )) }}

{% endmacro %}
