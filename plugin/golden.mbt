///|
/// Golden Tests — P0-011.
/// End-to-end pipeline verification with fixed inputs.
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

const GOLDEN_USERS: String = "/// users table\npub struct Users {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a Users\npub fn Users::decode(row: Row) -> Result[Users, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\npub enum UserRole {\n  Admin\n  Editor\n  Viewer\n}\n\n/// List all users\npub struct ListUsersRow {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a ListUsersRow\npub fn ListUsersRow::decode(row: Row) -> Result[ListUsersRow, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// Get user by ID\npub struct GetUserRow {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a GetUserRow\npub fn GetUserRow::decode(row: Row) -> Result[GetUserRow, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// List all users\npub fn query_list_users(db: DB) -> Result[Array[ListUsersRow], DBError] {\n  let sql = \"SELECT id, name, email FROM users\"\n  let params = []\n  match db.query(sql, params) {\n    Ok(iter) => match iter.collect() {\n      Ok(rows) => {\n        let result = []\n        for row in rows {\n          match ListUsersRow::decode(row) {\n            Ok(v) => result.push(v)\n            Err(e) => return Err(e)\n          }\n        }\n        Ok(result)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// Get user by ID\npub fn query_get_user(db: DB, id: Int) -> Result[GetUserRow, DBError] {\n  let sql = \"SELECT id, name, email FROM users WHERE id = \\$1\"\n  let params = [Int64(id)]\n  match db.query_row(sql, params) {\n    Ok(row) => GetUserRow::decode(row)\n    Err(e) => Err(e)\n  }\n}\n\npub fn query_delete_user(db: DB, id: Int) -> Result[Int64, DBError] {\n  let sql = \"DELETE FROM users WHERE id = \\$1\"\n  let params = [Int64(id)]\n  db.exec(sql, params)\n}\n"

test "golden: full pipeline matches expected output" {
  let req = make_users_request()
  let result = generate_source(req)
  inspect(result, content=GOLDEN_USERS)
}

test "golden: realistic types — bigserial→Int64, pg_catalog.int8→Int64, TEXT[]→Option[Array[String]]" {
  let req = make_realistic_request()
  let result = generate_source(req)
  inspect(result.contains("id: Int64"), content="true")
  inspect(result.contains("author_id: Int64"), content="true")
  inspect(result.contains("title: String"), content="true")
  inspect(result.contains("tags: Option[Array[String]]"), content="true")
  inspect(result.contains("created_at: DateTime"), content="true")
}

test "golden: realistic types — decode body uses typed getters for Int64 columns" {
  let req = make_realistic_request()
  let result = generate_source(req)
  inspect(result.contains("row.get_int64("), content="true")
}

test "golden: deterministic output" {
  let req = make_users_request()
  let result1 = generate_source(req)
  let result2 = generate_source(req)
  inspect(result1, content=result2)
}
