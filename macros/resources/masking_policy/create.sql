{% macro create_masking_policy(resource_config) %}
  {#
    Create a masking policy in the warehouse.

    Args:
      resource_config: Dictionary containing the policy configuration
        - name: Policy name
        - signature: Policy arguments (e.g. "val string"); the first arg is the
          column being masked
        - returns: Return type (must match the first argument's type)
        - body: SQL expression producing the masked value
        - comment: Optional description
  #}

  {{ return(adapter.dispatch('create_masking_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__create_masking_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("create_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__create_masking_policy(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set marker = dbt_drift.managed_marker() %}
  {% set user_comment = resource_config.get('comment') %}
  {% set full_comment = (user_comment ~ ' | ' ~ marker) if user_comment else marker %}
  {% set safe_comment = full_comment | replace("'", "''") %}

  {% set create_sql %}
    create or replace masking policy {{ target.schema }}.{{ resource_config.name }}
      as ({{ resource_config.signature }})
      returns {{ resource_config.returns }} ->
      {{ resource_config.body }}
    comment = '{{ safe_comment }}'
  {% endset %}

  {% do run_query(create_sql) %}
  {{ log("Created masking_policy: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}

{% endmacro %}
