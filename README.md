# dbt-drift

A framework for managing warehouse resources outside of dbt's standard scope (UDFs, masking policies, row access policies, etc.) using declarative YAML configuration.

## Overview

dbt-drift allows you to manage database objects that dbt doesn't natively support, using familiar dbt patterns:
- Define resources in YAML configuration
- Detect drift between config and actual state
- Automatically create or update resources to match configuration
- Extensible architecture for adding new resource types

## Quick Start

### Installation

```yaml
# In your dbt project's packages.yml
packages:
  - git: "https://github.com/henryupton/dbt-drift.git"
    revision: 1.0.0
```

### Configuration

Define resources in `dbt_project.yml`:

```yaml
vars:
  dbt_drift:
    # Report drift between config and the warehouse (default true)
    show_drift: true
    # Apply changes so the warehouse matches config (default false)
    reconcile_drift: false

    resources:
      udf:
        calculate_discount:
          arguments: "price number, discount_pct number"
          returns: "number"
          language: "sql"
          definition: "price * (1 - discount_pct / 100)"
          comment: "Calculates discounted price"
```

### Usage

```bash
# Report drift (default: read-only, changes nothing)
dbt run-operation dbt_drift.run

# Reconcile: apply create / update / delete to match config
dbt run-operation dbt_drift.run --vars '{dbt_drift: {reconcile_drift: true}}'

# Or use in an on-run-start hook (obeys the show_drift / reconcile_drift vars)
on-run-start:
  - "{{ dbt_drift.run() }}"
```

## Drift Behaviour

Two vars under `vars.dbt_drift` control what `run` does:

| Var | Default | Effect |
| --- | --- | --- |
| `show_drift` | `true` | Log the planned actions (create / update / delete) |
| `reconcile_drift` | `false` | Apply those actions to the warehouse |

By default `run` is **read-only**: it reports drift but changes nothing. Set
`reconcile_drift: true` to apply changes.

### How resources are tracked

On create, dbt-drift stamps a managed marker (`dbt-drift:managed`) into each
resource's comment. This lets it distinguish objects it manages from objects
created elsewhere.

The marker is part of the compared state, not just something written on the way
past. So **adopting an object that already exists** — adding config for a UDF you
created by hand, matching it exactly — reports as drift on the first plan, and the
reconcile that follows rewrites it solely to stamp the marker. That is deliberate:
without it the object would report `no_change` forever, never carry the marker, and
so never be visible to orphan detection. It would be managed in name only.

### Orphan handling

During reconcile, a resource that is **managed by dbt-drift** but no longer
present in config is treated as an orphan and dropped. Objects **without** the
managed marker are never touched, so dbt-drift will not delete anything it
didn't create. (Orphan detection requires the resource type to implement a
`list_{type}` macro; without it, deletion is skipped.)

## Referencing Resources in Models

Managed resources live in `target.schema`, so referencing them by bare name
from a model in another schema won't resolve. Use the per-type resolver macros
to expand a short name to its fully-qualified `database.schema.name`:

```sql
-- Call a managed UDF
select
  {{ dbt_drift.udf('calculate_discount') }}(price, discount_pct) as net_price
from {{ ref('orders') }}
```

```sql
-- Attach a managed row access policy (e.g. in a post-hook)
alter table {{ this }} add row access policy
  {{ dbt_drift.row_access_policy('restrict_by_region') }} on (region);
```

Each resolver validates that the name is configured under
`vars.dbt_drift.resources.{type}` and raises a clear error on a typo, the way
`ref()` fails on an unknown model. Every resource type ships a matching macro
(`dbt_drift.udf`, `dbt_drift.row_access_policy`, ...).

## Architecture

The framework uses a **resource-oriented CRUD pattern**:

