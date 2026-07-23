{% macro list_udf() %}
  {#
    List the UDFs in the target schema that are managed by dbt-drift.

    Returns a list of dicts: {'name': <lower>, 'arg_types': <types-only signature>}
    The arg_types are used to build an unambiguous DROP FUNCTION signature.
  #}

  {{ return(adapter.dispatch('list_udf', 'dbt_drift')()) }}

{% endmacro %}


{% macro default__list_udf() %}
  {# Listing not supported - orphan detection is skipped for this adapter #}
  {{ return(none) }}
{% endmacro %}


{% macro snowflake__list_udf() %}
  {% set marker = dbt_drift.managed_marker() %}

  {% set query %}
    select
      function_name,
      argument_signature
    from {{ target.database }}.information_schema.functions
    where function_schema = upper('{{ target.schema }}')
      and comment ilike '%{{ marker }}%'
  {% endset %}

  {% set result = run_query(query) %}
  {% set managed = [] %}

  {% if result %}
    {% for row in result.rows %}
      {% set arg_types = dbt_drift.arg_types_from_signature(row['ARGUMENT_SIGNATURE']) %}
      {% do managed.append({
        'name': row['FUNCTION_NAME'] | lower,
        'arg_types': arg_types
      }) %}
    {% endfor %}
  {% endif %}

  {{ return(managed) }}
{% endmacro %}
