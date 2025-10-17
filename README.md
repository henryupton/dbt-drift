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

```bash
# In your dbt project's packages.yml
packages:
  - git: "https://github.com/your-org/dbt-drift"
    revision: main
```

### Configuration

Define resources in `dbt_project.yml`:

```yaml
vars:
  dbt_drift:
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
# Manage all resources
dbt run-operation dbt_drift.run

# Or use in on-run-start hook
on-run-start:
  - "{{ dbt_drift.run() }}"
```

## Architecture

The framework uses a **resource-oriented CRUD pattern**:

```
macros/
├── resource_management/     # Core orchestration
│   ├── run.sql             # Entrypoint
│   ├── manage_resources.sql
│   ├── compare.sql         # Recursive comparison with normalization
│   └── crud/
│       ├── create_resource.sql
│       ├── read_resource.sql
│       ├── update_resource.sql
│       └── delete_resource.sql
│
└── resources/              # Resource-specific implementations
    └── {resource_type}/
        ├── create.sql      # How to create this resource
        ├── read.sql        # How to read from warehouse
        ├── update.sql      # How to update this resource
        └── delete.sql      # How to delete this resource
```

## Adding New Resource Types

To add support for a new resource type, you need to:

1. Create a folder under `macros/resources/` matching the resource type name
2. Implement 4 CRUD operations (create, read, update, delete)
3. Define resource configuration in `vars.dbt_drift.resources`

### Example: Adding Masking Policy Support

Let's walk through adding support for Snowflake dynamic masking policies.

#### Step 1: Create Resource Folder

```bash
mkdir -p macros/resources/masking_policy
```

#### Step 2: Implement READ Operation

Create `macros/resources/masking_policy/read.sql`:

```sql
{% macro read_masking_policy(resource_name) %}
  {#
    Read the current state of a masking policy from the warehouse
    Returns: Dictionary with policy metadata or none if not found
  #}

  {{ return(adapter.dispatch('read_masking_policy', 'dbt_drift')(resource_name)) }}
{% endmacro %}

{% macro default__read_masking_policy(resource_name) %}
  {{ exceptions.raise_compiler_error("read_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}

{% macro snowflake__read_masking_policy(resource_name) %}
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
{% macro delete_masking_policy(resource_name, extra_args=none) %}
  {#
    Delete a masking policy from the warehouse
  #}

  {{ return(adapter.dispatch('delete_masking_policy', 'dbt_drift')(resource_name, extra_args)) }}
{% endmacro %}

{% macro default__delete_masking_policy(resource_name, extra_args=none) %}
  {{ exceptions.raise_compiler_error("delete_masking_policy not implemented for adapter: " ~ target.type) }}
{% endmacro %}

{% macro snowflake__delete_masking_policy(resource_name, extra_args=none) %}
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

### Coming Soon

- 🚧 **Masking Policies** - Dynamic data masking
- 🚧 **Row Access Policies** - Row-level security
- 🚧 **External Functions** - API-backed functions
- 🚧 **Stored Procedures** - Procedural logic

## License

MIT
