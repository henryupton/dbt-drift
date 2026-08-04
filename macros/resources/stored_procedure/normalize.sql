{% macro normalize_stored_procedure(resource_config) %}
  {#
    Normalize a stored procedure config for comparison against warehouse-read
    state. Canonicalizes the return type and argument types so config values
    like `number` compare equal to the warehouse's widened `NUMBER(38,0)`.
  #}

  {{ return(adapter.dispatch('normalize_stored_procedure', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__normalize_stored_procedure(resource_config) %}
  {{ return(resource_config) }}
{% endmacro %}


{% macro snowflake__normalize_stored_procedure(resource_config) %}
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

  {{ return(normalized) }}
{% endmacro %}
