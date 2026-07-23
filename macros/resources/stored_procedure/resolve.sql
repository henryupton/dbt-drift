{% macro stored_procedure(name) %}
  {#
    Resolve a managed stored procedure to its fully-qualified name:

      call {{ dbt_drift.stored_procedure('log_run') }}('nightly');
  #}

  {{ return(dbt_drift.resolve_resource('stored_procedure', name)) }}

{% endmacro %}
