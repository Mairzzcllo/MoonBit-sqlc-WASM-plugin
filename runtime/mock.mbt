///|
/// MockDB is the project's interface-abstraction alternative to `emit_interface`.
/// MoonBit 0.1 does not support trait objects or generic trait methods, so we
/// cannot generate a `Querier` trait like sqlc-gen-go. Instead, MockDB uses the
/// concrete struct + closure pattern (ADR-010) to provide equivalent test
/// isolation: build a `DB` with preset results and pass it to generated query
/// functions. See ADR-015 for the design rationale and future recovery path.
///
/// MockDB for testing generated query functions without a real database.
/// Stores preset results for all query modes: :one, :many, :exec, :execrows,
/// plus copyfrom/batch/execlastid and optional transaction support.
//
// Copyright 2026 Mairzzcllo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/// Preset results for a mock database.
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

pub fn MockDB::new(
  exec_ok: Result[Int64, DBError],
  execrows_ok: Result[Int64, DBError],
  query_ok: Result[RowIter, DBError],
  query_row_ok: Result[Row, DBError],
  copyfrom_ok: Result[Int64, DBError],
  batch_ok: Result[Int64, DBError],
  execlastid_ok: Result[Int64, DBError],
  tx_fn: Option[() -> Result[Transaction, DBError]],
) -> MockDB {
  {
    exec_ok: exec_ok,
    execrows_ok: execrows_ok,
    query_ok: query_ok,
    query_row_ok: query_row_ok,
    copyfrom_ok: copyfrom_ok,
    batch_ok: batch_ok,
    execlastid_ok: execlastid_ok,
    tx_fn: tx_fn,
  }
}

/// Build a DB instance from MockDB preset results.
/// The returned closures return the preset values for each operation.
/// If tx_fn is Some(f), begin uses f; otherwise begin returns Err.
pub fn MockDB::build(self: MockDB) -> DB {
  let begin_fn = match self.tx_fn {
    Some(f) => f
    None => fn() { Err(QueryError("transactions not supported")) }
  }
  DB::new(
    fn(_sql, _params) { self.exec_ok },
    fn(_sql, _params) { self.execrows_ok },
    fn(_sql, _params) { self.query_ok },
    fn(_sql, _params) { self.query_row_ok },
    begin_fn,
    fn(_sql, _params) { self.copyfrom_ok },
    fn(_sql, _params) { self.batch_ok },
    fn(_sql, _params) { self.execlastid_ok },
  )
}

/// Create a MockDB with all operations returning Ok defaults.
/// exec/execrows/copyfrom/batch/execlastid → Ok(0L)
/// query → Ok(empty RowIter)
/// query_row → Ok(empty Row with 0 columns)
/// tx_fn → None (begin returns Err)
pub fn MockDB::default_ok() -> MockDB {
  MockDB::new(
    Ok(0L),
    Ok(0L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(0, false))),
    Ok(0L),
    Ok(0L),
    Ok(0L),
    None,
  )
}

/// A single SQL-to-result mapping for an Int64-returning operation.
/// Used with MockDBBuilder for exec/execrows/copyfrom/batch/execlastid.
struct IntPattern {
  sql : String
  result : Result[Int64, DBError]
}

/// A single SQL-to-result mapping for a query operation.
/// Used with MockDBBuilder for query registrations.
struct IterPattern {
  sql : String
  result : Result[RowIter, DBError]
}

/// A single SQL-to-result mapping for a query_row operation.
/// Used with MockDBBuilder for query_row registrations.
struct RowPattern {
  sql : String
  result : Result[Row, DBError]
}

/// Builder for constructing a DB with per-SQL result mappings.
/// Supports exact SQL matching with duplicate detection (errors via `MockDBBuilder::errors`).
/// Unmatched SQL falls through to per-operation defaults (all Ok).
pub struct MockDBBuilder {
  exec_patterns : Array[IntPattern]
  execrows_patterns : Array[IntPattern]
  query_patterns : Array[IterPattern]
  query_row_patterns : Array[RowPattern]
  copyfrom_patterns : Array[IntPattern]
  batch_patterns : Array[IntPattern]
  execlastid_patterns : Array[IntPattern]
  tx_fn : Option[() -> Result[Transaction, DBError]]
  errors : Array[String]
}

