{% macro delete_resource(resource_type, resource_config) %}
  {#
    Delete a resource - dispatches to resource-specific delete macros
    Uses dynamic macro lookup: delete_{resource_type}
  #}

  {% set macro_name = 'delete_' ~ resource_type %}

  {% if macro_name not in dbt_drift %}
    {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config.name, resource_config.get('arguments'))) }}

{% endmacro %}
