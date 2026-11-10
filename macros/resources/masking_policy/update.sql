{% macro update_masking_policy(resource_config) %}
  {#
    Update an existing masking policy in place.

    Snowflake refuses CREATE OR REPLACE on a policy attached to any column
    (003531), so the body and comment are altered instead. A signature or
    return type cannot be altered: the policy has to be detached first.
  #}

  {{ return(adapter.dispatch('update_masking_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_masking_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_masking_policy(resource_config) %}
  {% set fqn = target.database ~ '.' ~ target.schema ~ '.' ~ resource_config.name %}
  {% set current = dbt_drift.read_masking_policy(resource_config) %}

  {% if current is none %}
    {{ return(dbt_drift.create_masking_policy(resource_config)) }}
  {% endif %}

  {% set desired = dbt_drift.normalize_masking_policy(resource_config) %}
  {% if not dbt_drift.compare(current.signature, desired.signature)
        or not dbt_drift.compare(current.returns, desired.returns) %}
    {{ exceptions.raise_compiler_error(
      "masking_policy " ~ fqn ~ " changes its signature or return type ("
      ~ current.signature ~ " returns " ~ current.returns ~ " -> "
      ~ desired.signature ~ " returns " ~ desired.returns
      ~ "), which Snowflake cannot alter. Detach the policy from every column"
      ~ " (alter table ... modify column ... unset masking policy), then re-run"
      ~ " so dbt-drift recreates it."
    ) }}
  {% endif %}

  {% set safe_comment = dbt_drift.stamped_comment(resource_config) | replace("'", "''") %}

  {% if not dbt_drift.compare(current.body, desired.body) %}
    {% set body_sql %}
      alter masking policy {{ fqn }} set body ->
      {{ resource_config.body }}
    {% endset %}
    {% do run_query(body_sql) %}
  {% endif %}

  {% do run_query("alter masking policy " ~ fqn ~ " set comment = '" ~ safe_comment ~ "'") %}
  {{ log("Updated masking_policy: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}

{% endmacro %}