```
macros/
├── resource_management/       # Core orchestration
│   ├── run.sql                # Entrypoint (obeys show_drift / reconcile_drift)
│   ├── manage_resources.sql   # Plan + report + apply per resource type
│   ├── compare.sql            # Recursive comparison with normalization
│   ├── needs_update.sql       # Decide if a resource has drifted
│   ├── load_resource_configs.sql
│   ├── dispatch_resource.sql  # The one type -> macro lookup; all dispatch routes here
│   ├── list_resource.sql      # Dispatch to list_{type} (orphan detection)
│   ├── normalize_resource.sql # Dispatch to normalize_{type} (drift-noise)
│   ├── resolve_resource.sql   # Resolve a resource to its fully-qualified name
│   ├── canonicalize_types.sql # Warehouse type canonicalization helpers
│   ├── managed_marker.sql     # The dbt-drift:managed marker
│   └── crud/
│       ├── create_resource.sql
│       ├── read_resource.sql
│       ├── update_resource.sql
│       └── delete_resource.sql
│
└── resources/                 # Resource-specific implementations
    └── {resource_type}/
        ├── create.sql         # How to create this resource
        ├── read.sql           # How to read current state from the warehouse
        ├── update.sql         # How to update this resource
        ├── delete.sql         # How to delete this resource
        ├── list.sql           # (optional) list managed resources -> orphans
        ├── normalize.sql      # (optional) canonicalize config for comparison
        └── resolve.sql        # (optional) {type}(name) resolver for models
```

## Adding New Resource Types

To add support for a new resource type, you need to:

1. Create a folder under `macros/resources/` matching the resource type name
2. Implement the CRUD operations. Each is dispatched by name (`create_{type}`, etc.):
   - `read_{type}(resource_config)` - return current warehouse state (or `none`)
   - `create_{type}(resource_config)` / `update_{type}(resource_config)`
   - `delete_{type}(resource_config)`
3. Define resource configuration in `vars.dbt_drift.resources`

You don't need to touch dispatch. Every dispatcher routes through
`dispatch_resource`, the single place a resource type is resolved to a macro —
and so the single place that has to keep indexing the package namespace rather
than testing `macro_name in dbt_drift`. On dbt-fusion that `in` test is always
false, which would make every resource type report as unknown.

Two optional macros unlock the full feature set:

- `list_{type}()` - return the resources dbt-drift manages in the warehouse
  (those carrying `dbt_drift.managed_marker()`). Enables orphan detection and
  deletion. Return `none` where listing isn't supported.
- `normalize_{type}(resource_config)` - canonicalize the desired config so it
  compares equal to warehouse-read state (e.g. type widening). Optional but
  strongly recommended to avoid false-positive drift. Include `comment` here,
  set to `dbt_drift.stamped_comment(resource_config)`, so the managed marker is
  part of the compared state.
- `{type}(name)` - a resolver macro (e.g. `udf`, `row_access_policy`) that
  delegates to `dbt_drift.resolve_resource('{type}', name)` so models can
  reference the resource by short name. Recommended for any resource that gets
  referenced from SQL.

> **Note:** `read`, `create`, `update` and `delete` all receive the full
> `resource_config` dict. Stamp `dbt_drift.managed_marker()` into the object on
> create (e.g. in its comment) so dbt-drift can recognize it later.

### Example: Adding Masking Policy Support

> Masking policies are now built in (`macros/resources/masking_policy/`). This
> walkthrough is kept as a worked example of how a resource type is put
> together, and doubles as a reference for that implementation.

Let's walk through adding support for Snowflake dynamic masking policies.

#### Step 1: Create Resource Folder

```bash
mkdir -p macros/resources/masking_policy
```

#### Step 2: Implement READ Operation

Create `macros/resources/masking_policy/read.sql`:

