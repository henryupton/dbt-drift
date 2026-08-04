{% macro normalize_file_format(resource_config) %}
  {#
    Normalize a file format config for comparison against warehouse-read state.
    DESCRIBE returns every property_value as a string, so we stringify the
    configured option values (leaving the reserved keys alone). Case and
    whitespace differences are handled downstream by compare().
  #}

  {{ return(adapter.dispatch('normalize_file_format', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__normalize_file_format(resource_config) %}
  {{ return(resource_config) }}
{% endmacro %}


{% macro snowflake__normalize_file_format(resource_config) %}
  {% set reserved = ['name', 'type', 'comment'] %}
  {% set normalized = {} %}
  {% for key, value in resource_config.items() %}
    {% if key in reserved %}
      {% do normalized.update({key: value}) %}
    {% else %}
      {% do normalized.update({key: value | string}) %}
    {% endif %}
  {% endfor %}

  {# The warehouse comment carries the managed marker, so compare against the
     stamped form rather than the bare config comment. #}
  {% do normalized.update({'comment': dbt_drift.stamped_comment(resource_config)}) %}

  {{ return(normalized) }}
{% endmacro %}
