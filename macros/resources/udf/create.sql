{% macro create_udf(resource_config) %}
  {#
    Create a new UDF in the warehouse

    Args:
      resource_config: Dictionary containing UDF configuration
        - name: UDF name
        - arguments: Function arguments (e.g., "x number, y number")
        - returns: Return type
        - language: sql, javascript, or python
        - definition: Function body
        - comment: Optional description
  #}

  {{ return(adapter.dispatch('create_udf', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__create_udf(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("create_udf not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__create_udf(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set create_sql %}
    create or replace function {{ target.schema }}.{{ resource_config.name }}(
      {{ resource_config.arguments }}
    )
    returns {{ resource_config.returns }}
    language {{ resource_config.language | default('sql') }}
    {% if resource_config.comment %}
    comment = '{{ resource_config.comment }}'
    {% endif %}
    as
    $$
    {{ resource_config.definition }}
    $$
  {% endset %}

  {% do run_query(create_sql) %}
  {{ log("Created UDF: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}

{% endmacro %}
