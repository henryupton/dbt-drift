{% macro update_udf(resource_config) %}
  {#
    Update an existing UDF. Create uses CREATE OR ALTER, which keeps grants.
    Snowflake refuses a language change (001521): drop the function first.
  #}

  {{ return(adapter.dispatch('update_udf', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_udf(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_udf not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_udf(resource_config) %}
  {{ return(dbt_drift.create_udf(resource_config)) }}
{% endmacro %}
