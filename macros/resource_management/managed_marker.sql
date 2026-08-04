{% macro managed_marker() %}
  {#
    Marker embedded in a resource's comment/metadata so dbt-drift can tell
    which warehouse objects it manages. Orphan detection only ever drops
    resources carrying this marker, so objects created outside dbt-drift are
    left untouched.
  #}
  {{ return('dbt-drift:managed') }}
{% endmacro %}


{% macro stamped_comment(resource_config) %}
  {#
    The comment dbt-drift writes onto a managed object: the user's comment (when
    set) followed by the managed marker.

    Both sides of drift detection go through here - the create macros write it,
    and the normalize macros compare against it - so an object whose comment is
    missing the marker reads as drift and gets stamped on the next reconcile.
    Without that, an object adopted into config (already existing, matching in
    every other respect) would report no_change forever and never become
    visible to orphan detection.
  #}

  {% set marker = dbt_drift.managed_marker() %}
  {% set user_comment = resource_config.get('comment') if resource_config is mapping else none %}

  {{ return((user_comment ~ ' | ' ~ marker) if user_comment else marker) }}

{% endmacro %}
