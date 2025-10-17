{% macro needs_update(current_state, desired_state) %}
  {#
    Determine if update is needed by comparing states
    Returns true if states differ (update needed)

    Only compares fields that exist in current_state (ignores config-only fields like 'comment')
  #}

  {% if current_state is none %}
    {{ return(true) }}
  {% endif %}

  {# Extract only the fields that exist in current_state from desired_state #}
  {% set desired_comparable = {} %}
  {% for key in current_state.keys() %}
    {% if key in desired_state %}
      {% do desired_comparable.update({key: desired_state[key]}) %}
    {% endif %}
  {% endfor %}

  {# Use compare macro - if they're the same, no update needed #}
  {{ return(not dbt_drift.compare(current_state, desired_comparable)) }}

{% endmacro %}
