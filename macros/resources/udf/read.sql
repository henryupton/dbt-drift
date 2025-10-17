{% macro read_udf(resource_name) %}
  {#
    Read the current state of a UDF from the warehouse

    Args:
      resource_name: Name of the UDF to read

    Returns:
      Dictionary with UDF metadata or none if not found
  #}

  {{ return(adapter.dispatch('read_udf', 'dbt_drift')(resource_name)) }}

{% endmacro %}


{% macro default__read_udf(resource_name) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("read_udf not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__read_udf(resource_name) %}
  {# Snowflake-specific implementation #}

  {% set query %}
    select
      function_name,
      function_language,
      function_definition,
      argument_signature,
      data_type as return_type
    from {{ target.database }}.information_schema.functions
    where function_name = upper('{{ resource_name }}')
      and function_schema = upper('{{ target.schema }}')
    limit 1
  {% endset %}

  {% set result = run_query(query) %}

  {% if result and result.rows|length > 0 %}
    {% set row = result.rows[0] %}
    {% set state = {
      'name': row['FUNCTION_NAME'] | lower,
      'language': row['FUNCTION_LANGUAGE'] | lower,
      'definition': row['FUNCTION_DEFINITION'] | lower,
      'arguments': row['ARGUMENT_SIGNATURE'] | lower,
      'returns': row['RETURN_TYPE'] | lower
    } %}
    {{ return(state) }}
  {% else %}
    {{ return(none) }}
  {% endif %}

{% endmacro %}