```sql
{% macro read_masking_policy(resource_config) %}
  {#
    Read the current state of a masking policy from the warehouse
    Returns: Dictionary with policy metadata or none if not found
  #}

  {{ return(adapter.dispatch('read_masking_policy', 'dbt_drift')(resource_config)) }}
{% endmacro %}

{% macro default__read_masking_policy(resource_config) %}
  {{ exceptions.raise_compiler_error("read_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}

{% macro snowflake__read_masking_policy(resource_config) %}
  {% set resource_name = resource_config.name %}
  {% set query %}
    select
      name,
      signature,
      return_data_type,
      body
    from {{ target.database }}.information_schema.masking_policies
    where name = upper('{{ resource_name }}')
      and schema_name = upper('{{ target.schema }}')
    limit 1
  {% endset %}

  {% set result = run_query(query) %}

  {% if result and result.rows|length > 0 %}
    {% set row = result.rows[0] %}
    {% set state = {
      'name': row['NAME'] | lower,
      'signature': row['SIGNATURE'] | lower,
      'returns': row['RETURN_DATA_TYPE'] | lower,
      'body': row['BODY'] | lower
    } %}
    {{ return(state) }}
  {% else %}
    {{ return(none) }}
  {% endif %}
{% endmacro %}
```

**Key points:**
- Use `adapter.dispatch()` pattern for multi-warehouse support
- Query the warehouse's information schema or equivalent
- Return a dictionary with normalized fields (lowercase)
- Return `none` if resource doesn't exist

#### Step 3: Implement CREATE Operation

Create `macros/resources/masking_policy/create.sql`:

```sql
{% macro create_masking_policy(resource_config) %}
  {#
    Create a new masking policy in the warehouse
    Args: resource_config with keys: name, signature, returns, body, comment
  #}

  {{ return(adapter.dispatch('create_masking_policy', 'dbt_drift')(resource_config)) }}
{% endmacro %}

{% macro default__create_masking_policy(resource_config) %}
  {{ exceptions.raise_compiler_error("create_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}

{% macro snowflake__create_masking_policy(resource_config) %}
  {% set create_sql %}
    create or replace masking policy {{ target.schema }}.{{ resource_config.name }}
      as ({{ resource_config.signature }})
      returns {{ resource_config.returns }}
      ->
      {{ resource_config.body }}
      {% if resource_config.comment %}
      comment = '{{ resource_config.comment }}'
      {% endif %}
  {% endset %}

  {% do run_query(create_sql) %}
  {{ log("Created masking policy: " ~ resource_config.name, info=true) }}

  {{ return({'success': true, 'resource': resource_config.name}) }}
{% endmacro %}
```

**Key points:**
- Take `resource_config` dictionary as input
- Execute DDL to create the resource
- Use `CREATE OR REPLACE` when supported
- Log the action
- Return success indicator

#### Step 4: Implement UPDATE Operation

Create `macros/resources/masking_policy/update.sql`:

```sql
{% macro update_masking_policy(resource_config) %}
  {#
    Update an existing masking policy
    For most databases, CREATE OR REPLACE handles this
  #}

  {{ return(adapter.dispatch('update_masking_policy', 'dbt_drift')(resource_config)) }}
{% endmacro %}

{% macro default__update_masking_policy(resource_config) %}
  {{ exceptions.raise_compiler_error("update_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}

{% macro snowflake__update_masking_policy(resource_config) %}
  {# Snowflake uses CREATE OR REPLACE #}
  {{ return(create_masking_policy(resource_config)) }}
{% endmacro %}
```

**Key points:**
- Often delegates to `create_` macro if warehouse supports `CREATE OR REPLACE`
- Some resources may need explicit `DROP` then `CREATE`

#### Step 5: Implement DELETE Operation

Create `macros/resources/masking_policy/delete.sql`:

