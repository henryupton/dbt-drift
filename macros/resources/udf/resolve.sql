{% macro udf(name) %}
  {#
    Resolve a managed UDF to its fully-qualified name for use in models:

      select {{ dbt_drift.udf('calculate_discount') }}(price, pct) as net
      from {{ ref('orders') }}
  #}

  {{ return(dbt_drift.resolve_resource('udf', name)) }}

{% endmacro %}
