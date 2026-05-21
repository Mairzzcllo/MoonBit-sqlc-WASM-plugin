# Runtime API Reference

The `runtime` package provides the types and functions that generated query code depends on. Add it to your `moon.pkg`:

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

---

## DBError

```moonbit
pub enum DBError {
  ConnectionError(String)
  QueryError(String)
  TypeError(String)
  NoRows
}
```

Error type for all database operations. All runtime functions return `Result[T, DBError]`.

| Variant | Meaning |
|---------|---------|
| `ConnectionError(msg)` | Connection or transport failure |
| `QueryError(msg)` | SQL execution error |
| `TypeError(msg)` | Type mismatch during decode |
| `NoRows` | No row returned for `:one` query |

---

## Value

```moonbit
pub enum Value {
  Null
  Int64(Int64)
  String(String)
}
```

Typed parameter values for SQL query binding.

| Variant | SQL Type | Usage |
|---------|----------|-------|
| `Null` | `NULL` | Omitted parameters |
| `Int64(n)` | `BIGINT`, `INT`, `SERIAL` | Integer parameters |
| `String(s)` | `TEXT`, `VARCHAR` | String parameters |

---

## DB

```moonbit
pub struct DB {
  // Driver-supplied closures (constructed via DB::new)
}
```

Main database handle. Generated query functions accept `DB` as the first parameter.

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `exec` | `(String, Array[Value]) -> Result[Int64, DBError]` | Execute SQL returning affected row count |
| `execrows` | `(String, Array[Value]) -> Result[Int64, DBError]` | Execute SQL returning affected row count (alias for `:execrows` queries) |
| `query` | `(String, Array[Value]) -> Result[RowIter, DBError]` | Execute query returning a row iterator (`:many`) |
| `query_row` | `(String, Array[Value]) -> Result[Row, DBError]` | Execute query returning a single row (`:one`) |
| `begin` | `() -> Result[Transaction, DBError]` | Begin a new transaction |

### Constructor

```moonbit
pub fn DB::new(
  exec_fn: (String, Array[Value]) -> Result[Int64, DBError],
  execrows_fn: (String, Array[Value]) -> Result[Int64, DBError],
  query_fn: (String, Array[Value]) -> Result[RowIter, DBError],
  query_row_fn: (String, Array[Value]) -> Result[Row, DBError],
  begin_fn: () -> Result[Transaction, DBError],
) -> DB
```

---

## Transaction

```moonbit
pub struct Transaction {
  // Driver-supplied closures (constructed via Transaction::new)
}
```

Transaction handle. Shares the same `exec`/`execrows`/`query`/`query_row` interface as `DB`, plus `commit` and `rollback`.

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `exec` | `(String, Array[Value]) -> Result[Int64, DBError]` | Execute within transaction |
| `execrows` | `(String, Array[Value]) -> Result[Int64, DBError]` | Execute within transaction |
| `query` | `(String, Array[Value]) -> Result[RowIter, DBError]` | Query within transaction |
| `query_row` | `(String, Array[Value]) -> Result[Row, DBError]` | Query single row within transaction |
| `commit` | `() -> Result[Unit, DBError]` | Commit the transaction |
| `rollback` | `() -> Result[Unit, DBError]` | Rollback the transaction |

### Constructor

```moonbit
pub fn Transaction::new(
  exec_fn: (...) -> Result[Int64, DBError],
  execrows_fn: (...) -> Result[Int64, DBError],
  query_fn: (...) -> Result[RowIter, DBError],
  query_row_fn: (...) -> Result[Row, DBError],
  commit_fn: () -> Result[Unit, DBError],
  rollback_fn: () -> Result[Unit, DBError],
) -> Transaction
```

---

## Row

```moonbit
pub struct Row {
  get_fn: (Int) -> String
}
```

A single row of query results. Provides indexed column access (0-based).

### Raw Access

| Method | Returns | Description |
|--------|---------|-------------|
| `get` | `String` | Raw string value at index |
| `get_array` | `Array[String]` | Array value (MVP: single-element wrapper) |

### Typed Non-nullable Getters

Each returns `Result[T, DBError]`:

