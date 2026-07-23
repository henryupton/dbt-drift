{% macro delete_test_resources() %}
  {#
    Clean up resources created during integration testing.
    Drops every dbt-drift-managed resource (identified by the managed marker)
    across every configured resource type, so it works regardless of config.
  #}

  {% set resources = var('dbt_drift', {}).get('resources', {}) %}
  {% set total = namespace(n=0) %}

  {% for resource_type in resources.keys() %}
    {% set managed = dbt_drift.list_resource(resource_type) %}
    {% if managed is none %}
      {{ log("Listing not supported for " ~ resource_type ~ "; skipping", info=true) }}
    {% else %}
      {% for obj in managed %}
        {{ log("Deleting " ~ resource_type ~ ": " ~ obj.name, info=true) }}
        {% do dbt_drift.delete_resource(resource_type, obj) %}
        {% set total.n = total.n + 1 %}
      {% endfor %}
    {% endif %}
  {% endfor %}

  {{ log("Test cleanup complete (" ~ total.n ~ " resources)", info=true) }}

{% endmacro %}


{% macro verify_resources() %}
  {#
    Verify that every configured resource exists and matches configuration,
    across all resource types. Raises a compiler error on any miss or drift.
  #}

  {% set resources = var('dbt_drift', {}).get('resources', {}) %}
  {% set failures = [] %}

  {% for resource_type in resources.keys() %}
    {% set configs = dbt_drift.load_resource_configs(resource_type) %}
    {% for resource in configs %}
      {% set current_state = dbt_drift.read_resource(resource_type, resource) %}
      {% set desired_state = dbt_drift.normalize_resource(resource_type, resource) %}

      {% if current_state is none %}
        {% do failures.append(resource_type ~ '.' ~ resource.name ~ ' (missing)') %}
        {{ log("FAIL: " ~ resource_type ~ "." ~ resource.name ~ " does not exist", info=true) }}
      {% elif dbt_drift.needs_update(current_state, desired_state) %}
        {% do failures.append(resource_type ~ '.' ~ resource.name ~ ' (drift)') %}
        {{ log("FAIL: " ~ resource_type ~ "." ~ resource.name ~ " has drift", info=true) }}
      {% else %}
        {{ log("PASS: " ~ resource_type ~ "." ~ resource.name, info=true) }}
      {% endif %}
    {% endfor %}
  {% endfor %}

  {% if failures | length > 0 %}
    {{ exceptions.raise_compiler_error("Verification failed: " ~ failures | join(', ')) }}
  {% else %}
    {{ log("All resources verified successfully", info=true) }}
  {% endif %}

{% endmacro %}
