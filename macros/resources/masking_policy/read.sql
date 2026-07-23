{% macro read_masking_policy(resource_config) %}
  {#
    Read the current state of a masking policy from the warehouse.

    Returns:
      Dictionary with policy metadata (types canonicalized), or none if not found
  #}

  {{ return(adapter.dispatch('read_masking_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__read_masking_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("read_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__read_masking_policy(resource_config) %}
  {% set resource_name = resource_config.name if resource_config is mapping else resource_config %}

  {# DESCRIBE errors on a missing policy, so confirm existence via SHOW first #}
  {% set show_sql %}
    show masking policies like '{{ resource_name }}' in schema {{ target.database }}.{{ target.schema }}
  {% endset %}
  {% set existing = run_query(show_sql) %}

  {% if not existing or existing.rows | length == 0 %}
    {{ return(none) }}
  {% endif %}

  {% set describe_sql %}
    describe masking policy {{ target.database }}.{{ target.schema }}.{{ resource_name }}
  {% endset %}
  {% set result = run_query(describe_sql) %}

  {% if not result or result.rows | length == 0 %}
    {{ return(none) }}
  {% endif %}

  {# SHOW / DESCRIBE metadata commands return lower-cased column names #}
  {% set row = result.rows[0] %}
  {% set state = {
    'name': row['name'] | lower,
    'signature': dbt_drift.canonicalize_types(row['signature']),
    'returns': dbt_drift.canonicalize_types(row['return_type']),
    'body': row['body'] | lower
  } %}
  {{ return(state) }}

{% endmacro %}
