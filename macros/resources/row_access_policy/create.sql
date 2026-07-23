{% macro create_row_access_policy(resource_config) %}
  {#
    Create a row access policy in the warehouse.

    Args:
      resource_config: Dictionary containing the policy configuration
        - name: Policy name
        - signature: Policy arguments (e.g. "region string, dept string")
        - body: Boolean SQL expression controlling row visibility
        - comment: Optional description
  #}

  {{ return(adapter.dispatch('create_row_access_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__create_row_access_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("create_row_access_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__create_row_access_policy(resource_config) %}
  {# Snowflake-specific implementation #}

  {# Stamp the managed marker into the comment so dbt-drift can recognize this
     object later for drift/orphan detection. #}
  {% set marker = dbt_drift.managed_marker() %}
  {% set user_comment = resource_config.get('comment') %}
  {% set full_comment = (user_comment ~ ' | ' ~ marker) if user_comment else marker %}
  {% set safe_comment = full_comment | replace("'", "''") %}

  {% set create_sql %}
    create or replace row access policy {{ target.schema }}.{{ resource_config.name }}
      as ({{ resource_config.signature }})
      returns boolean ->
      {{ resource_config.body }}
    comment = '{{ safe_comment }}'
  {% endset %}

  {% do run_query(create_sql) %}
  {{ log("Created row_access_policy: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}

{% endmacro %}
