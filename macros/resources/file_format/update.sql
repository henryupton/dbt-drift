{% macro update_file_format(resource_config) %}
  {#
    Update an existing file format.
    Snowflake supports CREATE OR REPLACE, so update delegates to create.
  #}

  {{ return(adapter.dispatch('update_file_format', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_file_format(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_file_format not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_file_format(resource_config) %}
  {# Snowflake uses CREATE OR REPLACE, so update is the same as create #}
  {{ return(dbt_drift.create_file_format(resource_config)) }}
{% endmacro %}
