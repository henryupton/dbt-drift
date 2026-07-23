{% macro resolve_resource(resource_type, name) %}
  {#
    Resolve a managed resource's short name to its fully-qualified
    `database.schema.name`, so models can reference resources without
    hard-coding the FQN.

    Validates that the resource is configured under
    vars.dbt_drift.resources.{resource_type} and raises a clear error otherwise
    (mirroring how ref() fails on an unknown model).

    This is the shared implementation behind the per-type sugar macros
    (dbt_drift.udf, dbt_drift.row_access_policy, ...).
  #}

  {% set dbt_drift_vars = var('dbt_drift', {}) %}
  {% set resources = dbt_drift_vars.get('resources', {}) %}
  {% set of_type = resources.get(resource_type, {}) %}

  {% if name not in of_type %}
    {{ exceptions.raise_compiler_error(
      "dbt_drift." ~ resource_type ~ "('" ~ name ~ "') is not configured under vars.dbt_drift.resources." ~ resource_type
    ) }}
  {% endif %}

  {{ return(target.database ~ '.' ~ target.schema ~ '.' ~ name) }}

{% endmacro %}
