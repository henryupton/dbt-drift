{% macro normalize_udf(resource_config) %}
  {#
    Normalize a UDF config for comparison against warehouse-read state.
    Canonicalizes the return type and argument types so config values like
    `number` / `timestamp_tz(9)` compare equal to the warehouse's widened
    `NUMBER(38,0)` / `TIMESTAMP_TZ(9)`.
  #}

  {{ return(adapter.dispatch('normalize_udf', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__normalize_udf(resource_config) %}
  {{ return(resource_config) }}
{% endmacro %}


{% macro snowflake__normalize_udf(resource_config) %}
  {% set normalized = {} %}
  {% for key, value in resource_config.items() %}
    {% do normalized.update({key: value}) %}
  {% endfor %}

  {% if normalized.get('returns') is string %}
    {% do normalized.update({'returns': dbt_drift.canonicalize_types(normalized['returns'])}) %}
  {% endif %}

  {% if normalized.get('arguments') is string %}
    {% do normalized.update({'arguments': dbt_drift.canonicalize_types(normalized['arguments'])}) %}
  {% endif %}

  {# The warehouse comment carries the managed marker, so compare against the
     stamped form rather than the bare config comment. #}
  {% do normalized.update({'comment': dbt_drift.stamped_comment(resource_config)}) %}

  {# YAML reads an unquoted 3.10 as the float 3.1, which no runtime matches. #}
  {% if normalized.get('runtime_version') is not none and normalized.get('runtime_version') is not string %}
    {{ exceptions.raise_compiler_error(
        "dbt_drift udf " ~ resource_config.name ~ ": quote runtime_version (e.g. '3.11'), got " ~ normalized.get('runtime_version')
    ) }}
  {% endif %}

  {# The warehouse reports packages for every handler-language UDF (empty when
     none are declared), so the config side always needs the key to compare. #}
  {% if (normalized.get('language') or 'sql') | lower in ['python', 'java', 'scala'] %}
    {% do normalized.update({'packages': dbt_drift.udf_package_list(normalized.get('packages'))}) %}
  {% endif %}

  {{ return(normalized) }}
{% endmacro %}


{% macro udf_package_list(packages) %}
  {#
    Canonical package list for a handler-language UDF: none -> [], a bare
    string -> [string], items trimmed and sorted so declaration order is not
    drift. Used on both sides of the comparison and when emitting PACKAGES.
  #}
  {% if packages is none %}
    {{ return([]) }}
  {% endif %}
  {% if packages is string %}
    {% set packages = [packages] %}
  {% endif %}

  {% set cleaned = [] %}
  {% for p in packages %}
    {% if p is not none and (p | string | trim) != '' %}
      {% do cleaned.append(p | string | trim) %}
    {% endif %}
  {% endfor %}
  {{ return(cleaned | sort) }}
{% endmacro %}
