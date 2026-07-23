{% macro delete_udf(resource_config) %}
  {#
    Delete a UDF from the warehouse.

    Args:
      resource_config: Dict identifying the UDF to drop:
        - name: UDF name
        - arg_types: types-only argument signature (e.g. "number, number"),
          as required by DROP FUNCTION. Empty string for a no-argument UDF.
  #}

  {{ return(adapter.dispatch('delete_udf', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__delete_udf(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("delete_udf not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__delete_udf(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set name = resource_config.name %}
  {% set arg_types = resource_config.get('arg_types', '') or '' %}

  {% set drop_sql %}
    drop function if exists {{ target.schema }}.{{ name }}({{ arg_types }})
  {% endset %}

  {% do run_query(drop_sql) %}
  {{ log("Deleted UDF: " ~ name ~ "(" ~ arg_types ~ ")", info=true) }}

  {{ return({'success': true, 'resource': name}) }}

{% endmacro %}
