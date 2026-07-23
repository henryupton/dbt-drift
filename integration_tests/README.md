# Integration Tests

This sub-project tests the dbt-drift package against a live warehouse. It
configures one resource of every supported type (UDF, row access policy,
masking policy, file format, stored procedure).

## Setup

```bash
cd integration_tests
dbt deps
```

You need a `profiles.yml` with a profile named `integration_tests` pointing at a
Snowflake account and a schema you're happy to have objects created in and
dropped from. Nothing here touches your production objects: dbt-drift only ever
deletes objects carrying its own managed marker.

## Smoke test

The one-shot end-to-end check. It creates every configured resource, verifies
each matches, asserts a clean re-plan reports zero drift, proves orphan
deletion drops a managed object removed from config (and only that one), then
cleans up. It raises on the first failure.

```bash
dbt run-operation smoke_test
```

This is the fastest way to shake out warehouse-specific assumptions (e.g. the
`SHOW`/`DESCRIBE` column casing). If it fails partway, clean up with:

```bash
dbt run-operation delete_test_resources
```

## Individual operations

```bash
# Show drift without changing anything
dbt run-operation dbt_drift.run --vars '{dbt_drift: {reconcile_drift: false}}'

# Reconcile the warehouse to match config (create / update / delete)
dbt run-operation dbt_drift.run --vars '{dbt_drift: {reconcile_drift: true}}'

# Assert every configured resource exists and matches config (raises on drift)
dbt run-operation verify_resources

# Drop every dbt-drift-managed resource in the target schema
dbt run-operation delete_test_resources
```
