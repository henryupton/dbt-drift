{% macro dispatch_resource(resource_type, operation, resource_config=none, pass_config=true, required=true, fallback=none) %}
  {#
    Resolve and invoke a resource type's operation macro - `read_udf` for
    ('udf', 'read'), `create_masking_policy` for ('masking_policy', 'create'),
    and so on. Every dispatcher goes through here, so this is the only place a
    resource-type lookup happens.

    The lookup probes by indexing the package namespace. Do NOT rewrite it as
    `macro_name in dbt_drift`: on dbt-fusion the `in` test against a macro
    namespace is always false, so every dispatch would report its resource type
    as unknown and the package would not work on that engine at all.

    Args:
      resource_type:   e.g. 'udf'
      operation:       e.g. 'read' (prefixes resource_type to form the macro name)
      resource_config: the config dict to pass through
      pass_config:     false for operations taking no argument (list)
      required:        false to return `fallback` when the type doesn't implement
                       the operation, so optional operations degrade rather than fail
      fallback:        what to return when an optional operation is absent
  #}

  {% set macro_name = operation ~ '_' ~ resource_type %}

  {% if dbt_drift[macro_name] is not defined %}
    {% if required %}
      {{ exceptions.raise_compiler_error("Unknown resource type: " ~ resource_type ~ " (macro dbt_drift." ~ macro_name ~ " not found)") }}
    {% endif %}
    {{ return(fallback) }}
  {% endif %}

  {% if pass_config %}
    {{ return(dbt_drift[macro_name](resource_config)) }}
  {% else %}
    {{ return(dbt_drift[macro_name]()) }}
  {% endif %}

{% endmacro %}
