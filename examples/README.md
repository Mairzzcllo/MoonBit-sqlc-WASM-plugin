# Examples

## users — PostgreSQL Example

Complete sqlc integration example for MoonBit.

### Files

| File | Purpose |
|------|---------|
| `schema.sql` | Users table DDL |
| `query.sql` | SQL queries with sqlc annotations (`:one`, `:many`, `:exec`) |
| `sqlc.yaml` | sqlc v2 plugin config (references plugin.wasm from build output) |
| `moon.pkg` | Package manifest with runtime dependency |
| `lib.mbt` | Generated MoonBit code (produced by `sqlc generate`) |

### Usage

```bash
# Build the WASM plugin first
moon build --target wasm

# Generate MoonBit code from SQL
cd examples/users
sqlc generate

# Inspect the output
cat lib.mbt
```

### Query Annotations

- `:one` — Returns a single row (e.g., `GetUser`)
- `:many` — Returns multiple rows (e.g., `ListUsers`)
- `:exec` — Executes without returning rows (e.g., `DeleteUser`)
