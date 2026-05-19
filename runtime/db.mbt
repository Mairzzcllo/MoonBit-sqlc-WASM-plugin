///|
/// Database connection abstraction.
/// Generated code accepts DB as a parameter for each query function.
/// Real database drivers provide exec/execrows/query/query_row implementations via closures.
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

/// Concrete DB handle wrapping driver-specific implementations.
/// Each method accepts a SQL string and typed parameters, returning Result.
pub struct DB {
  exec_fn : (String, Array[Value]) -> Result[Int64, DBError]
  execrows_fn : (String, Array[Value]) -> Result[Int64, DBError]
  query_fn : (String, Array[Value]) -> Result[RowIter, DBError]
  query_row_fn : (String, Array[Value]) -> Result[Row, DBError]
  begin_fn : () -> Result[Transaction, DBError]
}

pub fn DB::new(
  exec_fn: (String, Array[Value]) -> Result[Int64, DBError],
  execrows_fn: (String, Array[Value]) -> Result[Int64, DBError],
  query_fn: (String, Array[Value]) -> Result[RowIter, DBError],
  query_row_fn: (String, Array[Value]) -> Result[Row, DBError],
  begin_fn: () -> Result[Transaction, DBError],
) -> DB {
  {
    exec_fn: exec_fn,
    execrows_fn: execrows_fn,
    query_fn: query_fn,
    query_row_fn: query_row_fn,
    begin_fn: begin_fn,
  }
}

/// Execute a SQL statement returning the number of affected rows.
pub fn DB::exec(self: DB, sql: String, params: Array[Value]) -> Result[Int64, DBError] {
  (self.exec_fn)(sql, params)
}

/// Execute a SQL statement returning the count of affected rows.
pub fn DB::execrows(self: DB, sql: String, params: Array[Value]) -> Result[Int64, DBError] {
  (self.execrows_fn)(sql, params)
}

/// Execute a query returning a RowIter for :many results.
pub fn DB::query(self: DB, sql: String, params: Array[Value]) -> Result[RowIter, DBError] {
  (self.query_fn)(sql, params)
}

/// Execute a query returning a single Row for :one results.
pub fn DB::query_row(self: DB, sql: String, params: Array[Value]) -> Result[Row, DBError] {
  (self.query_row_fn)(sql, params)
}

/// Begin a new transaction, returning a Result[Transaction, DBError].
/// The caller is responsible for calling commit or rollback on success.
pub fn DB::begin(self: DB) -> Result[Transaction, DBError] {
  (self.begin_fn)()
}

test "DB::new and exec returns Ok" {
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok({ get_fn: fn(_i) { "" } }) },
    fn() { Err(QueryError("transactions not supported")) },
  )
  let result = db.exec("DELETE FROM t", [])
  let val = match result { Ok(n) => n; Err(_) => 0L }
  inspect(val, content="1")
}

test "DB::execrows returns Ok with count" {
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(5L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok({ get_fn: fn(_i) { "" } }) },
    fn() { Err(QueryError("transactions not supported")) },
  )
  let result = db.execrows("UPDATE t SET x = 1", [])
  let val = match result { Ok(n) => n; Err(_) => 0L }
  inspect(val, content="5")
}

test "DB::query returns RowIter" {
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok({ get_fn: fn(_i) { "" } }) },
    fn() { Err(QueryError("transactions not supported")) },
  )
  let result = db.query("SELECT 1", [])
  let empty = match result { Ok(iter) => { match iter.collect() { Ok(rows) => rows.length(); _ => -1 } }; _ => -1 }
  inspect(empty, content="0")
}

test "DB::query_row returns Row" {
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok({ get_fn: fn(i) { if i == 0 { "42" } else { "" } } }) },
    fn() { Err(QueryError("transactions not supported")) },
  )
  let result = db.query_row("SELECT 42", [])
  let val = match result { Ok(row) => row.get(0); Err(_) => "" }
  inspect(val, content="42")
}

test "DB::exec returns Err on failure" {
  let db = DB::new(
    fn(_sql, _params) { Err(QueryError("table not found")) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok({ get_fn: fn(_i) { "" } }) },
    fn() { Err(QueryError("transactions not supported")) },
  )
  let result = db.exec("DROP TABLE t", [])
  let is_err = match result { Err(_) => true; _ => false }
  inspect(is_err, content="true")
}

test "DB::begin returns Ok with Transaction" {
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok({ get_fn: fn(_i) { "" } }) },
    fn() {
      Ok(Transaction::new(
        fn(_sql, _params) { Ok(1L) },
        fn(_sql, _params) { Ok(1L) },
        fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
        fn(_sql, _params) { Ok({ get_fn: fn(_i) { "" } }) },
        fn() { Ok(()) },
        fn() { Ok(()) },
      ))
    },
  )
  let result = db.begin()
  let ok = match result { Ok(_) => true; Err(_) => false }
  inspect(ok, content="true")
}

test "DB::begin returns Err on failure" {
  let db = DB::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok({ get_fn: fn(_i) { "" } }) },
    fn() { Err(QueryError("begin failed")) },
  )
  let result = db.begin()
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}
