# Quick Start Guide

> Generate type-safe MoonBit database code from SQL in 5 minutes.

## Prerequisites

- [MoonBit](https://www.moonbitlang.com/) >= 0.1.20260512
- [sqlc](https://sqlc.dev) >= v1.27.0 (tested with v1.31.1)
- PostgreSQL (for schema/query validation)

## 1. Build the WASM Plugin

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon build --target wasm
```

The plugin binary is at `_build/wasm/release/build/plugin/plugin.wasm`.

## 2. Configure Your Project

Create a `sqlc.yaml` in your MoonBit project:

```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./path/to/plugin.wasm
sql:
  - engine: postgresql
    schema: schema.sql
    queries: query.sql
    codegen:
      out: lib
      plugin: moonbit
```

## 3. Write SQL

`schema.sql`:
```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

`query.sql`:
```sql
-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: ListUsers :many
SELECT * FROM users ORDER BY created_at DESC;

-- name: CreateUser :one
INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

## 4. Generate Code

```bash
sqlc generate
```

This produces `types.mbt` (structs, enums, decode functions) and `queries.mbt` (query functions) in the output directory.

## 5. Add Runtime Dependency

In your `moon.pkg`:

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

## 6. Use Generated Code

```moonbit
fn init {
  // Create a DB connection (driver-specific)
  let db = connect_to_postgres("host=localhost dbname=myapp")

  // :one — single row
  let user = match query_users_get_by_id(db, 42) {
    Ok(u) => u
    Err(NoRows) => { println("not found"); return }
    Err(e) => { println("error: \{e}"); return }
  }
  println("Hello, \{user.name}!")

  // :many — multiple rows
  let all = match query_users_list(db) {
    Ok(rows) => rows
    Err(e) => { println("error: \{e}"); return }
  }
  println("Found \{all.length()} users")

  // :exec — no rows returned
  let _ = query_users_delete(db, 42)
}
```

## Using MockDB for Testing

```moonbit
test "query_users_get_by_id with mock" {
  let row = Row::new(fn(i) {
    if i == 0 { "1" }
    else if i == 1 { "Alice" }
    else if i == 2 { "alice@test.com" }
    else { "" }
  })
  let mock = MockDB::new(
    Ok(1L), Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(row),
  )
  let db = mock.build()
  let result = query_users_get_by_id(db, 1)
  // Assert on result...
}
```

## Transactions

```moonbit
fn transfer_funds(db: DB, from: Int64, to: Int64, amount: Int64) -> Result[Unit, DBError] {
  let tx = db.begin()?
  let _ = tx.exec("UPDATE accounts SET balance = balance - $1 WHERE id = $2", [Int64(amount), Int64(from)])?
  let _ = tx.exec("UPDATE accounts SET balance = balance + $1 WHERE id = $2", [Int64(amount), Int64(to)])?
  tx.commit()
}
```

## What's Next

- See [Runtime API Reference](runtime-api.md) for full type documentation
- See [examples/users/](../examples/users/) for a complete working example
