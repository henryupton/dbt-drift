{% macro create_file_format(resource_config) %}
  {#
    Create a file format in the warehouse.

    Config is flat: `type` and `comment` are reserved; every other key is
    treated as a Snowflake format option (e.g. field_delimiter, skip_header).

    Only scalar options (string / number / boolean) are supported. List-valued
    options such as NULL_IF are not yet supported and raise a clear error.
  #}

  {{ return(adapter.dispatch('create_file_format', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__create_file_format(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("create_file_format not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro render_file_format_option(key, value) %}
  {#
    Render a single file format option value for DDL:
      string  -> quoted    boolean -> bare true/false    number -> bare
    Anything else (e.g. a list) is not yet supported.
    NB: check boolean before number - a bool is a number in Jinja.
  #}
  {% if value is boolean %}
    {{ return('true' if value else 'false') }}
  {% elif value is number %}
    {{ return(value) }}
  {% elif value is string %}
    {{ return("'" ~ (value | replace("'", "''")) ~ "'") }}
  {% else %}
    {{ exceptions.raise_compiler_error(
      "file_format option '" ~ key ~ "' has an unsupported value type. Only string, number and boolean options are supported (list-valued options like NULL_IF are not yet supported)."
    ) }}
  {% endif %}
{% endmacro %}


{% macro snowflake__create_file_format(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set marker = dbt_drift.managed_marker() %}
  {% set user_comment = resource_config.get('comment') %}
  {% set full_comment = (user_comment ~ ' | ' ~ marker) if user_comment else marker %}
  {% set safe_comment = full_comment | replace("'", "''") %}

  {% set reserved = ['name', 'type', 'comment'] %}
  {% set option_lines = [] %}
  {% for key, value in resource_config.items() %}
    {% if key not in reserved %}
      {% do option_lines.append(key | upper ~ ' = ' ~ dbt_drift.render_file_format_option(key, value)) %}
    {% endif %}
  {% endfor %}

  {% set create_sql %}
    create or replace file format {{ target.schema }}.{{ resource_config.name }}
      type = {{ resource_config.type }}
      {% for line in option_lines %}
      {{ line }}
      {% endfor %}
      comment = '{{ safe_comment }}'
  {% endset %}

  {% do run_query(create_sql) %}
  {{ log("Created file_format: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}

{% endmacro %}
