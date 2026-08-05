{% macro list_resource(resource_type) %}
  {#
    List the resources of a given type that dbt-drift manages in the warehouse.
    Dispatches to resource-specific list macros: list_{resource_type}

    Returns:
      - A list of dicts describing each managed resource (enough to identify
        and delete it), or
      - none if listing is not supported for this resource type (in which case
        orphan detection is skipped).
  #}

  {{ return(dbt_drift.dispatch_resource(resource_type, 'list', pass_config=false, required=false)) }}

{% endmacro %}
