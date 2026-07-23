{% macro smoke_test() %}
  {#
    End-to-end smoke test against a live warehouse. Exercises every configured
    resource type through the full lifecycle and raises on the first failure.

      dbt run-operation smoke_test

    Steps:
      1. reconcile        - create every configured resource
      2. verify           - each exists and matches config
      3. idempotency      - a fresh plan reports ZERO drift (the key check:
                            catches type-widening and column-case bugs)
      4. orphan detection - a managed object dropped from config is pruned,
                            and only that one
      5. cleanup          - drop everything dbt-drift created

    If it fails partway, run `dbt run-operation delete_test_resources` to clean up.
  #}

  {% if not execute %}
    {{ return('') }}
  {% endif %}

  {% set resources = var('dbt_drift', {}).get('resources', {}) %}
  {% set types = resources.keys() | list %}

  {{ log("=" * 60, info=true) }}
  {{ log("dbt-drift smoke test - types: " ~ types | join(', '), info=true) }}
  {{ log("=" * 60, info=true) }}

  {# 1. Reconcile: create everything #}
  {{ log("[1/5] reconcile (create)", info=true) }}
  {% for resource_type in types %}
    {% do dbt_drift.manage_resources(resource_type, show_drift=false, reconcile_drift=true) %}
  {% endfor %}

  {# 2. Verify existence + match #}
  {{ log("[2/5] verify", info=true) }}
  {% do verify_resources() %}

  {# 3. Idempotency: a fresh plan should report no drift #}
  {{ log("[3/5] idempotency (expect zero drift)", info=true) }}
  {% set drifted = [] %}
  {% for resource_type in types %}
    {% set actions = dbt_drift.manage_resources(resource_type, show_drift=false, reconcile_drift=false) %}
    {% for action in actions %}
      {% if action.action != 'no_change' %}
        {% do drifted.append(resource_type ~ '.' ~ action.name ~ ' -> ' ~ action.action) %}
      {% endif %}
    {% endfor %}
  {% endfor %}
  {% if drifted | length > 0 %}
    {{ exceptions.raise_compiler_error("Idempotency FAILED - unexpected drift on a clean re-plan: " ~ drifted | join('; ')) }}
  {% endif %}
  {{ log("  no drift - idempotent", info=true) }}

  {# 4. Orphan detection: create a managed UDF absent from config, reconcile,
       expect it (and only it) to be dropped #}
  {{ log("[4/5] orphan detection", info=true) }}
  {% set orphan = {
    'name': 'dbt_drift_smoke_orphan',
    'arguments': 'x number',
    'returns': 'number',
    'language': 'sql',
    'definition': 'x'
  } %}
  {% do dbt_drift.create_resource('udf', orphan) %}
  {% do dbt_drift.manage_resources('udf', show_drift=false, reconcile_drift=true) %}

  {% if dbt_drift.read_resource('udf', orphan) is not none %}
    {{ exceptions.raise_compiler_error("Orphan detection FAILED - " ~ orphan.name ~ " was not dropped") }}
  {% endif %}
  {# The configured UDFs must still be present (we only drop orphans) #}
  {% for resource in dbt_drift.load_resource_configs('udf') %}
    {% if dbt_drift.read_resource('udf', resource) is none %}
      {{ exceptions.raise_compiler_error("Orphan detection FAILED - it dropped configured UDF " ~ resource.name) }}
    {% endif %}
  {% endfor %}
  {{ log("  orphan dropped, configured resources intact", info=true) }}

  {# 5. Cleanup #}
  {{ log("[5/5] cleanup", info=true) }}
  {% do delete_test_resources() %}

  {{ log("=" * 60, info=true) }}
  {{ log("SMOKE TEST PASSED", info=true) }}
  {{ log("=" * 60, info=true) }}

{% endmacro %}
