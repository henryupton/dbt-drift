{% macro read_resource(resource_type, resource_config) %}
  {#
    Query the actual warehouse state for a resource.
    Dispatches to resource-specific read macros.
    Uses dynamic macro lookup: read_{resource_type}

    The full desired config is passed (not just the name) so reads can match
    the correct object where identity depends on more than the name
    (e.g. overloaded UDFs identified by their argument signature).
  #}

  {% set macro_name = 'read_' ~ resource_type %}

  {# Probe by indexing, not `macro_name in dbt_drift`: on dbt-fusion the `in`
     test against a macro namespace is always false, so every dispatch would
     report the resource type as unknown. #}
  {% if dbt_drift[macro_name] is not defined %}
    {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
  {% endif %}

  {{ return(dbt_drift[macro_name](resource_config)) }}

{% endmacro %}
