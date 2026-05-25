///|
/// MockDB for testing generated query functions without a real database.
/// Stores preset results for all four query modes: :one, :many, :exec, :execrows.
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
}

pub fn MockDB::new(
  exec_ok: Result[Int64, DBError],
  execrows_ok: Result[Int64, DBError],
  query_ok: Result[RowIter, DBError],
  query_row_ok: Result[Row, DBError],
  copyfrom_ok: Result[Int64, DBError],
  batch_ok: Result[Int64, DBError],
  execlastid_ok: Result[Int64, DBError],
) -> MockDB {
  {
    exec_ok: exec_ok,
    execrows_ok: execrows_ok,
    query_ok: query_ok,
    query_row_ok: query_row_ok,
    copyfrom_ok: copyfrom_ok,
    batch_ok: batch_ok,
    execlastid_ok: execlastid_ok,
  }
}

/// Build a DB instance from MockDB preset results.
/// The returned closures return the preset values for each operation.
pub fn MockDB::build(self: MockDB) -> DB {
  DB::new(
    fn(_sql, _params) { self.exec_ok },
    fn(_sql, _params) { self.execrows_ok },
    fn(_sql, _params) { self.query_ok },
    fn(_sql, _params) { self.query_row_ok },
    fn() { Err(QueryError("transactions not supported")) },
    fn(_sql, _params) { self.copyfrom_ok },
    fn(_sql, _params) { self.batch_ok },
    fn(_sql, _params) { self.execlastid_ok },
  )
}

// === Integration-style tests for all four query modes ===

test "mock: :many — query returns row iter with results" {
  let alice = Row::new(fn(i) { if i == 0 { "1" } else if i == 1 { "Alice" } else { "" } })
  let bob = Row::new(fn(i) { if i == 0 { "2" } else if i == 1 { "Bob" } else { "" } })
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(1L),
    Ok(1L),
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
  let row = Row::new(fn(i) { if i == 0 { "42" } else if i == 1 { "Alice" } else { "" } })
  let mock = MockDB::new(
    Ok(1L),
    Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(row),
    Ok(1L),
    Ok(1L),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(1L),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(1L),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(1L),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(1L),
    Ok(1L),
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
  let row = Row::new(fn(i) { if i == 0 { "1" } else if i == 1 { "Alice" } else if i == 2 { "alice@test.com" } else { "" } })
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(1L),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(10L),
    Ok(1L),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(3L),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(1L),
    Ok(100L),
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
    Ok(Row::new(fn(_i) { "" })),
    Err(QueryError("copy failed")),
    Ok(1L),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Err(QueryError("batch failed")),
    Ok(1L),
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
    Ok(Row::new(fn(_i) { "" })),
    Ok(1L),
    Ok(1L),
    Err(QueryError("insert failed")),
  )
  let db = mock.build()
  let result = db.execlastid("INSERT INTO t VALUES (1)", [])
  let is_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_err, content="true")
}
