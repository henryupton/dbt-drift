{% macro create_resource(resource_type, resource_config) %}
  {#
    Create a resource - dispatches to resource-specific create macros:
    create_{resource_type}
  #}

  {{ return(dbt_drift.dispatch_resource(resource_type, 'create', resource_config=resource_config)) }}

{% endmacro %}
