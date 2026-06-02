///|
/// Transaction handle wrapping a database transaction.
/// Provides the same exec/query/query_row/execrows operations
/// as DB, scoped to a single transaction with commit/rollback.
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

/// Concrete Transaction handle wrapping driver-specific transaction operations.
pub struct Transaction {
  exec_fn : (String, Array[Value]) -> Result[Int64, DBError]
  execrows_fn : (String, Array[Value]) -> Result[Int64, DBError]
  query_fn : (String, Array[Value]) -> Result[RowIter, DBError]
  query_row_fn : (String, Array[Value]) -> Result[Row, DBError]
  commit_fn : () -> Result[Unit, DBError]
  rollback_fn : () -> Result[Unit, DBError]
}

pub fn Transaction::new(
  exec_fn: (String, Array[Value]) -> Result[Int64, DBError],
  execrows_fn: (String, Array[Value]) -> Result[Int64, DBError],
  query_fn: (String, Array[Value]) -> Result[RowIter, DBError],
  query_row_fn: (String, Array[Value]) -> Result[Row, DBError],
  commit_fn: () -> Result[Unit, DBError],
  rollback_fn: () -> Result[Unit, DBError],
) -> Transaction {
  {
    exec_fn: exec_fn,
    execrows_fn: execrows_fn,
    query_fn: query_fn,
    query_row_fn: query_row_fn,
    commit_fn: commit_fn,
    rollback_fn: rollback_fn,
  }
}

/// Execute a SQL statement within the transaction.
pub fn Transaction::exec(self: Transaction, sql: String, params: Array[Value]) -> Result[Int64, DBError] {
  (self.exec_fn)(sql, params)
}

/// Execute a SQL statement returning affected row count within the transaction.
pub fn Transaction::execrows(self: Transaction, sql: String, params: Array[Value]) -> Result[Int64, DBError] {
  (self.execrows_fn)(sql, params)
}

/// Execute a query within the transaction returning a RowIter for :many results.
pub fn Transaction::query(self: Transaction, sql: String, params: Array[Value]) -> Result[RowIter, DBError] {
  (self.query_fn)(sql, params)
}

/// Execute a query within the transaction returning a single Row for :one results.
pub fn Transaction::query_row(self: Transaction, sql: String, params: Array[Value]) -> Result[Row, DBError] {
  (self.query_row_fn)(sql, params)
}

/// Commit the transaction.
pub fn Transaction::commit(self: Transaction) -> Result[Unit, DBError] {
  (self.commit_fn)()
}

/// Rollback the transaction.
pub fn Transaction::rollback(self: Transaction) -> Result[Unit, DBError] {
  (self.rollback_fn)()
}

test "Transaction::new and exec returns Ok" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let result = tx.exec("DELETE FROM t", [])
  let val = match result { Ok(n) => n; Err(_) => 0L }
  inspect(val, content="1")
}

test "Transaction::execrows returns Ok with count" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(5L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let result = tx.execrows("UPDATE t SET x = 1", [])
  let val = match result { Ok(n) => n; Err(_) => 0L }
  inspect(val, content="5")
}

test "Transaction::query returns RowIter" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let result = tx.query("SELECT 1", [])
  let empty = match result { Ok(iter) => { match iter.collect() { Ok(rows) => rows.length(); _ => -1 } }; _ => -1 }
  inspect(empty, content="0")
}

test "Transaction::query_row returns Row" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(i) { if i == 0 { "42" } else { "" } }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let result = tx.query_row("SELECT 42", [])
  let val = match result { Ok(row) => row.get(0); Err(_) => "" }
  inspect(val, content="42")
}

test "Transaction::commit returns Ok" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let result = tx.commit()
  let ok = match result { Ok(_) => true; Err(_) => false }
  inspect(ok, content="true")
}

test "Transaction::rollback returns Ok" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let result = tx.rollback()
  let ok = match result { Ok(_) => true; Err(_) => false }
  inspect(ok, content="true")
}

test "Transaction::commit returns Err on failure" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Err(QueryError("commit failed")) },
    fn() { Ok(()) },
  )
  let result = tx.commit()
  match result {
    Err(QueryError(msg)) => inspect(msg, content="commit failed")
    _ => abort("expected commit error")
  }
}

test "Transaction::rollback returns Err on failure" {
  let tx = Transaction::new(
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Err(QueryError("rollback failed")) },
  )
  let result = tx.rollback()
  match result {
    Err(QueryError(msg)) => inspect(msg, content="rollback failed")
    _ => abort("expected rollback error")
  }
}

test "Transaction::exec returns Err on failure" {
  let tx = Transaction::new(
    fn(_sql, _params) { Err(QueryError("table not found")) },
    fn(_sql, _params) { Ok(1L) },
    fn(_sql, _params) { Ok(RowIter::new(fn() { Ok(None) })) },
    fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    fn() { Ok(()) },
    fn() { Ok(()) },
  )
  let result = tx.exec("DROP TABLE t", [])
  let is_err = match result { Err(_) => true; _ => false }
  inspect(is_err, content="true")
}