| Method | Returns | Parses |
|--------|---------|--------|
| `get_int64(index)` | `Result[Int64, DBError]` | Integer string |
| `get_string(index)` | `Result[String, DBError]` | Raw string |
| `get_bool(index)` | `Result[Bool, DBError]` | "true"/"false" |
| `get_double(index)` | `Result[Double, DBError]` | Float string |
| `get_bytes(index)` | `Result[Array[Byte], DBError]` | Byte array from string |
| `get_date(index)` | `Result[Date, DBError]` | Date string wrapper |
| `get_datetime(index)` | `Result[DateTime, DBError]` | DateTime string wrapper |
| `get_json(index)` | `Result[Json, DBError]` | JSON string -> @json.parse |

### Typed Nullable Getters

Each returns `Result[Option[T], DBError]`. Empty string (`""`) is treated as `None`:

| Method | Returns |
|--------|---------|
| `get_nullable_int64(index)` | `Result[Option[Int64], DBError]` |
| `get_nullable_string(index)` | `Result[Option[String], DBError]` |
| `get_nullable_bool(index)` | `Result[Option[Bool], DBError]` |
| `get_nullable_double(index)` | `Result[Option[Double], DBError]` |
| `get_nullable_bytes(index)` | `Result[Option[Array[Byte]], DBError]` |
| `get_nullable_date(index)` | `Result[Option[Date], DBError]` |
| `get_nullable_datetime(index)` | `Result[Option[DateTime], DBError]` |
| `get_nullable_json(index)` | `Result[Option[Json], DBError]` |

---

## RowIter

```moonbit
pub struct RowIter {
  next_fn: () -> Result[Option[Row], DBError]
}
```

Streaming row iterator for `:many` query results.

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `next` | `() -> Result[Option[Row], DBError]` | Advance to next row; `Ok(None)` when exhausted |
| `collect` | `() -> Result[Array[Row], DBError]` | Collect all remaining rows into an array |

Typical generated `:many` function pattern:

```moonbit
pub fn query_users_list(db: DB) -> Result[Array[User], DBError] {
  let iter = db.query("SELECT * FROM users", [])?
  let rows = iter.collect()?
  let mut result: Array[User] = []
  for row in rows {
    result.push(User::decode(row)?)
  }
  Ok(result)
}
```

---

## Date / DateTime

```moonbit
pub struct Date { inner: String }
pub struct DateTime { inner: String }
```

Thin wrappers around SQL date/timestamp strings.

| Method | Returns | Description |
|--------|---------|-------------|
| `Date::new(value)` | `Date` | Construct from string |
| `Date::to_string()` | `String` | Return inner value |
| `DateTime::new(value)` | `DateTime` | Construct from string |
| `DateTime::to_string()` | `String` | Return inner value |

---

## MockDB

```moonbit
pub struct MockDB {
  exec_ok: Result[Int64, DBError]
  execrows_ok: Result[Int64, DBError]
  query_ok: Result[RowIter, DBError]
  query_row_ok: Result[Row, DBError]
}
```

Preset mock database for testing generated query functions.

| Method | Returns | Description |
|--------|---------|-------------|
| `MockDB::new(exec, execrows, query, query_row)` | `MockDB` | Create with preset results |
| `MockDB::build(self)` | `DB` | Convert to `DB` instance (begin always returns `Err`) |

---

## Type Mapping Reference

| PostgreSQL Column Type | MoonBit Type | Row Getter |
|------------------------|-------------|------------|
| `BIGSERIAL`, `BIGINT` | `Int64` | `get_int64` |
| `INT`, `INT4`, `SERIAL` | `Int` | `get_int64` (cast) |
| `INT2`, `SMALLINT` | `Int` | `get_int64` (cast) |
| `TEXT`, `VARCHAR`, `CHAR` | `String` | `get_string` |
| `BOOLEAN`, `BOOL` | `Bool` | `get_bool` |
| `DOUBLE`, `FLOAT8` | `Double` | `get_double` |
| `NUMERIC`, `DECIMAL` | `String` | `get_string` |
| `BYTEA` | `Array[Byte]` | `get_bytes` |
| `DATE` | `Date` | `get_date` |
| `TIMESTAMP`, `TIMESTAMPTZ` | `DateTime` | `get_datetime` |
| `JSON`, `JSONB` | `Json` | `get_json` |
| Any nullable column | `Option[T]` | `get_nullable_*` |
