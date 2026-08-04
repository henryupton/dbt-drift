{% macro create_resource(resource_type, resource_config) %}
  {#
    Create a resource - dispatches to resource-specific create macros
    Uses dynamic macro lookup: create_{resource_type}
  #}

  {% set macro_name = 'create_' ~ resource_type %}

  {# Probe by indexing, not `macro_name in dbt_drift`: on dbt-fusion the `in`
     test against a macro namespace is always false, so every dispatch would
     report the resource type as unknown. #}
  {% if dbt_drift[macro_name] is not defined %}
    {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config)) }}

{% endmacro %}
