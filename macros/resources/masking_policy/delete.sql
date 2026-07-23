{% macro delete_masking_policy(resource_config) %}
  {#
    Delete a masking policy from the warehouse (uses 'name').

    Note: Snowflake refuses to drop a masking policy still attached to a column.
    Detach it first if reconcile reports an error here.
  #}

  {{ return(adapter.dispatch('delete_masking_policy', 'dbt_drift')(resource_config)) }}

{% endmacro %}


{% macro default__delete_masking_policy(resource_config) %}
  {# Default implementation - adapter not supported #}
  {{ exceptions.raise_compiler_error("delete_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__delete_masking_policy(resource_config) %}
  {# Snowflake-specific implementation #}

  {% set name = resource_config.name %}

  {% set drop_sql %}
    drop masking policy if exists {{ target.schema }}.{{ name }}
  {% endset %}

  {% do run_query(drop_sql) %}
  {{ log("Deleted masking_policy: " ~ name, info=true) }}

  {{ return({'success': true, 'resource': name}) }}

{% endmacro %}
