{% macro update_stored_procedure(resource_config) %}
  {#
    Update an existing stored procedure.
    Snowflake supports CREATE OR REPLACE, so update delegates to create.
  #}

  {{ return(adapter.dispatch('update_stored_procedure', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_stored_procedure(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_stored_procedure not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_stored_procedure(resource_config) %}
  {# Snowflake uses CREATE OR REPLACE, so update is the same as create #}
  {{ return(dbt_drift.create_stored_procedure(resource_config)) }}
{% endmacro %}
