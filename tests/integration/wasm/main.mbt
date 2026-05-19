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

test "wasm-compile: Users struct can be constructed" {
  let u: Users = { id: 1, name: "Alice", email: Some("alice@test.com") }
  inspect(u.name, content="Alice")
}

test "wasm-compile: GetUserRow struct can be constructed" {
  let r: GetUserRow = { id: 1, name: "Bob", email: None }
  inspect(r.id, content="1")
}

test "wasm-compile: query functions are callable" {
  let db: DB = { exec_fn: fn(_sql) { 0 }, execrows_fn: fn(_sql) { 0L }, query_fn: fn(_sql) { [] } }
  let count = query_delete_user(db, 42)
  inspect(count, content="0")
}

test "wasm-compile: UserRole enum variants accessible" {
  let role: UserRole = Admin
  inspect(match role { Admin => "admin"; _ => "other" }, content="admin")
}

test "wasm-compile: query_list_users accepts DB" {
  let db: DB = { exec_fn: fn(_sql) { 0 }, execrows_fn: fn(_sql) { 0L }, query_fn: fn(_sql) { [] } }
  let result: Array[ListUsersRow] = query_list_users(db)
  inspect(result.length(), content="0")
}
