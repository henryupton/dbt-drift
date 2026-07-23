{% macro canonicalize_types(type_string) %}
  {#
    Canonicalize a warehouse type string (a bare type, a return type, or a
    full argument signature) so config values and warehouse-read values compare
    equal despite the warehouse widening/normalizing types.

    e.g. Snowflake reports `NUMBER(38,0)`, `VARCHAR(16777216)`, `TIMESTAMP_TZ(9)`
    where config declares `number`, `varchar`, `timestamp_tz`.

    Adapter-dispatched: the default is a no-op so unsupported adapters simply
    compare raw strings.
  #}
  {{ return(adapter.dispatch('canonicalize_types', 'dbt_drift')(type_string)) }}
{% endmacro %}


{% macro default__canonicalize_types(type_string) %}
  {% if type_string is string %}
    {{ return(type_string | lower) }}
  {% endif %}
  {{ return(type_string) }}
{% endmacro %}


{% macro snowflake__canonicalize_types(type_string) %}
  {% if type_string is not string %}
    {{ return(type_string) }}
  {% endif %}

  {% set s = type_string | lower %}

  {# Strip Snowflake's default precisions #}
  {% set s = modules.re.sub('number\\(\\s*38\\s*,\\s*0\\s*\\)', 'number', s) %}
  {% set s = modules.re.sub('(?:varchar|char|character|string|text)\\(\\s*16777216\\s*\\)', 'varchar', s) %}
  {% set s = modules.re.sub('(timestamp_tz|timestamp_ntz|timestamp_ltz|timestamp|datetime|time)\\(\\s*9\\s*\\)', '\\1', s) %}

  {# Map aliases to their canonical base type (longest alternatives first) #}
  {% set s = modules.re.sub('\\b(integer|int|bigint|smallint|tinyint|byteint|decimal|numeric)\\b', 'number', s) %}
  {% set s = modules.re.sub('\\b(nvarchar2|nvarchar|nchar|character varying|char varying|character|string|text)\\b', 'varchar', s) %}
  {% set s = modules.re.sub('\\b(double precision|float8|float4|double|real)\\b', 'float', s) %}
  {% set s = modules.re.sub('\\bbool\\b', 'boolean', s) %}

  {{ return(s) }}
{% endmacro %}


{% macro arg_types_from_signature(signature) %}
  {#
    Extract a types-only argument signature (no argument names) from a full
    Snowflake ARGUMENT_SIGNATURE such as `(PRICE NUMBER(38,0), DISCOUNT_PCT NUMBER(38,0))`.
    Returns `number(38,0), number(38,0)` - the form DROP FUNCTION expects.

    Splits on top-level commas only (so parametrized types like NUMBER(10,2)
    survive) and drops the leading argument name from each part.
  #}
  {% if signature is none %}
    {{ return('') }}
  {% endif %}

  {% set s = signature | trim %}
  {% if s.startswith('(') and s.endswith(')') %}
    {% set s = s[1:-1] %}
  {% endif %}
  {% set s = s | trim %}
  {% if s == '' %}
    {{ return('') }}
  {% endif %}

  {# Paren-aware split on top-level commas #}
  {% set parts = [] %}
  {% set depth = namespace(d=0) %}
  {% set cur = namespace(t='') %}
  {% for ch in s %}
    {% if ch == '(' %}
      {% set depth.d = depth.d + 1 %}
      {% set cur.t = cur.t ~ ch %}
    {% elif ch == ')' %}
      {% set depth.d = depth.d - 1 %}
      {% set cur.t = cur.t ~ ch %}
    {% elif ch == ',' and depth.d == 0 %}
      {% do parts.append(cur.t) %}
      {% set cur.t = '' %}
    {% else %}
      {% set cur.t = cur.t ~ ch %}
    {% endif %}
  {% endfor %}
  {% do parts.append(cur.t) %}

  {# Drop the argument name (first whitespace-delimited token) from each part.
     The remainder is the type, which may itself be multi-word (e.g.
     "double precision") so we rejoin everything after the name. #}
  {% set types = [] %}
  {% for p in parts %}
    {% set toks = p.split() %}
    {% if toks | length >= 2 %}
      {% do types.append(toks[1:] | join(' ')) %}
    {% elif toks | length == 1 %}
      {% do types.append(toks[0]) %}
    {% endif %}
  {% endfor %}

  {{ return(types | join(', ')) }}
{% endmacro %}
