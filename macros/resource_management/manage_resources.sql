{% macro manage_resources(resource_type, show_drift=true, reconcile_drift=false) %}
  {#
    Core macro for managing external resources in dbt.

    Builds a plan of actions (create / update / delete / no_change) by comparing
    the desired config against the actual warehouse state, then:
      - logs the drift        (when show_drift)
      - applies the actions    (when reconcile_drift)

    Deletion is orphan-based: a resource is only dropped if the warehouse
    reports it as dbt-drift-managed (see managed_marker) and it no longer
    appears in config. Objects created outside dbt-drift are never touched.

    Args:
      resource_type:   Type of resource to manage (e.g. 'udf')
      show_drift:      Log the planned actions
      reconcile_drift: Apply the planned actions

    Returns:
      A list of action dicts: {resource_type, name, action, config}

    Usage:
      dbt run-operation dbt_drift.manage_resources --args '{resource_type: udf}'
  #}

  {% set desired = dbt_drift.load_resource_configs(resource_type) %}
  {% set actions = [] %}
  {% set configured_names = [] %}

  {# Plan create / update / no_change for each configured resource #}
  {% for resource in desired %}
    {% do configured_names.append(resource.name | lower) %}

    {% set current_state = dbt_drift.read_resource(resource_type, resource) %}
    {% set desired_state = dbt_drift.normalize_resource(resource_type, resource) %}

    {% if current_state is none %}
      {% do actions.append({'resource_type': resource_type, 'name': resource.name, 'action': 'create', 'config': resource}) %}
    {% elif dbt_drift.needs_update(current_state, desired_state) %}
      {% do actions.append({'resource_type': resource_type, 'name': resource.name, 'action': 'update', 'config': resource}) %}
    {% else %}
      {% do actions.append({'resource_type': resource_type, 'name': resource.name, 'action': 'no_change', 'config': resource}) %}
    {% endif %}
  {% endfor %}

  {# Plan deletes for managed orphans (only if listing is supported) #}
  {% set managed = dbt_drift.list_resource(resource_type) %}
  {% if managed is not none %}
    {% for obj in managed %}
      {% if obj.name | lower not in configured_names %}
        {% do actions.append({'resource_type': resource_type, 'name': obj.name, 'action': 'delete', 'config': obj}) %}
      {% endif %}
    {% endfor %}
  {% endif %}

  {# Report #}
  {% if show_drift %}
    {% set reported = namespace(n=0) %}
    {% for action in actions %}
      {% if action.action != 'no_change' %}
        {% set reported.n = reported.n + 1 %}
        {{ log("  [drift] " ~ action.action ~ " " ~ resource_type ~ " " ~ action.name, info=true) }}
      {% endif %}
    {% endfor %}
    {% if reported.n == 0 %}
      {{ log("  no drift for " ~ resource_type, info=true) }}
    {% endif %}
  {% endif %}

  {# Apply #}
  {% if reconcile_drift %}
    {% for action in actions %}
      {% if action.action == 'create' %}
        {{ log("Creating " ~ resource_type ~ ": " ~ action.name, info=true) }}
        {% do dbt_drift.create_resource(resource_type, action.config) %}
      {% elif action.action == 'update' %}
        {{ log("Updating " ~ resource_type ~ ": " ~ action.name, info=true) }}
        {% do dbt_drift.update_resource(resource_type, action.config) %}
      {% elif action.action == 'delete' %}
        {{ log("Deleting orphaned " ~ resource_type ~ ": " ~ action.name, info=true) }}
        {% do dbt_drift.delete_resource(resource_type, action.config) %}
      {% endif %}
    {% endfor %}
  {% endif %}

  {{ return(actions) }}

{% endmacro %}