/// Create a new MockDBBuilder with default Ok results for all operations.
/// Unmatched SQL returns sensible Ok defaults (0L / empty results).
pub fn MockDBBuilder::new() -> MockDBBuilder {
  {
    exec_patterns: [],
    execrows_patterns: [],
    query_patterns: [],
    query_row_patterns: [],
    copyfrom_patterns: [],
    batch_patterns: [],
    execlastid_patterns: [],
    tx_fn: None,
    errors: [],
  }
}

/// Return accumulated builder configuration errors (e.g. duplicate SQL registration).
pub fn MockDBBuilder::errors(self: MockDBBuilder) -> Array[String] {
  self.errors
}

/// Build a DB instance from the builder's registered patterns.
/// Each closure iterates over registered patterns and returns the first exact SQL match.
/// If no pattern matches, returns the default Ok value for that operation.
/// If tx_fn is set, begin uses it; otherwise begin returns Err.
pub fn MockDBBuilder::build(self: MockDBBuilder) -> DB {
  let begin_fn = match self.tx_fn {
    Some(f) => f
    None => fn() { Err(QueryError("transactions not supported")) }
  }
  DB::new(
    fn(sql, _params) {
      for pattern in self.exec_patterns {
        if pattern.sql == sql { return pattern.result }
      }
      Ok(0L)
    },
    fn(sql, _params) {
      for pattern in self.execrows_patterns {
        if pattern.sql == sql { return pattern.result }
      }
      Ok(0L)
    },
    fn(sql, _params) {
      for pattern in self.query_patterns {
        if pattern.sql == sql { return pattern.result }
      }
      Ok(RowIter::new(fn() { Ok(None) }))
    },
    fn(sql, _params) {
      for pattern in self.query_row_patterns {
        if pattern.sql == sql { return pattern.result }
      }
      Ok(Row::new(fn(_i) { "" }, Array::make(0, false)))
    },
    begin_fn,
    fn(sql, _params) {
      for pattern in self.copyfrom_patterns {
        if pattern.sql == sql { return pattern.result }
      }
      Ok(0L)
    },
    fn(sql, _params) {
      for pattern in self.batch_patterns {
        if pattern.sql == sql { return pattern.result }
      }
      Ok(0L)
    },
    fn(sql, _params) {
      for pattern in self.execlastid_patterns {
        if pattern.sql == sql { return pattern.result }
      }
      Ok(0L)
    },
  )
}

// --- Duplicate checks (abort on duplicate SQL per operation type) ---

fn append_dup_error(errors: Array[String], kind: String, sql: String) -> Array[String] {
  errors + ["duplicate SQL registration for " + kind + " operation: '" + sql + "'"]
}

fn check_dup_int(patterns: Array[IntPattern], sql: String) -> Bool {
  for pattern in patterns {
    if pattern.sql == sql {
      return false
    }
  }
  true
}

fn check_dup_iter(patterns: Array[IterPattern], sql: String) -> Bool {
  for pattern in patterns {
    if pattern.sql == sql {
      return false
    }
  }
  true
}

fn check_dup_row(patterns: Array[RowPattern], sql: String) -> Bool {
  for pattern in patterns {
    if pattern.sql == sql {
      return false
    }
  }
  true
}

// --- Registration methods (each checks for duplicates before appending) ---

/// Register an exec result for the given SQL pattern.
/// Duplicate SQL records an error retrievable via `MockDBBuilder::errors`.
pub fn MockDBBuilder::register_exec(self: MockDBBuilder, sql: String, result: Result[Int64, DBError]) -> MockDBBuilder {
  if !check_dup_int(self.exec_patterns, sql) {
    return { ..self, errors: append_dup_error(self.errors, "exec", sql) }
  }
  let new_patterns = self.exec_patterns
  new_patterns.push({ sql: sql, result: result })
  { ..self, exec_patterns: new_patterns }
}

/// Register an execrows result for the given SQL pattern.
pub fn MockDBBuilder::register_execrows(self: MockDBBuilder, sql: String, result: Result[Int64, DBError]) -> MockDBBuilder {
  if !check_dup_int(self.execrows_patterns, sql) {
    return { ..self, errors: append_dup_error(self.errors, "execrows", sql) }
  }
  let new_patterns = self.execrows_patterns
  new_patterns.push({ sql: sql, result: result })
  { ..self, execrows_patterns: new_patterns }
}

