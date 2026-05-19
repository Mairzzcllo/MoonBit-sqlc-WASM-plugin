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

const GOLDEN_USERS: String = "/// users table\npub struct Users {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a Users\npub fn Users::decode(row: Row) -> Users {\n  { id: try @string.parse_int(row.get(0)) catch { _ => 0 }, name: row.get(1), email: Some(row.get(2)) }\n}\n\npub enum UserRole {\n  Admin\n  Editor\n  Viewer\n}\n\n/// List all users\npub struct ListUsersRow {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a ListUsersRow\npub fn ListUsersRow::decode(row: Row) -> ListUsersRow {\n  { id: try @string.parse_int(row.get(0)) catch { _ => 0 }, name: row.get(1), email: Some(row.get(2)) }\n}\n\n/// Get user by ID\npub struct GetUserRow {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a GetUserRow\npub fn GetUserRow::decode(row: Row) -> GetUserRow {\n  { id: try @string.parse_int(row.get(0)) catch { _ => 0 }, name: row.get(1), email: Some(row.get(2)) }\n}\n\n/// List all users\npub fn query_list_users(db: DB) -> Array[ListUsersRow] {\n  let sql = \"SELECT id, name, email FROM users\"\n  let rows = db.query(sql)\n  rows.map({|row: Row| ListUsersRow::decode(row)})\n}\n\n/// Get user by ID\npub fn query_get_user(db: DB, id: Int) -> Option[GetUserRow] {\n  let sql = \"SELECT id, name, email FROM users WHERE id = \\$1\"\n  let rows = db.query(sql)\n  if rows.length() > 0 {\n    Some(GetUserRow::decode(rows[0]))\n  } else {\n    None\n  }\n}\n\npub fn query_delete_user(db: DB, id: Int) -> Int {\n  let sql = \"DELETE FROM users WHERE id = \\$1\"\n  db.exec(sql)\n}\n"

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
  inspect(result.contains("created_at: String"), content="true")
}

test "golden: realistic types — decode body contains parse_int64 for Int64 columns" {
  let req = make_realistic_request()
  let result = generate_source(req)
  inspect(result.contains("@string.parse_int64(row.get(0))"), content="true")
  inspect(result.contains("@string.parse_int64(row.get(1))"), content="true")
}

test "golden: deterministic output" {
  let req = make_users_request()
  let result1 = generate_source(req)
  let result2 = generate_source(req)
  inspect(result1, content=result2)
}
