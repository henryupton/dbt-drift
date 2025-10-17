{% macro update_udf(resource_config) %}
  {#
    Update an existing UDF in the warehouse

    For most databases, this is the same as CREATE OR REPLACE
    so we delegate to create_udf

    Args:
      resource_config: Dictionary containing UDF configuration
  #}

  {{ return(adapter.dispatch('update_udf', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_udf(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_udf not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_udf(resource_config) %}
  {#
    Snowflake uses CREATE OR REPLACE, so update is the same as create
  #}

  {{ return(create_udf(resource_config)) }}

{% endmacro %}
