{% macro update_masking_policy(resource_config) %}
  {#
    Update an existing masking policy.
    Snowflake supports CREATE OR REPLACE, so update delegates to create.
  #}

  {{ return(adapter.dispatch('update_masking_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_masking_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_masking_policy(resource_config) %}
  {# Snowflake uses CREATE OR REPLACE, so update is the same as create #}
  {{ return(dbt_drift.create_masking_policy(resource_config)) }}
{% endmacro %}
