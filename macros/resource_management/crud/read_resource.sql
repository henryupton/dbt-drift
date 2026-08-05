{% macro read_resource(resource_type, resource_config) %}
  {#
    Query the actual warehouse state for a resource.
    Dispatches to resource-specific read macros: read_{resource_type}

    The full desired config is passed (not just the name) so reads can match
    the correct object where identity depends on more than the name
    (e.g. overloaded UDFs identified by their argument signature).
  #}

  {{ return(dbt_drift.dispatch_resource(resource_type, 'read', resource_config=resource_config)) }}

{% endmacro %}
