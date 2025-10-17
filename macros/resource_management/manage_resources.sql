{% macro manage_resources(resource_type) %}
  {#
    Core macro for managing external resources in dbt

    Args:
      resource_type: Type of resource to manage (e.g., 'udf', 'masking_policy')

    Usage:
      dbt run-operation manage_resources --args '{resource_type: udf}'
  #}

  {% set resources = dbt_drift.load_resource_configs(resource_type) %}
  {% set results = [] %}

  {% for resource in resources %}
    {% set current_state = dbt_drift.read_resource(resource_type, resource.name) %}
    {% set desired_state = resource %}

    {% if current_state is none %}
      {{ log("Creating " ~ resource_type ~ ": " ~ resource.name, info=true) }}
      {% do dbt_drift.create_resource(resource_type, resource) %}
      {% do results.append({'action': 'created', 'resource': resource.name}) %}
    {% elif dbt_drift.needs_update(current_state, desired_state) %}
      {{ log("Updating " ~ resource_type ~ ": " ~ resource.name, info=true) }}
      {% do dbt_drift.update_resource(resource_type, resource) %}
      {% do results.append({'action': 'updated', 'resource': resource.name}) %}
    {% else %}
      {{ log(resource_type ~ " " ~ resource.name ~ " is up to date", info=true) }}
      {% do results.append({'action': 'no_change', 'resource': resource.name}) %}
    {% endif %}
  {% endfor %}

  {{ log("Resource management complete. Summary: " ~ results|length ~ " resources processed", info=true) }}

{% endmacro %}
