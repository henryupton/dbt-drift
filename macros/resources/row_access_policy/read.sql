{% macro read_row_access_policy(resource_config) %}
  {#
    Read the current state of a row access policy from the warehouse.

    Args:
      resource_config: The desired-state config (dict with at least 'name')

    Returns:
      Dictionary with policy metadata (types canonicalized), or none if not found
  #}

  {{ return(adapter.dispatch('read_row_access_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__read_row_access_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("read_row_access_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__read_row_access_policy(resource_config) %}
  {% set resource_name = resource_config.name if resource_config is mapping else resource_config %}

  {# DESCRIBE errors on a missing policy, so confirm existence via SHOW first #}
  {% set show_sql %}
    show row access policies like '{{ resource_name }}' in schema {{ target.database }}.{{ target.schema }}
  {% endset %}
  {% set existing = run_query(show_sql) %}

  {% if not existing or existing.rows | length == 0 %}
    {{ return(none) }}
  {% endif %}

  {% set describe_sql %}
    describe row access policy {{ target.database }}.{{ target.schema }}.{{ resource_name }}
  {% endset %}
  {% set result = run_query(describe_sql) %}

  {% if not result or result.rows | length == 0 %}
    {{ return(none) }}
  {% endif %}

  {# SHOW / DESCRIBE metadata commands return lower-cased column names.
     The comment comes from SHOW - DESCRIBE does not report it. #}
  {% set row = result.rows[0] %}
  {% set state = {
    'name': row['name'] | lower,
    'signature': dbt_drift.canonicalize_types(row['signature']),
    'body': row['body'] | lower,
    'comment': existing.rows[0]['comment']
  } %}
  {{ return(state) }}

{% endmacro %}
