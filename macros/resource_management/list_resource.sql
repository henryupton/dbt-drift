{% macro list_resource(resource_type) %}
  {#
    List the resources of a given type that dbt-drift manages in the warehouse.
    Dispatches to resource-specific list macros: list_{resource_type}

    Returns:
      - A list of dicts describing each managed resource (enough to identify
        and delete it), or
      - none if listing is not supported for this resource type (in which case
        orphan detection is skipped).
  #}

  {% set macro_name = 'list_' ~ resource_type %}

  {# Probe by indexing, not `macro_name in dbt_drift`: on dbt-fusion the `in`
     test against a macro namespace is always false, so every dispatch would
     report the resource type as unknown. #}
  {% if dbt_drift[macro_name] is not defined %}
    {{ return(none) }}
  {% endif %}

  {{ return(dbt_drift[macro_name]()) }}

{% endmacro %}
