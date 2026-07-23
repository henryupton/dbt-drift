{% macro normalize_masking_policy(resource_config) %}
  {#
    Normalize a masking policy config for comparison against warehouse-read
    state. Canonicalizes the signature and return types so config values like
    `val string` / `string` compare equal to the warehouse's widened forms.
  #}

  {{ return(adapter.dispatch('normalize_masking_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__normalize_masking_policy(resource_config) %}
  {{ return(resource_config) }}
{% endmacro %}


{% macro snowflake__normalize_masking_policy(resource_config) %}
  {% set normalized = {} %}
  {% for key, value in resource_config.items() %}
    {% do normalized.update({key: value}) %}
  {% endfor %}

  {% if normalized.get('signature') is string %}
    {% do normalized.update({'signature': dbt_drift.canonicalize_types(normalized['signature'])}) %}
  {% endif %}

  {% if normalized.get('returns') is string %}
    {% do normalized.update({'returns': dbt_drift.canonicalize_types(normalized['returns'])}) %}
  {% endif %}

  {{ return(normalized) }}
{% endmacro %}
