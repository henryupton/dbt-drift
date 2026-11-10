{% macro update_file_format(resource_config) %}
  {#
    Update an existing file format. Create uses CREATE OR ALTER, which keeps
    grants. Snowflake refuses a type change (002134): drop the format first.
  #}

  {{ return(adapter.dispatch('update_file_format', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_file_format(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_file_format not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_file_format(resource_config) %}
  {{ return(dbt_drift.create_file_format(resource_config)) }}
{% endmacro %}
