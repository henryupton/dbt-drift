{% macro masking_policy(name) %}
  {#
    Resolve a managed masking policy to its fully-qualified name:

      alter table {{ this }} modify column email
        set masking policy {{ dbt_drift.masking_policy('mask_email') }};
  #}

  {{ return(dbt_drift.resolve_resource('masking_policy', name)) }}

{% endmacro %}
