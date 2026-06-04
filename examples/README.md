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

## Feature Examples

The plugin supports these features which can be referenced in `sqlc.yaml`:

| Feature | Config Key | Example Value |
|---------|-----------|---------------|
| Transaction support | (auto-generated) | Query fn overload accepts `tx: Transaction` |
| PostgreSQL Enum | schema DDL | `CREATE TYPE mood AS ENUM ('happy','sad')` |
| Custom type overrides | `override_<pg_type>=<MoonBit>` | `override_numeric=Decimal` |
| Column-level overrides | `override_column_<table>.<col>=<Type>` | `override_column_users.id=String` |
| Nullable overrides | `override_nullable_<pg_type>=true` | `override_nullable_int4=true` |
| JSON/DB tag annotations | `emit_json_tags`, `emit_db_tags` | `true` / `false` |
| SQL doc comments | `emit_sql_as_comment` | `true` |
| Naming initialisms | `initialisms` | `ID,URL,HTTP` |
| JSON tag case style | `json_tags_case_style` | `snake` / `camel` / `pascal` |
| MockDB testing | `runtime/mock.mbt` | `MockDB::build()` → `DB` |

### Adding New Examples

To create an additional example, copy the `users/` directory and:
1. Write a `schema.sql` with your DDL
2. Write a `query.sql` with annotated queries
3. Update `sqlc.yaml` with your options
4. Run `sqlc generate` and verify the output

The plugin supports: multi-table joins, PostgreSQL enums, arrays, transactions,
and all type override options documented in the main README.
