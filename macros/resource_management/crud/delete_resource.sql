{% macro delete_resource(resource_type, resource_config) %}
  {#
    Delete a resource - dispatches to resource-specific delete macros.
    Uses dynamic macro lookup: delete_{resource_type}

    The full config is passed so resource types can use whatever identity they
    need to delete unambiguously (e.g. a UDF's types-only argument signature).
  #}

  {% set macro_name = 'delete_' ~ resource_type %}

  {% if macro_name not in dbt_drift %}
    {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config)) }}

{% endmacro %}
