# Integration Tests

This sub-project tests the dbt-drift package functionality against a live warehouse.

## Setup

```bash
cd integration_tests
dbt deps
```

This project sets `reconcile_drift: true`, so `dbt_drift.run()` runs on
`on-run-start` and reconciles the configured UDFs on every invocation.

## Running Tests

```bash
# Show drift without changing anything
dbt run-operation dbt_drift.run --vars '{dbt_drift: {reconcile_drift: false}}'

# Reconcile the warehouse to match config (create/update/delete)
dbt run-operation dbt_drift.run --vars '{dbt_drift: {reconcile_drift: true}}'

# Assert every configured resource exists and matches config (raises on drift)
dbt run-operation verify_resources
```

## Test Resources

Defined in `dbt_project.yml`:
- `to_aet` - converts a UTC timestamp to Australia/Melbourne
- `to_aet_date` - converts a UTC date to Australia/Melbourne

## Cleanup

```bash
# Drop every dbt-drift-managed UDF in the target schema
dbt run-operation delete_test_resources
```