/// Register a query result for the given SQL pattern.
pub fn MockDBBuilder::register_query(self: MockDBBuilder, sql: String, result: Result[RowIter, DBError]) -> MockDBBuilder {
  if !check_dup_iter(self.query_patterns, sql) {
    return { ..self, errors: append_dup_error(self.errors, "query", sql) }
  }
  let new_patterns = self.query_patterns
  new_patterns.push({ sql: sql, result: result })
  { ..self, query_patterns: new_patterns }
}

/// Register a query_row result for the given SQL pattern.
pub fn MockDBBuilder::register_query_row(self: MockDBBuilder, sql: String, result: Result[Row, DBError]) -> MockDBBuilder {
  if !check_dup_row(self.query_row_patterns, sql) {
    return { ..self, errors: append_dup_error(self.errors, "query_row", sql) }
  }
  let new_patterns = self.query_row_patterns
  new_patterns.push({ sql: sql, result: result })
  { ..self, query_row_patterns: new_patterns }
}

/// Register a copyfrom result for the given SQL pattern.
pub fn MockDBBuilder::register_copyfrom(self: MockDBBuilder, sql: String, result: Result[Int64, DBError]) -> MockDBBuilder {
  if !check_dup_int(self.copyfrom_patterns, sql) {
    return { ..self, errors: append_dup_error(self.errors, "copyfrom", sql) }
  }
  let new_patterns = self.copyfrom_patterns
  new_patterns.push({ sql: sql, result: result })
  { ..self, copyfrom_patterns: new_patterns }
}

/// Register a batch result for the given SQL pattern.
pub fn MockDBBuilder::register_batch(self: MockDBBuilder, sql: String, result: Result[Int64, DBError]) -> MockDBBuilder {
  if !check_dup_int(self.batch_patterns, sql) {
    return { ..self, errors: append_dup_error(self.errors, "batch", sql) }
  }
  let new_patterns = self.batch_patterns
  new_patterns.push({ sql: sql, result: result })
  { ..self, batch_patterns: new_patterns }
}

/// Register an execlastid result for the given SQL pattern.
pub fn MockDBBuilder::register_execlastid(self: MockDBBuilder, sql: String, result: Result[Int64, DBError]) -> MockDBBuilder {
  if !check_dup_int(self.execlastid_patterns, sql) {
    return { ..self, errors: append_dup_error(self.errors, "execlastid", sql) }
  }
  let new_patterns = self.execlastid_patterns
  new_patterns.push({ sql: sql, result: result })
  { ..self, execlastid_patterns: new_patterns }
}

/// Set the transaction factory function for this builder.
/// The provided closure is used as the DB begin function.
pub fn MockDBBuilder::with_tx(self: MockDBBuilder, f: () -> Result[Transaction, DBError]) -> MockDBBuilder {
  { ..self, tx_fn: Some(f) }
}

// === Integration-style tests for all four query modes ===

test "mock: :many — query returns row iter with results" {
  let alice = Row::new(fn(i) { if i == 0 { "1" } else if i == 1 { "Alice" } else { "" } }, Array::make(3, false))
  let bob = Row::new(fn(i) { if i == 0 { "2" } else if i == 1 { "Bob" } else { "" } }, Array::make(3, false))
  let mut idx = 0
  let rows = [alice, bob]
  let iter = RowIter::new(fn() {
    if idx < 2 {
      let row = rows[idx]
      idx = idx + 1
      Ok(Some(row))
    } else {
      Ok(None)
    }
  })
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(iter),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.query("SELECT id, name FROM users", [])
  let rows_result = match result {
    Ok(iter2) => { (iter2).collect() }
    Err(_) => { inspect("fail", content="fail"); return }
  }
  let rows_got = match rows_result {
    Ok(r) => r
    Err(_) => { inspect("fail", content="fail"); return }
  }
  inspect(rows_got.length(), content="2")
  let name0 = (rows_got[0]).get(1)
  inspect(name0, content="Alice")
  let name1 = (rows_got[1]).get(1)
  inspect(name1, content="Bob")
}

