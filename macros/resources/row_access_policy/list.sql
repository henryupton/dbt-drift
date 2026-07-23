{% macro list_row_access_policy() %}
  {#
    List the row access policies in the target schema managed by dbt-drift.
    Returns a list of dicts: {'name': <lower>}
  #}

  {{ return(adapter.dispatch('list_row_access_policy', 'dbt_drift')()) }}

{% endmacro %}


{% macro default__list_row_access_policy() %}
  {# Listing not supported - orphan detection is skipped for this adapter #}
  {{ return(none) }}
{% endmacro %}


{% macro snowflake__list_row_access_policy() %}
  {% set marker = dbt_drift.managed_marker() %}

  {% set query %}
    show row access policies in schema {{ target.database }}.{{ target.schema }}
  {% endset %}

  {% set result = run_query(query) %}
  {% set managed = [] %}

  {% if result %}
    {% for row in result.rows %}
      {% set comment = row['comment'] %}
      {% if comment is not none and marker in comment %}
        {% do managed.append({'name': row['name'] | lower}) %}
      {% endif %}
    {% endfor %}
  {% endif %}

  {{ return(managed) }}
{% endmacro %}
