{% macro normalize_row_access_policy(resource_config) %}
  {#
    Normalize a row access policy config for comparison against warehouse-read
    state. Canonicalizes the argument/signature types so config values like
    `region string` compare equal to the warehouse's `(REGION VARCHAR)`.
  #}

  {{ return(adapter.dispatch('normalize_row_access_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__normalize_row_access_policy(resource_config) %}
  {{ return(resource_config) }}
{% endmacro %}


{% macro snowflake__normalize_row_access_policy(resource_config) %}
  {% set normalized = {} %}
  {% for key, value in resource_config.items() %}
    {% do normalized.update({key: value}) %}
  {% endfor %}

  {% if normalized.get('signature') is string %}
    {% do normalized.update({'signature': dbt_drift.canonicalize_types(normalized['signature'])}) %}
  {% endif %}

  {{ return(normalized) }}
{% endmacro %}