test "mock: :one — query_row returns single row" {
  let row = Row::new(fn(i) { if i == 0 { "42" } else if i == 1 { "Alice" } else { "" } }, Array::make(3, false))
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(row),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.query_row("SELECT id, name FROM users WHERE id = $1", [Int64(42L)])
  let got = match result {
    Ok(r) => r.get(0)
    Err(_) => "fail"
  }
  inspect(got, content="42")
}

test "mock: :exec — exec returns affected row count" {
  let mock = MockDB::new(
    Ok(3L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.exec("DELETE FROM users WHERE id = $1", [Int64(42L)])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="3")
}

test "mock: :execrows — execrows returns affected row count" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(5L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.execrows("UPDATE users SET name = $1 WHERE id = $2", [String("Bob"), Int64(1L)])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="5")
}

test "mock: error propagation — exec returns Err" {
  let mock = MockDB::new(
    Err(QueryError("table not found")),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.exec("DROP TABLE t", [])
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "mock: error propagation — query_row returns Err" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Err(QueryError("no rows")),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.query_row("SELECT 1", [])
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "mock: query with empty results" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.query("SELECT 1 WHERE false", [])
  let rows = match result {
    Ok(iter) => { match (iter).collect() { Ok(r) => r; Err(_) => { inspect("fail", content="fail"); return } } }
    Err(_) => { inspect("fail", content="fail"); return }
  }
  inspect(rows.length(), content="0")
}

test "mock: :many — decode each row through typed getters" {
  let row = Row::new(fn(i) { if i == 0 { "1" } else if i == 1 { "Alice" } else if i == 2 { "alice@test.com" } else { "" } }, Array::make(4, false))
  let mut row_idx = 0
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() {
      if row_idx < 1 {
        row_idx = row_idx + 1
        Ok(Some(row))
      } else {
        Ok(None)
      }
    })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let iter = match db.query("SELECT id, name, email FROM users", []) {
    Ok(iter) => iter
    Err(_) => { inspect("fail", content="fail"); return }
  }
  let rows = match (iter).collect() {
    Ok(rows) => rows
    Err(_) => { inspect("fail", content="fail"); return }
  }
  inspect(rows.length(), content="1")
  let id = match (rows[0]).get_int64(0) { Ok(n) => n; Err(_) => 0L }
  let name = match (rows[0]).get_string(1) { Ok(s) => s; Err(_) => "" }
  let email = match (rows[0]).get_nullable_string(2) { Ok(o) => { match o { Some(s) => s; None => "" } }; Err(_) => "" }
  inspect(id, content="1")
  inspect(name, content="Alice")
  inspect(email, content="alice@test.com")
}

test "mock: :copyfrom — copyfrom returns affected row count" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(10L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.copyfrom("COPY users FROM stdin", [])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="10")
}

test "mock: :batch — batch returns affected row count" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(3L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.batch("INSERT INTO t VALUES (1), (2), (3)", [])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="3")
}

test "mock: :execlastid — execlastid returns last insert id" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(100L),
    None,
  )
  let db = mock.build()
  let result = db.execlastid("INSERT INTO users (name) VALUES ($1)", [String("Bob")])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="100")
}

test "mock: :copyfrom error propagation" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Err(QueryError("copy failed")),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.copyfrom("COPY bad", [])
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "mock: :batch error propagation" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Err(QueryError("batch failed")),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.batch("BAD SQL", [])
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "mock: :execlastid error propagation" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Err(QueryError("insert failed")),
    None,
  )
  let db = mock.build()
  let result = db.execlastid("INSERT INTO t VALUES (1)", [])
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "mock: transaction — begin returns Ok with configurable tx" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(3L) },
    fn(_sql, _params) { Ok(7L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(i) { if i == 0 { "42" } else { "" } }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    Some(fn() { Ok(tx) }),
  )
  let db = mock.build()
  let result = db.begin()
  let tx_got = match result {
    Ok(t) => t
    Err(_) => { inspect("no tx", content="fail"); return }
  }
  // Verify tx methods work
  let exec_result = tx_got.exec("DELETE FROM t", [])
  let exec_val = match exec_result { Ok(n) => n; Err(_) => 0L }
  inspect(exec_val, content="3")

  let execrows_result = tx_got.execrows("UPDATE t SET x = 1", [])
  let execrows_val = match execrows_result { Ok(n) => n; Err(_) => 0L }
  inspect(execrows_val, content="7")

  let query_result = tx_got.query("SELECT 1", [])
  let query_ok = match query_result { Ok(_) => true; Err(_) => false }
  inspect(query_ok, content="true")

  let query_row_result = tx_got.query_row("SELECT 42", [])
  let query_row_val = match query_row_result { Ok(row) => row.get(0); Err(_) => "" }
  inspect(query_row_val, content="42")

  let commit_ok = match tx_got.commit() { Ok(_) => true; Err(_) => false }
  inspect(commit_ok, content="true")

  let rollback_ok = match tx_got.rollback() { Ok(_) => true; Err(_) => false }
  inspect(rollback_ok, content="true")
}

