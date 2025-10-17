{% macro compare(obj1, obj2) %}
  {#
    Compare two objects for equality with normalization
    Recursively walks structure and normalizes primitives
    - Strings: case insensitive, whitespace normalized
    - Numbers/Booleans: direct comparison
    - Dicts: recursive comparison of all keys
    - Lists: recursive comparison of all items

    Returns true if they are the same, false otherwise
  #}

  {# Both none = equal #}
  {% if obj1 is none and obj2 is none %}
    {{ return(true) }}
  {% endif %}

  {# One none, one not = not equal #}
  {% if obj1 is none or obj2 is none %}
    {{ return(false) }}
  {% endif %}

  {# Check if both are dictionaries #}
  {% if obj1 is mapping and obj2 is mapping %}
    {# Check if they have the same keys #}
    {% set keys1 = obj1.keys() | list | sort %}
    {% set keys2 = obj2.keys() | list | sort %}

    {% if keys1 != keys2 %}
      {{ return(false) }}
    {% endif %}

    {# Recursively compare each key's value #}
    {% for key in keys1 %}
      {% if not dbt_drift.compare(obj1[key], obj2[key]) %}
        {{ return(false) }}
      {% endif %}
    {% endfor %}

    {{ return(true) }}
  {% endif %}

  {# Check if both are lists #}
  {% if obj1 is sequence and obj1 is not string and obj2 is sequence and obj2 is not string %}
    {% if obj1 | length != obj2 | length %}
      {{ return(false) }}
    {% endif %}

    {# Recursively compare each item #}
    {% for i in range(obj1 | length) %}
      {% if not dbt_drift.compare(obj1[i], obj2[i]) %}
        {{ return(false) }}
      {% endif %}
    {% endfor %}

    {{ return(true) }}
  {% endif %}

  {# Both are strings - normalize and compare #}
  {% if obj1 is string and obj2 is string %}
    {# Normalize: lowercase, trim, collapse whitespace, remove wrapping parentheses #}
    {% set temp1 = obj1 | lower | trim | replace('\n', ' ') | replace('\r', ' ') | replace('\t', ' ') %}
    {% set temp2 = obj2 | lower | trim | replace('\n', ' ') | replace('\r', ' ') | replace('\t', ' ') %}

    {# Collapse multiple spaces #}
    {% set normalized1 = modules.re.sub('\\s+', ' ', temp1) %}
    {% set normalized2 = modules.re.sub('\\s+', ' ', temp2) %}

    {# Strip wrapping parentheses #}
    {% set normalized1 = modules.re.sub('^\\((.*)\\)$', '\\1', normalized1) | trim %}
    {% set normalized2 = modules.re.sub('^\\((.*)\\)$', '\\1', normalized2) | trim %}

    {{ return(normalized1 == normalized2) }}
  {% endif %}

  {# Numbers and booleans - direct comparison #}
  {% if obj1 is number and obj2 is number %}
    {{ return(obj1 == obj2) }}
  {% endif %}

  {% if obj1 is boolean and obj2 is boolean %}
    {{ return(obj1 == obj2) }}
  {% endif %}

  {# Type mismatch - not equal #}
  {{ return(false) }}

{% endmacro %}
