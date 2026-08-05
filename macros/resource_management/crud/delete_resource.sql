{% macro delete_resource(resource_type, resource_config) %}
  {#
    Delete a resource - dispatches to resource-specific delete macros:
    delete_{resource_type}

    The full config is passed so resource types can use whatever identity they
    need to delete unambiguously (e.g. a UDF's types-only argument signature).
  #}

  {{ return(dbt_drift.dispatch_resource(resource_type, 'delete', resource_config=resource_config)) }}

{% endmacro %}