test "mock: transaction — begin returns Err when tx_fn is None" {
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.begin()
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

/// P1-042: Verify SQL is actually passed through to the mock closures.
/// This validates the SQL matching contract using inspect inside closures.
test "mock: sql pass-through — exec receives correct SQL string" {
  let mut captured = ""
  let db = DB::new(
    fn(sql, _params) {
      captured = sql
      Ok(1L)
    },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Err(QueryError("transactions not supported")) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
  )
  let _ = db.exec("DELETE FROM users WHERE id = $1", [Int64(42L)])
  inspect(captured, content="DELETE FROM users WHERE id = $1")
}

test "mock: sql pass-through — query receives correct SQL string" {
  let mut captured2 = ""
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(sql, _params) {
      captured2 = sql
      Ok(RowIter::new(fn() { Ok(None) }))
    },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Err(QueryError("transactions not supported")) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
  )
  let _ = db.query("SELECT id, name FROM users WHERE name = $1", [String("Alice")])
  inspect(captured2, content="SELECT id, name FROM users WHERE name = $1")
}

test "mock: sql pass-through — execrows receives correct SQL" {
  let mut captured3 = ""
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(sql, _params) {
      captured3 = sql
      Ok(5L)
    },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Err(QueryError("transactions not supported")) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
  )
  let _ = db.execrows("UPDATE users SET name = $2 WHERE id = $1", [Int64(1L), String("Bob")])
  inspect(captured3, content="UPDATE users SET name = $2 WHERE id = $1")
}

test "mock: sql pass-through — copyfrom receives SQL" {
  let mut captured4 = ""
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Err(QueryError("transactions not supported")) },
    fn(sql, _params) {
      captured4 = sql
      Ok(10L)
    },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
  )
  let _ = db.copyfrom("COPY users FROM stdin", [])
  inspect(captured4, content="COPY users FROM stdin")
}

