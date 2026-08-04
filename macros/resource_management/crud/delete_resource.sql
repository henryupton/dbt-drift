{% macro delete_resource(resource_type, resource_config) %}
  {#
    Delete a resource - dispatches to resource-specific delete macros.
    Uses dynamic macro lookup: delete_{resource_type}

    The full config is passed so resource types can use whatever identity they
    need to delete unambiguously (e.g. a UDF's types-only argument signature).
  #}

  {% set macro_name = 'delete_' ~ resource_type %}

  {# Probe by indexing, not `macro_name in dbt_drift`: on dbt-fusion the `in`
     test against a macro namespace is always false, so every dispatch would
     report the resource type as unknown. #}
  {% if dbt_drift[macro_name] is not defined %}
    {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config)) }}

{% endmacro %}
