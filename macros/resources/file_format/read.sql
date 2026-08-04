{% macro read_file_format(resource_config) %}
  {#
    Read the current state of a file format from the warehouse.

    DESCRIBE FILE FORMAT returns one row per property (property / property_value).
    We pivot those rows and project down to the options present in config (plus
    type) so needs_update compares like-for-like instead of drowning in the
    dozens of defaulted properties Snowflake reports.
  #}

  {{ return(adapter.dispatch('read_file_format', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__read_file_format(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("read_file_format not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__read_file_format(resource_config) %}
  {% set resource_name = resource_config.name if resource_config is mapping else resource_config %}

  {# DESCRIBE errors on a missing object, so confirm existence via SHOW first #}
  {% set show_sql %}
    show file formats like '{{ resource_name }}' in schema {{ target.database }}.{{ target.schema }}
  {% endset %}
  {% set existing = run_query(show_sql) %}

  {% if not existing or existing.rows | length == 0 %}
    {{ return(none) }}
  {% endif %}

  {% set describe_sql %}
    describe file format {{ target.database }}.{{ target.schema }}.{{ resource_name }}
  {% endset %}
  {% set result = run_query(describe_sql) %}

  {% if not result or result.rows | length == 0 %}
    {{ return(none) }}
  {% endif %}

  {# Pivot the key/value property rows into a dict keyed by lower-cased property #}
  {% set props = {} %}
  {% for row in result.rows %}
    {% do props.update({row['property'] | lower: row['property_value']}) %}
  {% endfor %}

  {# Project to the configured options (+ type) so keys align with desired state.
     The comment comes from SHOW - DESCRIBE reports format options only. #}
  {% set reserved = ['name', 'type', 'comment'] %}
  {% set state = {
    'type': (props.get('type') or '') | lower,
    'comment': existing.rows[0]['comment']
  } %}
  {% if resource_config is mapping %}
    {% for key, value in resource_config.items() %}
      {% if key not in reserved %}
        {% do state.update({key: props.get(key)}) %}
      {% endif %}
    {% endfor %}
  {% endif %}

  {{ return(state) }}

{% endmacro %}
