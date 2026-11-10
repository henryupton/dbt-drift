{% macro update_row_access_policy(resource_config) %}
  {#
    Update an existing row access policy. Create uses CREATE OR ALTER, which changes
    the body and comment while the policy is attached to a table or view. Snowflake
    refuses a signature change there (001521): drop the policy to change one.
  #}

  {{ return(adapter.dispatch('update_row_access_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_row_access_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_row_access_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_row_access_policy(resource_config) %}
  {{ return(dbt_drift.create_row_access_policy(resource_config)) }}
{% endmacro %}
