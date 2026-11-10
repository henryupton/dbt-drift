{% macro update_masking_policy(resource_config) %}
  {#
    Update an existing masking policy. Create uses CREATE OR ALTER, which changes
    the body and comment while the policy is attached to a column. Snowflake
    refuses a signature change there (001521): drop the policy to change one.
  #}

  {{ return(adapter.dispatch('update_masking_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_masking_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_masking_policy(resource_config) %}
  {{ return(dbt_drift.create_masking_policy(resource_config)) }}
{% endmacro %}
