{% macro create_stored_procedure(resource_config) %}
  {#
    Create a stored procedure in the warehouse.

    Args:
      resource_config: Dictionary containing the procedure configuration
        - name: Procedure name
        - arguments: Procedure arguments (e.g. "id number, label string")
        - returns: Return type
        - language: sql or javascript (inline-body languages)
        - definition: Procedure body
        - comment: Optional description

    Scope: inline-body procedures (SQL scripting, JavaScript). Handler-based
    languages (Python/Java/Scala) needing runtime_version/packages/handler are
    not yet supported.
  #}

  {{ return(adapter.dispatch('create_stored_procedure', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__create_stored_procedure(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("create_stored_procedure not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__create_stored_procedure(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set marker = dbt_drift.managed_marker() %}
  {% set user_comment = resource_config.get('comment') %}
  {% set full_comment = (user_comment ~ ' | ' ~ marker) if user_comment else marker %}
  {% set safe_comment = full_comment | replace("'", "''") %}

  {% set create_sql %}
    create or replace procedure {{ target.schema }}.{{ resource_config.name }}(
      {{ resource_config.arguments }}
    )
    returns {{ resource_config.returns }}
    language {{ resource_config.language | default('sql') }}
    comment = '{{ safe_comment }}'
    as
    $$
    {{ resource_config.definition }}
    $$
  {% endset %}

  {% do run_query(create_sql) %}
  {{ log("Created stored_procedure: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}

{% endmacro %}
