{% macro run() %}
  {#
    Entrypoint macro that manages all configured resources.
    Automatically detects resource types from configuration.

    Behaviour is controlled by two vars (under vars.dbt_drift):
      - show_drift      (default true):  log the drift between config and warehouse
      - reconcile_drift (default false): apply changes to make the warehouse match config

    By default dbt-drift reports drift but changes nothing. Set reconcile_drift
    to true to apply create / update / delete actions.

    Usage:
      dbt run-operation dbt_drift.run
      dbt run-operation dbt_drift.run --vars '{dbt_drift: {reconcile_drift: true}}'
      Or in on-run-start: "{{ dbt_drift.run() }}"
  #}

  {# Only run during execute phase, not during parsing #}
  {% if not execute %}
    {{ return('') }}
  {% endif %}

  {% set dbt_drift_vars = var('dbt_drift', {}) %}
  {% set resources = dbt_drift_vars.get('resources', {}) %}
  {% set show_drift = dbt_drift_vars.get('show_drift', true) %}
  {% set reconcile_drift = dbt_drift_vars.get('reconcile_drift', false) %}

  {% if resources | length == 0 %}
    {{ log("No resources configured in vars.dbt_drift.resources", info=true) }}
    {{ return('') }}
  {% endif %}

  {{ log("=" * 60, info=true) }}
  {{ log("dbt-drift: Managing resources (show_drift=" ~ show_drift ~ ", reconcile_drift=" ~ reconcile_drift ~ ")", info=true) }}
  {{ log("=" * 60, info=true) }}

  {% set all_actions = [] %}
  {% for resource_type in resources.keys() %}
    {{ log("Processing resource type: " ~ resource_type, info=true) }}
    {% set actions = dbt_drift.manage_resources(resource_type, show_drift, reconcile_drift) %}
    {% do all_actions.extend(actions) %}
  {% endfor %}

  {# Summarize #}
  {% set counts = {'create': 0, 'update': 0, 'delete': 0, 'no_change': 0} %}
  {% for action in all_actions %}
    {% do counts.update({action.action: counts[action.action] + 1}) %}
  {% endfor %}

  {{ log("=" * 60, info=true) }}
  {% if reconcile_drift %}
    {{ log("dbt-drift: Applied " ~ counts['create'] ~ " created, " ~ counts['update'] ~ " updated, " ~ counts['delete'] ~ " deleted, " ~ counts['no_change'] ~ " unchanged", info=true) }}
  {% else %}
    {% set drifted = counts['create'] + counts['update'] + counts['delete'] %}
    {{ log("dbt-drift: " ~ drifted ~ " resource(s) drifted (" ~ counts['create'] ~ " to create, " ~ counts['update'] ~ " to update, " ~ counts['delete'] ~ " to delete). Set reconcile_drift: true to apply.", info=true) }}
  {% endif %}
  {{ log("=" * 60, info=true) }}

  {{ return(all_actions) }}

{% endmacro %}
