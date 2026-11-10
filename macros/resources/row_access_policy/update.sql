{% macro update_row_access_policy(resource_config) %}
  {#
    Update an existing row access policy in place.

    Snowflake refuses CREATE OR REPLACE on a policy attached to any table or
    view (003531), so the body and comment are altered instead. A signature
    cannot be altered: the policy is recreated when
    nothing references it, and refused when something does.
  #}

  {{ return(adapter.dispatch('update_row_access_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__update_row_access_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("update_row_access_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__update_row_access_policy(resource_config) %}
  {% set fqn = target.database ~ '.' ~ target.schema ~ '.' ~ resource_config.name %}
  {% set current = dbt_drift.read_row_access_policy(resource_config) %}

  {% if current is none %}
    {{ return(dbt_drift.create_row_access_policy(resource_config)) }}
  {% endif %}

  {% set desired = dbt_drift.normalize_row_access_policy(resource_config) %}
  {% if not dbt_drift.compare(current.signature, desired.signature) %}
    {% if not dbt_drift.policy_is_attached(fqn) %}
      {{ return(dbt_drift.create_row_access_policy(resource_config)) }}
    {% endif %}
    {{ exceptions.raise_compiler_error(
      "row_access_policy " ~ fqn ~ " changes its signature ("
      ~ current.signature ~ " -> " ~ desired.signature
      ~ "), which Snowflake cannot alter. Detach the policy from every table and"
      ~ " view (alter table ... drop row access policy ...), then re-run so"
      ~ " dbt-drift can recreate it."
    ) }}
  {% endif %}

  {% set safe_comment = dbt_drift.stamped_comment(resource_config) | replace("'", "''") %}

  {% if not dbt_drift.compare(current.body, desired.body) %}
    {% set body_sql %}
      alter row access policy {{ fqn }} set body ->
      {{ resource_config.body }}
    {% endset %}
    {% do run_query(body_sql) %}
  {% endif %}

  {% do run_query("alter row access policy " ~ fqn ~ " set comment = '" ~ safe_comment ~ "'") %}
  {{ log("Updated row_access_policy: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}

{% endmacro %}
