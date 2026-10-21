{% macro create_udf(resource_config) %}
  {#
    Create a new UDF in the warehouse

    Args:
      resource_config: Dictionary containing UDF configuration
        - name: UDF name
        - arguments: Function arguments (e.g., "x number, y number")
        - returns: Return type
        - language: sql, javascript, python, java or scala
        - definition: Function body
        - comment: Optional description
        - runtime_version: Handler-language runtime (e.g. "3.11"), quoted
        - handler: Handler function or class.method
        - packages: List of packages (e.g. ["snowballstemmer"])
  #}

  {{ return(adapter.dispatch('create_udf', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__create_udf(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("create_udf not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__create_udf(resource_config) %}
  {# Snowflake-specific implementation #}

  {# Stamp the managed marker into the comment so dbt-drift can recognize this
     object later for drift/orphan detection. #}
  {% set safe_comment = dbt_drift.stamped_comment(resource_config) | replace("'", "''") %}
  {% set packages = dbt_drift.udf_package_list(resource_config.get('packages')) %}

  {# The body is emitted at column 0: Python is indentation-sensitive, and an
     indented first line is a syntax error. #}
  {% set create_sql %}
    create or replace function {{ target.database }}.{{ target.schema }}.{{ resource_config.name }}(
      {{ resource_config.arguments }}
    )
    returns {{ resource_config.returns }}
    language {{ resource_config.language | default('sql') }}
    {%- if resource_config.get('runtime_version') %}
    runtime_version = '{{ resource_config.runtime_version }}'
    {%- endif %}
    {%- if packages %}
    packages = ({% for p in packages %}'{{ p }}'{{ ', ' if not loop.last }}{% endfor %})
    {%- endif %}
    {%- if resource_config.get('handler') %}
    handler = '{{ resource_config.handler }}'
    {%- endif %}
    comment = '{{ safe_comment }}'
    as
$$
{{ resource_config.definition }}
$$
  {% endset %}

  {% do run_query(create_sql) %}
  {{ log("Created UDF: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}

{% endmacro %}
