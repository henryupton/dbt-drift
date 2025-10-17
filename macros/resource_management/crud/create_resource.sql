{% macro create_resource(resource_type, resource_config) %}
  {#
    Create a resource - dispatches to resource-specific create macros
    Uses dynamic macro lookup: create_{resource_type}
  #}

  {% set macro_name = 'create_' ~ resource_type %}

  {% if macro_name not in dbt_drift %}
    {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config)) }}

{% endmacro %}
