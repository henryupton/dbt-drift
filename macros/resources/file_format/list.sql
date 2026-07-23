{% macro list_file_format() %}
  {#
    List the file formats in the target schema managed by dbt-drift.
    Returns a list of dicts: {'name': <lower>}
  #}

  {{ return(adapter.dispatch('list_file_format', 'dbt_drift')()) }}

{% endmacro %}


{% macro default__list_file_format() %}
  {# Listing not supported - orphan detection is skipped for this adapter #}
  {{ return(none) }}
{% endmacro %}


{% macro snowflake__list_file_format() %}
  {% set marker = dbt_drift.managed_marker() %}

  {% set query %}
    show file formats in schema {{ target.database }}.{{ target.schema }}
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
