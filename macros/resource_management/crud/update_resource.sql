{% macro update_resource(resource_type, resource_config) %}
  {#
    Update a resource - dispatches to resource-specific update macros:
    update_{resource_type}
  #}

  {{ return(dbt_drift.dispatch_resource(resource_type, 'update', resource_config=resource_config)) }}

{% endmacro %}