test "mock: sequential operations — exec then query on same DB" {
  let mut exec_called = false
  let mut query_called = false
  let db = DB::new(
    fn(_sql, _params) { exec_called = true; Ok(3L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) {
      query_called = true
      let row = Row::new(fn(i) { if i == 0 { "1" } else { "" } }, Array::make(1, false))
      let mut idx = 0
      Ok(RowIter::new(fn() {
        if idx < 1 { idx = idx + 1; Ok(Some(row)) } else { Ok(None) }
      }))
    },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Err(QueryError("transactions not supported")) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
  )
  let _ = db.exec("INSERT INTO users VALUES (1, 'Alice')", [])
  let result = db.query("SELECT * FROM users", [])
  let rows = match result { Ok(iter) => { match iter.collect() { Ok(r) => r; _ => [] } }; _ => [] }
  inspect(exec_called, content="true")
  inspect(query_called, content="true")
  inspect(rows.length(), content="1")
}

test "mock: all error defaults — every operation returns Err" {
  let mock = MockDB::new(
    Err(ConnectionError("db down")),
    Err(ConnectionError("db down")),
    Err(ConnectionError("db down")),
    Err(ConnectionError("db down")),
    Err(ConnectionError("db down")),
    Err(ConnectionError("db down")),
    Err(ConnectionError("db down")),
    None,
  )
  let db = mock.build()
  // All operations should return Err
  let exec_err = match db.exec("SELECT 1", []) { Err(_) => true; _ => false }
  let execrows_err = match db.execrows("SELECT 1", []) { Err(_) => true; _ => false }
  let query_err = match db.query("SELECT 1", []) { Err(_) => true; _ => false }
  let query_row_err = match db.query_row("SELECT 1", []) { Err(_) => true; _ => false }
  let copyfrom_err = match db.copyfrom("COPY", []) { Err(_) => true; _ => false }
  let batch_err = match db.batch("INSERT INTO t VALUES (1)", []) { Err(_) => true; _ => false }
  let execlastid_err = match db.execlastid("INSERT INTO t VALUES (1)", []) { Err(_) => true; _ => false }
  inspect(exec_err, content="true")
  inspect(execrows_err, content="true")
  inspect(query_err, content="true")
  inspect(query_row_err, content="true")
  inspect(copyfrom_err, content="true")
  inspect(batch_err, content="true")
  inspect(execlastid_err, content="true")
}

test "mock: query_row with complex return — multiple columns typed getters" {
  let row = Row::new(
    fn(i) {
      if i == 0 { "42" }
      else if i == 1 { "Alice" }
      else if i == 2 { "alice@example.com" }
      else { "" }
    },
    Array::make(4, false),
  )
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(row),
    Ok(1L),
    Ok(1L),
    Ok(1L),
    None,
  )
  let db = mock.build()
  let result = db.query_row("SELECT id, name, email FROM users WHERE id = $1", [Int64(42L)])
  let row_got = match result { Ok(r) => r; Err(_) => { inspect("fail", content="fail"); return } }
  let id = match row_got.get_int64(0) { Ok(n) => n; Err(_) => 0L }
  let name = match row_got.get_string(1) { Ok(s) => s; Err(_) => "" }
  let email = match row_got.get_nullable_string(2) {
    Ok(o) => match o { Some(s) => s; None => "" }
    Err(_) => ""
  }
  inspect(id, content="42")
  inspect(name, content="Alice")
  inspect(email, content="alice@example.com")
}

test "mock: transaction exec error propagation" {
  let tx = Transaction::new(
    fn(_sql, _params) { Err(QueryError("tx exec failed")) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let mock = MockDB::new(
    Ok(1L), Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L), Ok(1L), Ok(1L),
    Some(fn() { Ok(tx) }),
  )
  let db = mock.build()
  let tx_got = match db.begin() { Ok(t) => t; Err(_) => { inspect("fail", content="fail"); return } }
  let exec_result = tx_got.exec("BAD SQL", [])
  let is_err = match exec_result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "mock: zero params — exec with empty params array" {
  let mock = MockDB::new(
    Ok(1L), Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(Row::new(fn(_i) { "" }, Array::make(1, false))),
    Ok(1L), Ok(1L), Ok(1L),
    None,
  )
  let db = mock.build()
  // Empty params array (not just [], but explicitly zero-length)
  let empty_params: Array[Value] = []
  let result = db.exec("SELECT 1", empty_params)
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="1")
}

// === P1-042: MockDB API enhancements — default_ok, MockDBBuilder, SQL pattern matching ===

test "mock: default_ok — all operations return Ok defaults" {
  let db = MockDB::default_ok().build()
  // All operations should return Ok defaults
  let exec_val = match db.exec("ANYTHING", []) { Ok(n) => n; Err(_) => -1L }
  let execrows_val = match db.execrows("ANYTHING", []) { Ok(n) => n; Err(_) => -1L }
  let query_rows = match db.query("ANYTHING", []) { Ok(iter) => { match iter.collect() { Ok(r) => r.length(); _ => -1 } }; _ => -1 }
  let query_row_val = match db.query_row("ANYTHING", []) { Ok(row) => row.column_count(); Err(_) => -1 }
  let copyfrom_val = match db.copyfrom("ANYTHING", []) { Ok(n) => n; Err(_) => -1L }
  let batch_val = match db.batch("ANYTHING", []) { Ok(n) => n; Err(_) => -1L }
  let execlastid_val = match db.execlastid("ANYTHING", []) { Ok(n) => n; Err(_) => -1L }
  inspect(exec_val, content="0")
  inspect(execrows_val, content="0")
  inspect(query_rows, content="0")
  inspect(query_row_val, content="0")
  inspect(copyfrom_val, content="0")
  inspect(batch_val, content="0")
  inspect(execlastid_val, content="0")
  // begin should return Err since tx_fn is None
  let begin_err = match db.begin() { Err(QueryError(_)) => true; _ => false }
  inspect(begin_err, content="true")
}

test "mock: builder register_exec — exact SQL match returns registered result" {
  let db = MockDBBuilder::new()
    .register_exec("DELETE FROM users WHERE id = $1", Ok(5L))
    .build()
  let result = db.exec("DELETE FROM users WHERE id = $1", [Int64(42L)])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="5")
}

