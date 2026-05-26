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

const GOLDEN_USERS: String = "package testdb\n\n/// users table\npub struct Users {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a Users\npub fn Users::decode(row: Row) -> Result[Users, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\npub enum UserRole {\n  Admin\n  Editor\n  Viewer\n}\n\n/// List all users\npub struct ListUsersRow {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a ListUsersRow\npub fn ListUsersRow::decode(row: Row) -> Result[ListUsersRow, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// Get user by ID\npub struct GetUserRow {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a GetUserRow\npub fn GetUserRow::decode(row: Row) -> Result[GetUserRow, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// List all users\npub fn query_list_users(db: DB) -> Result[Array[ListUsersRow], DBError] {\n  let sql = \"SELECT id, name, email FROM users\"\n  let params = []\n  match db.query(sql, params) {\n    Ok(iter) => match iter.collect() {\n      Ok(rows) => {\n        let result = []\n        for row in rows {\n          match ListUsersRow::decode(row) {\n            Ok(v) => result.push(v)\n            Err(e) => return Err(e)\n          }\n        }\n        Ok(result)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// List all users\npub fn query_list_users(tx: Transaction) -> Result[Array[ListUsersRow], DBError] {\n  let sql = \"SELECT id, name, email FROM users\"\n  let params = []\n  match tx.query(sql, params) {\n    Ok(iter) => match iter.collect() {\n      Ok(rows) => {\n        let result = []\n        for row in rows {\n          match ListUsersRow::decode(row) {\n            Ok(v) => result.push(v)\n            Err(e) => return Err(e)\n          }\n        }\n        Ok(result)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// Get user by ID\npub fn query_get_user(db: DB, id: Int) -> Result[GetUserRow, DBError] {\n  let sql = \"SELECT id, name, email FROM users WHERE id = $1\"\n  let params = [Int64(id)]\n  match db.query_row(sql, params) {\n    Ok(row) => GetUserRow::decode(row)\n    Err(e) => Err(e)\n  }\n}\n\n/// Get user by ID\npub fn query_get_user(tx: Transaction, id: Int) -> Result[GetUserRow, DBError] {\n  let sql = \"SELECT id, name, email FROM users WHERE id = $1\"\n  let params = [Int64(id)]\n  match tx.query_row(sql, params) {\n    Ok(row) => GetUserRow::decode(row)\n    Err(e) => Err(e)\n  }\n}\n\npub fn query_delete_user(db: DB, id: Int) -> Result[Int64, DBError] {\n  let sql = \"DELETE FROM users WHERE id = $1\"\n  let params = [Int64(id)]\n  db.exec(sql, params)\n}\n\npub fn query_delete_user(tx: Transaction, id: Int) -> Result[Int64, DBError] {\n  let sql = \"DELETE FROM users WHERE id = $1\"\n  let params = [Int64(id)]\n  tx.exec(sql, params)\n}\n"

test "golden: full pipeline matches expected output" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb" })
  inspect(result, content=GOLDEN_USERS)
}

test "golden: realistic types — bigserial→Int64, pg_catalog.int8→Int64, TEXT[]→Option[Array[String]]" {
  let req = make_realistic_request()
  let result = generate_source(req, { package_name: "testdb" })
  inspect(result.contains("id: Int64"), content="true")
  inspect(result.contains("author_id: Int64"), content="true")
  inspect(result.contains("title: String"), content="true")
  inspect(result.contains("tags: Option[Array[String]]"), content="true")
  inspect(result.contains("created_at: DateTime"), content="true")
}

test "golden: realistic types — decode body uses typed getters for Int64 columns" {
  let req = make_realistic_request()
  let result = generate_source(req, { package_name: "testdb" })
  inspect(result.contains("row.get_int64("), content="true")
}

test "golden: deterministic output" {
  let req = make_users_request()
  let result1 = generate_source(req, { package_name: "testdb" })
  let result2 = generate_source(req, { package_name: "testdb" })
  inspect(result1, content=result2)
}

test "golden: all PG types — struct field types" {
  let req = make_all_types_request()
  let result = generate_source(req, { package_name: "testdb" })
  inspect(result.contains("is_active: Bool"), content="true")
  inspect(result.contains("score: Double"), content="true")
  inspect(result.contains("data: Option[Bytes]"), content="true")
  inspect(result.contains("created_date: Date"), content="true")
  inspect(result.contains("created_at: DateTime"), content="true")
  inspect(result.contains("updated_at: Option[DateTime]"), content="true")
  inspect(result.contains("metadata: Option[JsonValue]"), content="true")
  inspect(result.contains("price: Decimal"), content="true")
  inspect(result.contains("uid: Uuid"), content="true")
  inspect(result.contains("device_ip: Option[IpAddr]"), content="true")
  inspect(result.contains("small_num: Int"), content="true")
  inspect(result.contains("real_num: Double"), content="true")
  inspect(result.contains("label: String"), content="true")
  inspect(result.contains("event_time: Option[Time]"), content="true")
  inspect(result.contains("duration: Option[Duration]"), content="true")
  inspect(result.contains("tags: Option[Array[String]]"), content="true")
}

test "golden: all PG types — decode getters" {
  let req = make_all_types_request()
  let result = generate_source(req, { package_name: "testdb" })
  inspect(result.contains("row.get_int64(0)"), content="true")
  inspect(result.contains("row.get_bool(1)"), content="true")
  inspect(result.contains("row.get_double(2)"), content="true")
  inspect(result.contains("row.get_nullable_bytes(3)"), content="true")
  inspect(result.contains("row.get_date(4)"), content="true")
  inspect(result.contains("row.get_datetime(5)"), content="true")
  inspect(result.contains("row.get_nullable_datetime(6)"), content="true")
  inspect(result.contains("row.get_nullable_json(7)"), content="true")
  inspect(result.contains("row.get_decimal(8)"), content="true")
  inspect(result.contains("row.get_uuid(9)"), content="true")
  inspect(result.contains("row.get_nullable_ipaddr(10)"), content="true")
  inspect(result.contains("row.get_int64(11)"), content="true")
  inspect(result.contains("row.get_double(12)"), content="true")
  inspect(result.contains("row.get_string(13)"), content="true")
  inspect(result.contains("row.get_nullable_time(14)"), content="true")
  inspect(result.contains("row.get_nullable_duration(15)"), content="true")
  inspect(result.contains("row.decode_nullable_array_string(16)"), content="true")
}

test "golden: all PG types — Value constructors in params" {
  let req = make_all_types_request()
  let result = generate_source(req, { package_name: "testdb" })
  inspect(result.contains("Int64(id)"), content="true")
  inspect(result.contains("Bool(is_active)"), content="true")
  inspect(result.contains("Double(score)"), content="true")
  inspect(result.contains("String(label)"), content="true")
}
