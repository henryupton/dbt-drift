{% macro policy_is_attached(policy_fqn) %}
  {# True when a masking or row access policy is referenced by any object. #}
  {{ return(adapter.dispatch('policy_is_attached', 'dbt_drift')(policy_fqn)) }}
{% endmacro %}


{% macro default__policy_is_attached(policy_fqn) %}
  {{ exceptions.raise_compiler_error("policy_is_attached not implemented for adapter: " ~ target.type) }}
{% endmacro %}


{% macro snowflake__policy_is_attached(policy_fqn) %}
  {% set refs_sql %}
    select count(*) as n
    from table({{ target.database }}.information_schema.policy_references(policy_name => '{{ policy_fqn }}'))
  {% endset %}
  {% set result = run_query(refs_sql) %}
  {{ return(result.rows[0][0] > 0) }}
{% endmacro %}
