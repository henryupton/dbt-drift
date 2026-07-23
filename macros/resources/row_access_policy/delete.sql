{% macro delete_row_access_policy(resource_config) %}
  {#
    Delete a row access policy from the warehouse.

    Args:
      resource_config: Dict identifying the policy to drop (uses 'name').

    Note: Snowflake refuses to drop a row access policy that is still attached
    to a table or view. Detach it first if reconcile reports an error here.
  #}

  {{ return(adapter.dispatch('delete_row_access_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__delete_row_access_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("delete_row_access_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__delete_row_access_policy(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set name = resource_config.name %}

  {% set drop_sql %}
    drop row access policy if exists {{ target.schema }}.{{ name }}
  {% endset %}

  {% do run_query(drop_sql) %}
  {{ log("Deleted row_access_policy: " ~ name, info=true) }}

  {{ return({'success': true, 'resource': name}) }}

{% endmacro %}
