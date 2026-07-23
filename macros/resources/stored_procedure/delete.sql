{% macro delete_stored_procedure(resource_config) %}
  {#
    Delete a stored procedure from the warehouse.

    Args:
      resource_config: Dict identifying the procedure to drop:
        - name: Procedure name
        - arg_types: types-only argument signature (e.g. "number, string"),
          as required by DROP PROCEDURE. Empty string for a no-argument proc.
  #}

  {{ return(adapter.dispatch('delete_stored_procedure', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__delete_stored_procedure(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("delete_stored_procedure not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__delete_stored_procedure(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set name = resource_config.name %}
  {% set arg_types = resource_config.get('arg_types', '') or '' %}

  {% set drop_sql %}
    drop procedure if exists {{ target.schema }}.{{ name }}({{ arg_types }})
  {% endset %}

  {% do run_query(drop_sql) %}
  {{ log("Deleted stored_procedure: " ~ name ~ "(" ~ arg_types ~ ")", info=true) }}

  {{ return({'success': true, 'resource': name}) }}

{% endmacro %}
