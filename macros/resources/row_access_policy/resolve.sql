{% macro row_access_policy(name) %}
  {#
    Resolve a managed row access policy to its fully-qualified name:

      alter table {{ this }} add row access policy
        {{ dbt_drift.row_access_policy('restrict_by_region') }} on (region);
  #}

  {{ return(dbt_drift.resolve_resource('row_access_policy', name)) }}

{% endmacro %}