test "mock: builder exact match — SQL must match exactly (prefix does not count)" {
  let db = MockDBBuilder::new()
    .register_execrows("UPDATE users SET name = $1 WHERE id = $2", Ok(3L))
    .build()
  // Exact match → Ok(3L)
  let result1 = db.execrows("UPDATE users SET name = $1 WHERE id = $2", [String("Bob"), Int64(1L)])
  let n1 = match result1 { Ok(n) => n; Err(_) => 0L }
  inspect(n1, content="3")
  // Prefix match only → falls back to default (Ok(0L))
  let result2 = db.execrows("UPDATE users SET name = $1", [String("Bob")])
  let n2 = match result2 { Ok(n) => n; Err(_) => -1L }
  inspect(n2, content="0")
}

test "mock: builder register_query — exact SQL match returns registered RowIter" {
  let row = Row::new(fn(i) { if i == 0 { "1" } else if i == 1 { "Alice" } else { "" } }, Array::make(2, false))
  let mut called = false
  let iter = RowIter::new(fn() {
    if !called { called = true; Ok(Some(row)) } else { Ok(None) }
  })
  let db = MockDBBuilder::new()
    .register_query("SELECT id, name FROM users", Ok(iter))
    .build()
  let result = db.query("SELECT id, name FROM users", [])
  let rows = match result { Ok(iter2) => { match iter2.collect() { Ok(r) => r; _ => [] } }; _ => [] }
  inspect(rows.length(), content="1")
  let name = (rows[0]).get(1)
  inspect(name, content="Alice")
}

test "mock: builder register_query_row — exact SQL match returns registered Row" {
  let row = Row::new(fn(i) { if i == 0 { "42" } else if i == 1 { "Alice" } else { "" } }, Array::make(2, false))
  let db = MockDBBuilder::new()
    .register_query_row("SELECT id, name FROM users WHERE id = $1", Ok(row))
    .build()
  let result = db.query_row("SELECT id, name FROM users WHERE id = $1", [Int64(42L)])
  let got = match result { Ok(r) => r.get(0); Err(_) => "fail" }
  inspect(got, content="42")
}

test "mock: builder multiple exec patterns — different SQL returns different results" {
  let db = MockDBBuilder::new()
    .register_exec("DELETE FROM users WHERE id = $1", Ok(1L))
    .register_exec("DELETE FROM orders", Ok(10L))
    .register_exec("DELETE FROM products", Err(QueryError("products table locked")))
    .build()
  // First pattern
  let r1 = match db.exec("DELETE FROM users WHERE id = $1", [Int64(1L)]) { Ok(n) => n; Err(_) => -1L }
  inspect(r1, content="1")
  // Second pattern
  let r2 = match db.exec("DELETE FROM orders", []) { Ok(n) => n; Err(_) => -1L }
  inspect(r2, content="10")
  // Third pattern (error)
  let r3_is_err = match db.exec("DELETE FROM products", []) { Err(QueryError(_)) => true; _ => false }
  inspect(r3_is_err, content="true")
  // Unmatched SQL → default Ok(0L)
  let r4 = match db.exec("UNRECOGNIZED SQL", []) { Ok(n) => n; Err(_) => -1L }
  inspect(r4, content="0")
}

test "mock: builder register_copyfrom — exact SQL match" {
  let db = MockDBBuilder::new()
    .register_copyfrom("COPY users FROM stdin", Ok(42L))
    .build()
  let result = db.copyfrom("COPY users FROM stdin", [])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="42")
}

test "mock: builder register_batch — exact SQL match" {
  let db = MockDBBuilder::new()
    .register_batch("INSERT INTO t VALUES (1), (2), (3)", Ok(3L))
    .build()
  let result = db.batch("INSERT INTO t VALUES (1), (2), (3)", [])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="3")
}

