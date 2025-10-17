{% macro update_resource(resource_type, resource_config) %}
  {#
    Update a resource - dispatches to resource-specific update macros
    Uses dynamic macro lookup: update_{resource_type}
  #}

  {% set macro_name = 'update_' ~ resource_type %}

  {% if macro_name not in dbt_drift %}
    {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config)) }}

{% endmacro %}
