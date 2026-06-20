///|
/// WASM compilation tests — P0-026.
/// Verifies the generated MoonBit code compiles with moonc without errors.
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

fn main { () }

test "wasm-compile: User struct can be constructed" {
  let u: User = { id: 1L, name: "Alice", email: "alice@test.com", created_at: DateTime::new("") }
  inspect(u.name, content="Alice")
}

test "wasm-compile: GetUserRow struct can be constructed" {
  let r: GetUserRow = { id: 1L, name: "Bob", email: "bob@test.com", created_at: DateTime::new("") }
  inspect(r.id, content="1")
}

test "wasm-compile: query functions are callable" {
  let db: DB = { exec_fn: fn(_sql, _params) { Ok(0L) }, execrows_fn: fn(_sql, _params) { Ok(0L) }, query_fn: fn(_sql, _params) { Ok(RowIter::new([])) }, query_row_fn: fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) }, begin_fn: fn() { Err(QueryError("no tx")) }, copyfrom_fn: fn(_sql, _params) { Ok(0L) }, batch_fn: fn(_sql, _params) { Ok(0L) }, execlastid_fn: fn(_sql, _params) { Ok(0L) } }
  let result = query_delete_user(db, 42L)
  inspect(match result { Ok(r) => r.rows_affected; Err(_) => 0L }, content="0")
}

test "wasm-compile: query_list_users accepts DB" {
  let db: DB = { exec_fn: fn(_sql, _params) { Ok(0L) }, execrows_fn: fn(_sql, _params) { Ok(0L) }, query_fn: fn(_sql, _params) { Ok(RowIter::new([])) }, query_row_fn: fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) }, begin_fn: fn() { Err(QueryError("no tx")) }, copyfrom_fn: fn(_sql, _params) { Ok(0L) }, batch_fn: fn(_sql, _params) { Ok(0L) }, execlastid_fn: fn(_sql, _params) { Ok(0L) } }
  let result = query_list_users(db)
  inspect(match result { Ok(rows) => rows.length(); Err(_) => -1 }, content="0")
}

test "wasm-compile: DBError variant accessible" {
  let e: DBError = ConnectionError("err")
  inspect(match e { ConnectionError(s) => s; _ => "" }, content="err")
  let te: DBError = TypeError("type")
  inspect(match te { TypeError(s) => s; _ => "" }, content="type")
  let cn: DBError = ColumnNotFound("email")
  inspect(match cn { ColumnNotFound(s) => s; _ => "" }, content="email")
}

test "wasm-compile: Transaction type exists" {
  let tx: Transaction = {
    exec_fn: fn(_sql, _params) { Ok(0L) },
    execrows_fn: fn(_sql, _params) { Ok(0L) },
    query_fn: fn(_sql, _params) { Ok(RowIter::new([])) },
    query_row_fn: fn(_sql, _params) { Ok(Row::new(fn(_i) { "" }, Array::make(1, false))) },
    commit_fn: fn() { Ok(()) },
    rollback_fn: fn() { Ok(()) },
  }
  inspect(match (tx.commit_fn)() { Ok(_) => true; Err(_) => false }, content="true")
}
