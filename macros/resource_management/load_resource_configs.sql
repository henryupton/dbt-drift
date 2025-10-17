{% macro load_resource_configs(resource_type) %}
  {#
    Load resource configurations from dbt_drift vars

    Structure: var('dbt_drift').resources[resource_type][object_name] = config
    Returns: List of configs with 'name' added to each
  #}

  {% set dbt_drift_vars = var('dbt_drift', {}) %}
  {% set resources = dbt_drift_vars.get('resources', {}) %}
  {% set resource_configs = resources.get(resource_type, {}) %}

  {% if resource_configs|length == 0 %}
    {{ return([]) }}
  {% endif %}

  {# Transform dict to list, adding 'name' to each config #}
  {% set config_list = [] %}
  {% for resource_name, config in resource_configs.items() %}
    {% set config_with_name = {'name': resource_name} %}
    {% for key, value in config.items() %}
      {% do config_with_name.update({key: value}) %}
    {% endfor %}
    {% do config_list.append(config_with_name) %}
  {% endfor %}

  {{ return(config_list) }}

{% endmacro %}
