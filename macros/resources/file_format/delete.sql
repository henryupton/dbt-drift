{% macro delete_file_format(resource_config) %}
  {#
    Delete a file format from the warehouse (uses 'name').
  #}

  {{ return(adapter.dispatch('delete_file_format', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__delete_file_format(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("delete_file_format not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__delete_file_format(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set name = resource_config.name %}

  {% set drop_sql %}
    drop file format if exists {{ target.schema }}.{{ name }}
  {% endset %}

  {% do run_query(drop_sql) %}
  {{ log("Deleted file_format: " ~ name, info=true) }}

  {{ return({'success': true, 'resource': name}) }}

{% endmacro %}
