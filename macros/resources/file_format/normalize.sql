{% macro normalize_file_format(resource_config) %}
  {#
    Normalize a file format config for comparison against warehouse-read state.
    DESCRIBE returns every property_value as a string, so we stringify the
    configured option values (leaving the reserved keys alone). Case and
    whitespace differences are handled downstream by compare().

    List-valued options are rendered into the bracket form DESCRIBE reports
    rather than parsed out of it - see snowflake__render_file_format_list.
  #}

  {{ return(adapter.dispatch('normalize_file_format', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__normalize_file_format(resource_config) %}
  {{ return(resource_config) }}
{% endmacro %}


{% macro snowflake__escape_file_format_value(value) %}
  {#
    DESCRIBE FILE FORMAT reports string values JSON-escaped: a configured `"`
    comes back as `\"`, and the stock NULL_IF value `\N` as `\\N`. Apply the same
    escaping to config values so they compare equal. Backslashes first, or the
    backslash introduced by the quote rule would be escaped in turn.
  #}
  {{ return(value | string | replace('\\', '\\\\') | replace('"', '\\"')) }}
{% endmacro %}


{% macro snowflake__render_file_format_list(value) %}
  {#
    Render a list option the way DESCRIBE FILE FORMAT reports it: bracketed,
    comma-space separated, values UNQUOTED. `('', 'NULL')` comes back as
    `[, NULL]` and `('')` as `[]`.

    Comparing in this rendered form rather than parsing DESCRIBE's output is
    deliberate. `()` and `('')` both report as `[]`, so the warehouse cannot
    distinguish an empty list from a list holding one empty string. Parsing
    would make a configured `['']` compare unequal to `[]` and the resource
    would drift on every single run.
  #}
  {% set elements = [] %}
  {% for element in value %}
    {% do elements.append(dbt_drift.snowflake__escape_file_format_value(element)) %}
  {% endfor %}
  {{ return('[' ~ (elements | join(', ')) ~ ']') }}
{% endmacro %}


{% macro snowflake__normalize_file_format(resource_config) %}
  {% set reserved = ['name', 'type', 'comment'] %}
  {% set normalized = {} %}
  {% for key, value in resource_config.items() %}
    {% if key in reserved %}
      {% do normalized.update({key: value}) %}
    {% elif value is not string and value is sequence %}
      {% do normalized.update({key: dbt_drift.snowflake__render_file_format_list(value)}) %}
    {% elif value is string %}
      {% do normalized.update({key: dbt_drift.snowflake__escape_file_format_value(value)}) %}
    {% else %}
      {% do normalized.update({key: value | string}) %}
    {% endif %}
  {% endfor %}

  {# The warehouse comment carries the managed marker, so compare against the
     stamped form rather than the bare config comment. #}
  {% do normalized.update({'comment': dbt_drift.stamped_comment(resource_config)}) %}

  {{ return(normalized) }}
{% endmacro %}
