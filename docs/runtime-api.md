<p align="center">
  <a href="runtime-api.md"><b>English</b></a>
  ·
  <a href="runtime-api.zh.md">中文</a>
  ·
  <a href="runtime-api.ja.md">日本語</a>
</p>

# Runtime API Reference

The `runtime` package provides the types and functions that generated query code depends on.

**Documentation:** [Quick Start](quickstart.md) · [README](../README.md) · [Examples](../examples/README.md) · [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) · [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## Install from mooncakes.io

| Item | Value |
|------|-------|
| Package | `Mairzzcllo/moonbit_sqlc_plugin` |
| Version | **0.1.4** |
| Import path | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| Docs | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| Target | `wasm-gc` |

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
```

Add to `moon.pkg`:

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

Generated files already contain `import "Mairzzcllo/moonbit_sqlc_plugin/runtime"`. See [Quick Start — Path A](quickstart.md#path-a--install-runtime-from-mooncakesio) · [中文](quickstart.zh.md) · [日本語](quickstart.ja.md) for full setup.

---

## DBError

```moonbit
pub enum DBError {
  ConnectionError(String)
  QueryError(String)
  TypeError(String)
  NoRows
  ColumnNotFound(String)
  TooManyRows(Int, String)
}
```

Error type for all database operations. All runtime functions return `Result[T, DBError]`.

| Variant | Meaning |
|---------|---------|
| `ConnectionError(msg)` | Connection or transport failure |
| `QueryError(msg)` | SQL execution error |
| `TypeError(msg)` | Type mismatch during decode |
| `NoRows` | No row returned for `:one` query |
| `ColumnNotFound(name)` | Column name not found during name-based lookup |
| `TooManyRows(count, query)` | `:one` query returned multiple rows, or `collect_limited` limit exceeded |

---

## Value

```moonbit
pub enum Value {
  Null
  Int64(Int64)
  String(String)
  Bool(Bool)
  Double(Double)
  Bytes(Array[Byte])
  Date(Date)
  DateTime(DateTime)
  JsonValue(Json)
  Decimal(Decimal)
  Uuid(Uuid)
  Duration(Duration)
  Time(Time)
  TimeTZ(TimeTZ)
  IpAddr(IpAddr)
}
```

Typed parameter values for SQL query binding.

| Variant | SQL Type | Usage |
|---------|----------|-------|
| `Null` | `NULL` | Omitted parameters / NULL values |
| `Int64(n)` | `BIGINT`, `INT`, `SERIAL` | Integer parameters |
| `String(s)` | `TEXT`, `VARCHAR` | String parameters |
| `Bool(b)` | `BOOLEAN`, `BOOL` | Boolean parameters |
| `Double(d)` | `FLOAT8`, `DOUBLE` | Float parameters |
| `Bytes(b)` | `BYTEA` | Binary parameters |
| `Date(d)` | `DATE` | Date parameters |
| `DateTime(dt)` | `TIMESTAMP`, `TIMESTAMPTZ` | Timestamp parameters |
| `JsonValue(j)` | `JSON`, `JSONB` | JSON parameters |
| `Decimal(d)` | `NUMERIC`, `DECIMAL` | Exact numeric parameters |
| `Uuid(u)` | `UUID` | UUID parameters |
| `Duration(d)` | `INTERVAL` | Interval parameters (microseconds) |
| `Time(t)` | `TIME` | Time parameters (hour, min, sec, micros) |
| `TimeTZ(tz)` | `TIMETZ` | Time with timezone offset |
| `IpAddr(ip)` | `INET`, `CIDR` | Network address parameters |

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
| `copyfrom` | `(String, Array[Value]) -> Result[Int64, DBError]` | Execute a COPY FROM statement |
| `batch` | `(String, Array[Value]) -> Result[Int64, DBError]` | Execute a batch statement |
| `execlastid` | `(String, Array[Value]) -> Result[Int64, DBError]` | Execute statement returning last insert row ID |

### Constructor

```moonbit
pub fn DB::new(
  exec_fn: (String, Array[Value]) -> Result[Int64, DBError],
  execrows_fn: (String, Array[Value]) -> Result[Int64, DBError],
  query_fn: (String, Array[Value]) -> Result[RowIter, DBError],
  query_row_fn: (String, Array[Value]) -> Result[Row, DBError],
  begin_fn: () -> Result[Transaction, DBError],
  copyfrom_fn: (String, Array[Value]) -> Result[Int64, DBError],
  batch_fn: (String, Array[Value]) -> Result[Int64, DBError],
  execlastid_fn: (String, Array[Value]) -> Result[Int64, DBError],
) -> DB
```

---

## Transaction

```moonbit
pub struct Transaction {
  // Driver-supplied closures (constructed via Transaction::new)
}
```

Transaction handle. Shares the same `exec`/`execrows`/`query`/`query_row` interface as `DB`, plus `commit` and `rollback`. Note: `copyfrom`, `batch`, and `execlastid` are **not** available on `Transaction` — generated code only produces `db: DB` variants for those commands (per `supports_transaction()` logic).

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
  get_fn : (Int) -> String
  null_mask : Array[Bool]
  col_names : Array[String]
  num_cols : Int
}
```

A single row of query results. Provides indexed column access (0-based) with bounds checking and name-based lookup.

### Constructors

| Constructor | Description |
|-------------|-------------|
| `Row::new(get_fn, null_mask)` | Basic constructor (col_names empty, num_cols from null_mask) |
| `Row::new_with_names(get_fn, null_mask, col_names)` | Constructor with column names for name-based lookup |

### Raw Access & Metadata

| Method | Returns | Description |
|--------|---------|-------------|
| `get(index)` | `String` | Raw string value at index |
| `is_null(index)` | `Bool` | Check if column at index is NULL |
| `column_count()` | `Int` | Number of columns in this row |
| `check_bounds(index)` | `Result[Int, DBError]` | Validate index within bounds; OOB → `Err(TypeError(...))` |
| `index_of(name)` | `Result[Int, DBError]` | Find column index by name (O(n) scan); not found → `Err(ColumnNotFound(...))` |

### Typed Non-nullable Getters

Each returns `Result[T, DBError]`. All getters internally call `check_bounds(index)` first:

| Method | Returns | Parses |
|--------|---------|--------|
| `get_int64(index)` | `Result[Int64, DBError]` | Integer string |
| `get_string(index)` | `Result[String, DBError]` | Raw string |
| `get_bool(index)` | `Result[Bool, DBError]` | "true"/"false" |
| `get_double(index)` | `Result[Double, DBError]` | Float string |
| `get_bytes(index)` | `Result[Array[Byte], DBError]` | Byte array from string (non-ASCII safe) |
| `get_date(index)` | `Result[Date, DBError]` | Date string wrapper |
| `get_datetime(index)` | `Result[DateTime, DBError]` | DateTime string wrapper |
| `get_json(index)` | `Result[Json, DBError]` | JSON string → `@json.parse` |
| `get_decimal(index)` | `Result[Decimal, DBError]` | Numeric string wrapper |
| `get_uuid(index)` | `Result[Uuid, DBError]` | UUID string wrapper |
| `get_duration(index)` | `Result[Duration, DBError]` | Interval as microseconds |
| `get_time(index)` | `Result[Time, DBError]` | Time with variable-precision fractional seconds (0–6 digits) |
| `get_timetz(index)` | `Result[TimeTZ, DBError]` | Time with timezone offset |
| `get_ipaddr(index)` | `Result[IpAddr, DBError]` | INET/CIDR string wrapper |

### Typed Nullable Getters

Each returns `Result[Option[T], DBError]`. The `null_mask` determines NULL-ness, not empty string:

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
| `get_nullable_decimal(index)` | `Result[Option[Decimal], DBError]` |
| `get_nullable_uuid(index)` | `Result[Option[Uuid], DBError]` |
| `get_nullable_duration(index)` | `Result[Option[Duration], DBError]` |
| `get_nullable_time(index)` | `Result[Option[Time], DBError]` |
| `get_nullable_timetz(index)` | `Result[Option[TimeTZ], DBError]` |
| `get_nullable_ipaddr(index)` | `Result[Option[IpAddr], DBError]` |

### Array Decoders

For PostgreSQL array columns (e.g., `TEXT[]`, `INT[]`), decode from JSON array representation:

| Method | Returns |
|--------|---------|
| `decode_array_string(index)` | `Result[Array[String], DBError]` |
| `decode_array_int64(index)` | `Result[Array[Int64], DBError]` |
| `decode_array_bool(index)` | `Result[Array[Bool], DBError]` |
| `decode_array_double(index)` | `Result[Array[Double], DBError]` |
| `decode_array_date(index)` | `Result[Array[Date], DBError]` |
| `decode_array_datetime(index)` | `Result[Array[DateTime], DBError]` |
| `decode_array_decimal(index)` | `Result[Array[Decimal], DBError]` |
| `decode_array_bytes(index)` | `Result[Array[Array[Byte]], DBError]` |

### Nullable Array Decoders

Each returns `Result[Option[Array[T]], DBError]` — `None` if the column is NULL:

| Method | Returns |
|--------|---------|
| `decode_nullable_array_string(index)` | `Result[Option[Array[String]], DBError]` |
| `decode_nullable_array_int64(index)` | `Result[Option[Array[Int64]], DBError]` |
| `decode_nullable_array_bool(index)` | `Result[Option[Array[Bool]], DBError]` |
| `decode_nullable_array_double(index)` | `Result[Option[Array[Double]], DBError]` |
| `decode_nullable_array_date(index)` | `Result[Option[Array[Date]], DBError]` |
| `decode_nullable_array_datetime(index)` | `Result[Option[Array[DateTime]], DBError]` |
| `decode_nullable_array_decimal(index)` | `Result[Option[Array[Decimal]], DBError]` |
| `decode_nullable_array_bytes(index)` | `Result[Option[Array[Array[Byte]]], DBError]` |

---

## RowIter

```moonbit
pub struct RowIter {
  next_fn : () -> Result[Option[Row], DBError]
}
```

Streaming row iterator for `:many` query results.

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `next` | `() -> Result[Option[Row], DBError]` | Advance to next row; `Ok(None)` when exhausted |
| `collect` | `() -> Result[Array[Row], DBError]` | Collect all rows (max 10,000; delegates to `collect_limited`) |
| `collect_limited` | `(Int) -> Result[Array[Row], DBError]` | Collect up to `max_rows` rows; exceeds → `Err(TooManyRows(count, query))` |

Typical generated `:many` function pattern:

```moonbit
pub fn query_users_list(db: DB) -> Result[Array[Users], DBError] {
  let iter = db.query("SELECT * FROM users", [])?
  let rows = iter.collect()?
  let mut result: Array[Users] = []
  for row in rows {
    result.push(Users::decode(row)?)
  }
  Ok(result)
}
```

---

## Value Wrappers

### Date / DateTime

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

### Decimal / Uuid / IpAddr

```moonbit
pub struct Decimal { inner: String }
pub struct Uuid { inner: String }
pub struct IpAddr { inner: String }
```

String wrappers preserving full precision/formatting.

| Struct | Constructor | Accessor |
|--------|-------------|----------|
| `Decimal` | `Decimal::new(value: String)` | `.to_string()` |
| `Uuid` | `Uuid::new(value: String)` | `.to_string()` |
| `IpAddr` | `IpAddr::new(value: String)` | `.to_string()` |

### Duration

```moonbit
pub struct Duration { microseconds: Int64 }
```

SQL INTERVAL represented as total microseconds.

| Method | Returns | Description |
|--------|---------|-------------|
| `Duration::new(microseconds)` | `Duration` | Construct from Int64 |
| `Duration::to_int64()` | `Int64` | Return microseconds |

### Time

```moonbit
pub struct Time { hour: Int, min: Int, sec: Int, micros: Int }
```

SQL TIME value decomposed into components. Variable-precision fractional seconds (0–6 digits) are normalized by `Row::get_time`.

| Method | Returns | Description |
|--------|---------|-------------|
| `Time::new(hour, min, sec, micros)` | `Time` | Construct from components |

### TimeTZ

```moonbit
pub struct TimeTZ { hour: Int, min: Int, sec: Int, micros: Int, tz_offset: Int }
```

SQL TIMETZ value — time with timezone offset in seconds (e.g., +8h = `28800`, -5h = `-18000`).

| Method | Returns | Description |
|--------|---------|-------------|
| `TimeTZ::new(hour, min, sec, micros, tz_offset)` | `TimeTZ` | Construct from components |

### ExecResult

```moonbit
pub struct ExecResult { last_insert_id: Int64, rows_affected: Int64 }
```

Dual-value result for `:execresult` queries (resolves GAP-2).

| Method | Returns | Description |
|--------|---------|-------------|
| `ExecResult::new(last_insert_id, rows_affected)` | `ExecResult` | Construct |

---

## MockDB

```moonbit
pub struct MockDB {
  exec_ok: Result[Int64, DBError]
  execrows_ok: Result[Int64, DBError]
  query_ok: Result[RowIter, DBError]
  query_row_ok: Result[Row, DBError]
  copyfrom_ok: Result[Int64, DBError]
  batch_ok: Result[Int64, DBError]
  execlastid_ok: Result[Int64, DBError]
  tx_fn: Option[() -> Result[Transaction, DBError]]
}
```

Preset mock database for testing generated query functions.

### Constructors & Builders

| Method | Returns | Description |
|--------|---------|-------------|
| `MockDB::new(...)` | `MockDB` | Full constructor with all 8 preset results |
| `MockDB::default_ok()` | `MockDB` | Quick constructor: all ops → `Ok(0L)` / empty results; `begin` → `Err` |
| `MockDB::build(self)` | `DB` | Convert to `DB` instance |

### MockDBBuilder (P1-042)

Fluent builder API with per-SQL exact matching, duplicate detection, and configurable transaction factory:

```moonbit
pub struct MockDBBuilder { ... }
```

| Method | Returns | Description |
|--------|---------|-------------|
| `MockDBBuilder::new()` | `MockDBBuilder` | Create builder with all-Ok defaults |
| `.register_exec(sql, result)` | `MockDBBuilder` | Register exec result for exact SQL match |
| `.register_execrows(sql, result)` | `MockDBBuilder` | Register execrows result |
| `.register_query(sql, result)` | `MockDBBuilder` | Register query result |
| `.register_query_row(sql, result)` | `MockDBBuilder` | Register query_row result |
| `.register_copyfrom(sql, result)` | `MockDBBuilder` | Register copyfrom result |
| `.register_batch(sql, result)` | `MockDBBuilder` | Register batch result |
| `.register_execlastid(sql, result)` | `MockDBBuilder` | Register execlastid result |
| `.with_tx(f)` | `MockDBBuilder` | Set transaction factory |
| `.strict(enabled)` | `MockDBBuilder` | When `true`, unregistered SQL returns `Err` instead of default `Ok` |
| `.build()` | `DB` | Build DB with registered patterns |

Unmatched SQL falls through to per-operation defaults (`Ok(0L)` / empty results) unless **strict mode** is enabled via `.strict(true)`, in which case unregistered SQL returns `Err(QueryError(...))`. Duplicate SQL registrations abort.

Example:

```moonbit
let db = MockDBBuilder::new()
  .strict(true)
  .register_query_row("SELECT * FROM users WHERE id = $1", Ok(row))
  .build()
```

---

## Type Mapping Reference

| PostgreSQL Column Type | MoonBit Type | Row Getter |
|------------------------|-------------|------------|
| `BIGSERIAL`, `BIGINT`, `INT8` | `Int64` | `get_int64` |
| `INT`, `INT4`, `SERIAL` | `Int` | `get_int64` (cast) |
| `INT2`, `SMALLINT` | `Int` | `get_int64` (cast) |
| `TEXT`, `VARCHAR`, `CHAR` | `String` | `get_string` |
| `BOOLEAN`, `BOOL` | `Bool` | `get_bool` |
| `DOUBLE`, `FLOAT8` | `Double` | `get_double` |
| `FLOAT4`, `REAL` | `Double` | `get_double` |
| `NUMERIC`, `DECIMAL` | `Decimal` | `get_decimal` |
| `UUID` | `Uuid` | `get_uuid` |
| `INTERVAL` | `Duration` | `get_duration` |
| `TIME` | `Time` | `get_time` |
| `TIMETZ` | `TimeTZ` | `get_timetz` |
| `DATE` | `Date` | `get_date` |
| `TIMESTAMP`, `TIMESTAMPTZ` | `DateTime` | `get_datetime` |
| `JSON`, `JSONB` | `Json` | `get_json` |
| `BYTEA` | `Array[Byte]` | `get_bytes` |
| `INET`, `CIDR` | `IpAddr` | `get_ipaddr` |
| Array types (e.g., `TEXT[]`) | `Array[T]` | `decode_array_*` |
| Any nullable column | `Option[T]` | `get_nullable_*` |

> **Plugin codegen:** unknown PostgreSQL types fail at `sqlc generate` time unless overridden via `override_<pgtype>=<MoonBitType>`. The runtime getters above apply to columns the plugin successfully mapped.

---

## Related Documentation

| Resource | Link |
|----------|------|
| Quick Start | [quickstart.md](quickstart.md) · [中文](quickstart.zh.md) · [日本語](quickstart.ja.md) |
| Examples | [examples/README.md](../examples/README.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |
