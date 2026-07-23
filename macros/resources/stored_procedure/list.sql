{% macro list_stored_procedure() %}
  {#
    List the stored procedures in the target schema managed by dbt-drift.

    Returns a list of dicts: {'name': <lower>, 'arg_types': <types-only signature>}
  #}

  {{ return(adapter.dispatch('list_stored_procedure', 'dbt_drift')()) }}

{% endmacro %}


{% macro default__list_stored_procedure() %}
  {# Listing not supported - orphan detection is skipped for this adapter #}
  {{ return(none) }}
{% endmacro %}


{% macro snowflake__list_stored_procedure() %}
  {% set marker = dbt_drift.managed_marker() %}

  {% set query %}
    select
      procedure_name,
      argument_signature
    from {{ target.database }}.information_schema.procedures
    where procedure_schema = upper('{{ target.schema }}')
      and comment ilike '%{{ marker }}%'
  {% endset %}

  {% set result = run_query(query) %}
  {% set managed = [] %}

  {% if result %}
    {% for row in result.rows %}
      {% set arg_types = dbt_drift.arg_types_from_signature(row['ARGUMENT_SIGNATURE']) %}
      {% do managed.append({
        'name': row['PROCEDURE_NAME'] | lower,
        'arg_types': arg_types
      }) %}
    {% endfor %}
  {% endif %}

  {{ return(managed) }}
{% endmacro %}
