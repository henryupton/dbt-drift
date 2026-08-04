{% macro read_udf(resource_config) %}
  {#
    Read the current state of a UDF from the warehouse.

    Args:
      resource_config: The desired-state config (dict with at least 'name';
        'arguments' is used to disambiguate overloaded functions)

    Returns:
      Dictionary with UDF metadata (types canonicalized), or none if not found
  #}

  {{ return(adapter.dispatch('read_udf', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__read_udf(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("read_udf not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__read_udf(resource_config) %}
  {% set resource_name = resource_config.name if resource_config is mapping else resource_config %}

  {% set query %}
    select
      function_name,
      function_language,
      function_definition,
      argument_signature,
      data_type as return_type,
      comment
    from {{ target.database }}.information_schema.functions
    where function_name = upper('{{ resource_name }}')
      and function_schema = upper('{{ target.schema }}')
  {% endset %}

  {% set result = run_query(query) %}

  {% if not result or result.rows | length == 0 %}
    {{ return(none) }}
  {% endif %}

  {# When arguments are configured, select the matching overload #}
  {% set desired_args = none %}
  {% if resource_config is mapping and resource_config.get('arguments') is not none %}
    {% set desired_args = dbt_drift.canonicalize_types(resource_config.get('arguments')) %}
  {% endif %}

  {% set picked = namespace(row=none) %}
  {% for row in result.rows %}
    {% if picked.row is none %}
      {% if desired_args is none %}
        {% set picked.row = row %}
      {% else %}
        {% set row_args = dbt_drift.canonicalize_types(row['ARGUMENT_SIGNATURE']) %}
        {% if dbt_drift.compare(row_args, desired_args) %}
          {% set picked.row = row %}
        {% endif %}
      {% endif %}
    {% endif %}
  {% endfor %}

  {% if picked.row is none %}
    {{ return(none) }}
  {% endif %}

  {% set row = picked.row %}
  {% set state = {
    'name': row['FUNCTION_NAME'] | lower,
    'language': row['FUNCTION_LANGUAGE'] | lower,
    'definition': row['FUNCTION_DEFINITION'] | lower,
    'arguments': dbt_drift.canonicalize_types(row['ARGUMENT_SIGNATURE']),
    'returns': dbt_drift.canonicalize_types(row['RETURN_TYPE']),
    'comment': row['COMMENT']
  } %}
  {{ return(state) }}

{% endmacro %}
