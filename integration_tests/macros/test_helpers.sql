{% macro delete_test_resources() %}
  {#
    Clean up resources created during integration testing.
    Drops every UDF that dbt-drift manages in the target schema (identified by
    the managed marker), so it works regardless of the current config.
  #}

  {% set managed = dbt_drift.list_resource('udf') %}

  {% if managed is none %}
    {{ log("Listing not supported for this adapter; nothing to clean up", info=true) }}
    {{ return('') }}
  {% endif %}

  {% for obj in managed %}
    {{ log("Deleting test resource: " ~ obj.name, info=true) }}
    {% do dbt_drift.delete_resource('udf', obj) %}
  {% endfor %}

  {{ log("Test cleanup complete (" ~ managed | length ~ " resources)", info=true) }}

{% endmacro %}


{% macro verify_resources() %}
  {#
    Verify that all configured resources exist and match configuration.
    Raises a compiler error if any resource is missing or has drifted.
  #}

  {% set resources = dbt_drift.load_resource_configs('udf') %}
  {% set failures = [] %}

  {% for resource in resources %}
    {% set current_state = dbt_drift.read_resource('udf', resource) %}
    {% set desired_state = dbt_drift.normalize_resource('udf', resource) %}

    {% if current_state is none %}
      {% do failures.append(resource.name) %}
      {{ log("FAIL: " ~ resource.name ~ " does not exist", info=true) }}
    {% elif dbt_drift.needs_update(current_state, desired_state) %}
      {% do failures.append(resource.name) %}
      {{ log("FAIL: " ~ resource.name ~ " has drift", info=true) }}
    {% else %}
      {{ log("PASS: " ~ resource.name ~ " is correct", info=true) }}
    {% endif %}
  {% endfor %}

  {% if failures | length > 0 %}
    {{ exceptions.raise_compiler_error("Verification failed: " ~ failures | length ~ " resource(s) have issues: " ~ failures | join(', ')) }}
  {% else %}
    {{ log("All resources verified successfully", info=true) }}
  {% endif %}

{% endmacro %}
