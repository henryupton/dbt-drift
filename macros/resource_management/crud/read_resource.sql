{% macro read_resource(resource_type, resource_name) %}
  {#
    Query the actual warehouse state for a resource
    Dispatches to resource-specific read macros
    Uses dynamic macro lookup: read_{resource_type}
  #}

  {% set macro_name = 'read_' ~ resource_type %}

  {% if macro_name not in dbt_drift %}
    {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_name)) }}

{% endmacro %}
