{% macro delete_udf(resource_name, arguments=none) %}
  {#
    Delete a UDF from the warehouse

    Args:
      resource_name: Name of the UDF to delete
      arguments: Optional argument signature for overloaded functions
  #}

  {{ return(adapter.dispatch('delete_udf', 'dbt_drift')(resource_name, arguments)) }}

{% endmacro %}


{% macro default__delete_udf(resource_name, arguments=none) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("delete_udf not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__delete_udf(resource_name, arguments=none) %}
  {# Snowflake-specific implementation #}

  {% set drop_sql %}
    drop function if exists {{ target.schema }}.{{ resource_name }}
    {% if arguments %}
    ({{ arguments }})
    {% endif %}
  {% endset %}

  {% do run_query(drop_sql) %}
  {{ log("Deleted UDF: " ~ resource_name, info=true) }}

  {{ return({'success': true, 'resource': resource_name}) }}

{% endmacro %}
