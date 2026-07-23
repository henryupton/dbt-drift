{% macro file_format(name) %}
  {#
    Resolve a managed file format to its fully-qualified name, e.g.:

      copy into {{ this }}
      from @my_stage
      file_format = (format_name = '{{ dbt_drift.file_format('standard_csv') }}');
  #}

  {{ return(dbt_drift.resolve_resource('file_format', name)) }}

{% endmacro %}