```sql
{% macro delete_masking_policy(resource_config) %}
  {#
    Delete a masking policy from the warehouse
  #}

  {{ return(adapter.dispatch('delete_masking_policy', 'dbt_drift')(resource_config)) }}
{% endmacro %}

{% macro default__delete_masking_policy(resource_config) %}
  {{ exceptions.raise_compiler_error("delete_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}

{% macro snowflake__delete_masking_policy(resource_config) %}
  {% set resource_name = resource_config.name %}
  {% set drop_sql %}
    drop masking policy if exists {{ target.schema }}.{{ resource_name }}
  {% endset %}

  {% do run_query(drop_sql) %}
  {{ log("Deleted masking policy: " ~ resource_name, info=true) }}

  {{ return({'success': true, 'resource': resource_name}) }}
{% endmacro %}
```

#### Step 6: Configure the Resource

In `dbt_project.yml`:

```yaml
vars:
  dbt_drift:
    resources:
      masking_policy:
        mask_pii:
          signature: "val string"
          returns: "string"
          body: |
            case
              when current_role() in ('ADMIN', 'COMPLIANCE')
              then val
              else '***MASKED***'
            end
          comment: "Generic PII masking policy"

        mask_email:
          signature: "email string"
          returns: "string"
          body: |
            case
              when current_role() = 'ADMIN'
              then email
              else regexp_replace(email, '^(.{2}).*(@.*)$', '\\1***\\2')
            end
          comment: "Email masking - shows first 2 chars"
```

#### Step 7: Use It

```bash
# Run drift management
dbt run-operation dbt_drift.run

# Output:
# Creating masking_policy: mask_pii
# Created masking policy: mask_pii
# Creating masking_policy: mask_email
# Created masking policy: mask_email
```

**That's it!** The framework automatically:
- Detects the new resource type from your configuration
- Calls your CRUD macros via dynamic dispatch
- Compares warehouse state to configuration
- Creates or updates resources as needed

## Supported Resources

### Snowflake

- ✅ **UDF** - User-Defined Functions (SQL, JavaScript, Python)
- ✅ **Row Access Policies** - Row-level security

```yaml
vars:
  dbt_drift:
    resources:
      row_access_policy:
        restrict_by_region:
          signature: "region string"   # columns the policy is applied to
          body: |                       # any boolean SQL expression
            case
              when current_role() = 'ADMIN' then true
              when region = current_role() then true
              else false
            end
          comment: "Row-level security by region / role"
```

- ✅ **File Formats** - Reusable load/unload formats

```yaml
vars:
  dbt_drift:
    resources:
      file_format:
        standard_csv:
          type: csv               # reserved: type, comment
          field_delimiter: "|"    # any other key is a format option
          skip_header: 1
          compression: gzip
          null_if: ["", "NULL"]   # list options render as ('', 'NULL')
          comment: "Pipe-delimited CSV"
```

> Options may be strings, numbers, booleans or lists. A list is compared in the
> bracketed form `DESCRIBE FILE FORMAT` reports (`[, NULL]`) rather than parsed
> out of it, because Snowflake reports both `()` and `('')` as `[]` — parsing
> would make a configured `[""]` drift on every run.

- ✅ **Masking Policies** - Dynamic data masking

```yaml
vars:
  dbt_drift:
    resources:
      masking_policy:
        mask_email:
          signature: "val string"   # first arg is the column being masked
          returns: "string"         # must match the first arg's type
          body: |
            case
              when current_role() = 'ADMIN' then val
              else '***masked***'
            end
          comment: "Mask email unless ADMIN"
```

- ✅ **Stored Procedures** - Procedural logic (SQL scripting, JavaScript)

```yaml
vars:
  dbt_drift:
    resources:
      stored_procedure:
        log_run:
          arguments: "run_label string"
          returns: "string"
          language: "sql"      # sql or javascript (inline-body)
          definition: |
            begin
              return 'logged: ' || run_label;
            end;
          comment: "Example logging procedure"
```

> Inline-body procedures only for now (SQL scripting, JavaScript). Handler-based
> languages (Python/Java/Scala) needing `runtime_version`/`packages`/`handler`
> aren't supported yet - same limitation as UDFs.

### Coming Soon

- 🚧 **External Functions** - API-backed functions

## License

MIT