test "mock: builder register_execlastid — exact SQL match" {
  let db = MockDBBuilder::new()
    .register_execlastid("INSERT INTO users (name) VALUES ($1)", Ok(100L))
    .build()
  let result = db.execlastid("INSERT INTO users (name) VALUES ($1)", [String("Bob")])
  let n = match result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="100")
}

test "mock: builder with_tx — begin returns Ok with registered transaction" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(99L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let db = MockDBBuilder::new()
    .with_tx(fn() { Ok(tx) })
    .build()
  let tx_result = db.begin()
  let tx_got = match tx_result { Ok(t) => t; Err(_) => { inspect("fail", content="fail"); return } }
  let exec_result = tx_got.exec("SELECT 1", [])
  let n = match exec_result { Ok(n) => n; Err(_) => 0L }
  inspect(n, content="99")
}

test "mock: builder patterns not matched — fall back to Ok defaults" {
  let db = MockDBBuilder::new()
    .register_exec("DELETE FROM users", Ok(5L))
    .build()
  // Registered SQL → returns 5L
  let r1 = match db.exec("DELETE FROM users", []) { Ok(n) => n; Err(_) => 0L }
  inspect(r1, content="5")
  // Unregistered exec SQL → fallback Ok(0L)
  let r2 = match db.exec("SOME OTHER SQL", []) { Ok(n) => n; Err(_) => -1L }
  inspect(r2, content="0")
  // Unregistered query → fallback empty RowIter
  let query_rows = match db.query("SOME OTHER SQL", []) { Ok(iter) => { match iter.collect() { Ok(r) => r.length(); _ => -1 } }; _ => -1 }
  inspect(query_rows, content="0")
  // Unregistered query_row → fallback empty Row (0 columns)
  let qr_cols = match db.query_row("SOME OTHER SQL", []) { Ok(row) => row.column_count(); Err(_) => -1 }
  inspect(qr_cols, content="0")
}

test "mock: builder register_execrows — error result propagated" {
  let db = MockDBBuilder::new()
    .register_execrows("BAD SQL", Err(QueryError("table not found")))
    .build()
  let result = db.execrows("BAD SQL", [])
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "mock: builder chained registration — fluent API supports multiple calls" {
  let row = Row::new(fn(_i) { "hello" }, Array::make(1, false))
  let iter = RowIter::new(fn() { Ok(None) })
  let db = MockDBBuilder::new()
    .register_exec("SQL_EXEC", Ok(7L))
    .register_execrows("SQL_EXECROWS", Ok(11L))
    .register_query("SQL_QUERY", Ok(iter))
    .register_query_row("SQL_QUERY_ROW", Ok(row))
    .register_copyfrom("SQL_COPY", Ok(13L))
    .register_batch("SQL_BATCH", Ok(17L))
    .register_execlastid("SQL_LASTID", Ok(19L))
    .build()
  // Verify each registered pattern
  let exec_n = match db.exec("SQL_EXEC", []) { Ok(n) => n; Err(_) => 0L }
  let execrows_n = match db.execrows("SQL_EXECROWS", []) { Ok(n) => n; Err(_) => 0L }
  let query_empty = match db.query("SQL_QUERY", []) { Ok(iter2) => { match iter2.collect() { Ok(r) => r.length(); _ => -1 } }; _ => -1 }
  let qr_val = match db.query_row("SQL_QUERY_ROW", []) { Ok(r) => r.get(0); Err(_) => "" }
  let copy_n = match db.copyfrom("SQL_COPY", []) { Ok(n) => n; Err(_) => 0L }
  let batch_n = match db.batch("SQL_BATCH", []) { Ok(n) => n; Err(_) => 0L }
  let lastid_n = match db.execlastid("SQL_LASTID", []) { Ok(n) => n; Err(_) => 0L }
  inspect(exec_n, content="7")
  inspect(execrows_n, content="11")
  inspect(query_empty, content="0")
  inspect(qr_val, content="hello")
  inspect(copy_n, content="13")
  inspect(batch_n, content="17")
  inspect(lastid_n, content="19")
}

test "P1-007: duplicate SQL registration records builder error" {
  let builder = MockDBBuilder::new()
    .register_exec("SQL_A", Ok(1L))
    .register_exec("SQL_A", Ok(2L))
  inspect(builder.errors().length(), content="1")
  inspect(builder.errors()[0].contains("duplicate"), content="true")
}
