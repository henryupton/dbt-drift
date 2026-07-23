{% macro read_stored_procedure(resource_config) %}
  {#
    Read the current state of a stored procedure from the warehouse.

    Args:
      resource_config: The desired-state config (dict with at least 'name';
        'arguments' is used to disambiguate overloaded procedures)

    Returns:
      Dictionary with procedure metadata (types canonicalized), or none
  #}

  {{ return(adapter.dispatch('read_stored_procedure', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__read_stored_procedure(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("read_stored_procedure not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__read_stored_procedure(resource_config) %}
  {% set resource_name = resource_config.name if resource_config is mapping else resource_config %}

  {% set query %}
    select
      procedure_name,
      procedure_language,
      procedure_definition,
      argument_signature,
      data_type as return_type
    from {{ target.database }}.information_schema.procedures
    where procedure_name = upper('{{ resource_name }}')
      and procedure_schema = upper('{{ target.schema }}')
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
    'name': row['PROCEDURE_NAME'] | lower,
    'language': row['PROCEDURE_LANGUAGE'] | lower,
    'definition': row['PROCEDURE_DEFINITION'] | lower,
    'arguments': dbt_drift.canonicalize_types(row['ARGUMENT_SIGNATURE']),
    'returns': dbt_drift.canonicalize_types(row['RETURN_TYPE'])
  } %}
  {{ return(state) }}

{% endmacro %}
