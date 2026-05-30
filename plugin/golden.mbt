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

const GOLDEN_USERS: String = "package testdb\n\nimport \"Mairzzcllo/moonbit_sqlc_plugin/runtime\"\n\n/// users table\npub struct Users {\n  id: Int64\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a Users\npub fn Users::decode(row: Row) -> Result[Users, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\npub enum UserRole {\n  Admin\n  Editor\n  Viewer\n}\n\n/// List all users\npub struct ListUsersRow {\n  id: Int64\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a ListUsersRow\npub fn ListUsersRow::decode(row: Row) -> Result[ListUsersRow, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// Get user by ID\npub struct GetUserRow {\n  id: Int64\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Decode a Row into a GetUserRow\npub fn GetUserRow::decode(row: Row) -> Result[GetUserRow, DBError] {\n  match row.get_int64(0) {\n    Ok(id) => match row.get_string(1) {\n      Ok(name) => match row.get_nullable_string(2) {\n        Ok(email) => Ok({ id: id, name: name, email: email })\n        Err(e) => Err(e)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// List all users\npub fn query_list_users(db: DB) -> Result[Array[ListUsersRow], DBError] {\n  let sql = \"SELECT id, name, email FROM users\"\n  let params = []\n  match db.query(sql, params) {\n    Ok(iter) => match iter.collect() {\n      Ok(rows) => {\n        let result = []\n        for row in rows {\n          match ListUsersRow::decode(row) {\n            Ok(v) => result.push(v)\n            Err(e) => return Err(e)\n          }\n        }\n        Ok(result)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// List all users\npub fn query_list_users(tx: Transaction) -> Result[Array[ListUsersRow], DBError] {\n  let sql = \"SELECT id, name, email FROM users\"\n  let params = []\n  match tx.query(sql, params) {\n    Ok(iter) => match iter.collect() {\n      Ok(rows) => {\n        let result = []\n        for row in rows {\n          match ListUsersRow::decode(row) {\n            Ok(v) => result.push(v)\n            Err(e) => return Err(e)\n          }\n        }\n        Ok(result)\n      }\n      Err(e) => Err(e)\n    }\n    Err(e) => Err(e)\n  }\n}\n\n/// Get user by ID\npub fn query_get_user(db: DB, id: Int64) -> Result[GetUserRow, DBError] {\n  let sql = \"SELECT id, name, email FROM users WHERE id = \\$1\"\n  let params = [Int64(id)]\n  match db.query_row(sql, params) {\n    Ok(row) => GetUserRow::decode(row)\n    Err(e) => Err(e)\n  }\n}\n\n/// Get user by ID\npub fn query_get_user(tx: Transaction, id: Int64) -> Result[GetUserRow, DBError] {\n  let sql = \"SELECT id, name, email FROM users WHERE id = \\$1\"\n  let params = [Int64(id)]\n  match tx.query_row(sql, params) {\n    Ok(row) => GetUserRow::decode(row)\n    Err(e) => Err(e)\n  }\n}\n\npub fn query_delete_user(db: DB, id: Int64) -> Result[ExecResult, DBError] {\n  let sql = \"DELETE FROM users WHERE id = \\$1\"\n  let params = [Int64(id)]\n  match db.exec(sql, params) {\n    Ok(n) => Ok(ExecResult::new(0L, n))\n    Err(e) => Err(e)\n  }\n}\n\npub fn query_delete_user(tx: Transaction, id: Int64) -> Result[ExecResult, DBError] {\n  let sql = \"DELETE FROM users WHERE id = \\$1\"\n  let params = [Int64(id)]\n  match tx.exec(sql, params) {\n    Ok(n) => Ok(ExecResult::new(0L, n))\n    Err(e) => Err(e)\n  }\n}\n"

test "golden: full pipeline matches expected output" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  inspect(result, content=GOLDEN_USERS)
}

test "golden: realistic types — bigserial→Int64, pg_catalog.int8→Int64, TEXT[]→Option[Array[String]]" {
  let req = make_realistic_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  inspect(result.contains("id: Int64"), content="true")
  inspect(result.contains("author_id: Int64"), content="true")
  inspect(result.contains("title: String"), content="true")
  inspect(result.contains("tags: Option[Array[String]]"), content="true")
  inspect(result.contains("created_at: DateTime"), content="true")
}

test "golden: realistic types — decode body uses typed getters for Int64 columns" {
  let req = make_realistic_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  inspect(result.contains("row.get_int64("), content="true")
}

test "golden: deterministic output" {
  let req = make_users_request()
  let result1 = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  let result2 = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  inspect(result1, content=result2)
}

test "golden: all PG types — struct field types" {
  let req = make_all_types_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
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
  inspect(result.contains("small_num: Int64"), content="true")
  inspect(result.contains("real_num: Double"), content="true")
  inspect(result.contains("label: String"), content="true")
  inspect(result.contains("event_time: Option[Time]"), content="true")
  inspect(result.contains("duration: Option[Duration]"), content="true")
  inspect(result.contains("tags: Option[Array[String]]"), content="true")
}

test "golden: all PG types — decode getters" {
  let req = make_all_types_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
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
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  inspect(result.contains("Int64(id)"), content="true")
  inspect(result.contains("Bool(is_active)"), content="true")
  inspect(result.contains("Double(score)"), content="true")
  inspect(result.contains("String(label)"), content="true")
}

test "golden: emit_sql_as_comment=true includes SQL text in doc comments" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: true, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  // Doc comment contains SQL text when enabled
  inspect(result.contains("/// List all users"), content="true")
  inspect(result.contains("/// SELECT id, name, email FROM users"), content="true")
}

test "golden: emit_sql_as_comment=false omits SQL text from doc comments" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  // Doc comment does NOT contain SQL text when disabled
  inspect(result.contains("/// List all users"), content="true")
  inspect(result.contains("/// SELECT id, name, email FROM users"), content="false")
  // But SQL still appears in function body as string literal
  inspect(result.contains("let sql = \"SELECT id, name, email FROM users\""), content="true")
}

test "golden: emit_json_tags=true with json_tags_case_style=camel produces camelCase tags" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: true, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "camel", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  inspect(result.contains("@json.tag(\"id\")"), content="true")
  inspect(result.contains("@json.tag(\"name\")"), content="true")
  inspect(result.contains("@json.tag(\"email\")"), content="true")
}

test "golden: emit_json_tags=true with json_tags_case_style=pascal produces PascalCase tags" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: true, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "pascal", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  inspect(result.contains("@json.tag(\"Id\")"), content="true")
  inspect(result.contains("@json.tag(\"Name\")"), content="true")
  inspect(result.contains("@json.tag(\"Email\")"), content="true")
}

test "golden: initialisms=ID,URL affects PascalCase naming in query types" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "ID,URL", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  // With initialism "ID", "get_user" type should be GetUserRow (no change, "User" is not "ID")
  inspect(result.contains("GetUserRow"), content="true")
  inspect(result.contains("ListUsersRow"), content="true")
}

test "golden: full pipeline with emit_json_tags=true + json_tags_case_style=camel" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: true, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "ID,URL", json_tags_case_style: "camel", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  // Check JSON tags are camelCase
  inspect(result.contains("@json.tag(\"id\")"), content="true")
  inspect(result.contains("@json.tag(\"name\")"), content="true")
  inspect(result.contains("@json.tag(\"email\")"), content="true")
  // Check SQL appears in body and is referenced in doc (emit_sql_as_comment=false default)
  inspect(result.contains("let sql"), content="true")
}

test "golden: emit_exact_table_names=true does not crash" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: true, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  // Must at least produce valid output containing struct definitions
  inspect(result.contains("pub struct "), content="true")
  inspect(result.contains("pub fn "), content="true")
}

test "golden: emit_empty_slices=true generates Err(NoRows) arm" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: true, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  // With emit_empty_slices=true, Err(NoRows) is converted to Ok([])
  inspect(result.contains("Err(NoRows) => Ok([])"), content="true")
  // Other errors are still propagated
  inspect(result.contains("Err(e) => Err(e)"), content="true")
  // The buggy pattern Err(e) => Ok([]) must NOT appear
  inspect(result.contains("Err(e) => Ok([])"), content="false")
}

test "golden: emit_methods_with_db_argument=true does not crash" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: true, column_overrides: [], nullable_overrides: [] })
  // Must at least produce valid output containing struct definitions
  inspect(result.contains("pub struct "), content="true")
  inspect(result.contains("pub fn "), content="true")
}

test "golden: omit_unused_structs=true does not crash" {
  let req = make_users_request()
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: true, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  // Must at least produce valid output containing struct and function definitions
  inspect(result.contains("pub struct "), content="true")
  inspect(result.contains("pub fn "), content="true")
  // The Users struct IS referenced (via query columns), so it should still be included
  inspect(result.contains("pub struct Users"), content="true")
}

test "golden: multi-file output produces types.mbt and queries.mbt" {
  let req = make_users_request()
  let sources = generate_sources(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: [], nullable_overrides: [] })
  inspect(sources.length(), content="2")
  let types_file = sources[0]
  let queries_file = sources[1]
  inspect(types_file.0, content="types.mbt")
  inspect(queries_file.0, content="queries.mbt")
  // types.mbt contains struct definitions and decode functions
  inspect(types_file.1.contains("pub struct Users"), content="true")
  inspect(types_file.1.contains("Users::decode"), content="true")
  inspect(types_file.1.contains("pub enum UserRole"), content="true")
  // queries.mbt contains query functions
  inspect(queries_file.1.contains("pub fn query_list_users"), content="true")
  inspect(queries_file.1.contains("pub fn query_get_user"), content="true")
  inspect(queries_file.1.contains("pub fn query_delete_user"), content="true")
  // types.mbt does NOT contain query functions
  inspect(types_file.1.contains("pub fn query_"), content="false")
  // queries.mbt does NOT contain struct definitions
  inspect(queries_file.1.contains("pub struct "), content="false")
  // ::decode appears in query function bodies (e.g. ListUsersRow::decode(row))
  // but NOT as top-level pub fn declarations
  inspect(queries_file.1.contains("pub fn Users::decode"), content="false")
  inspect(queries_file.1.contains("pub fn ListUsersRow::decode"), content="false")
  // Both files have the import statement
  inspect(types_file.1.contains("import \"Mairzzcllo/moonbit_sqlc_plugin/runtime\""), content="true")
  inspect(queries_file.1.contains("import \"Mairzzcllo/moonbit_sqlc_plugin/runtime\""), content="true")
  // Both files have the package declaration
  inspect(types_file.1.contains("package testdb"), content="true")
  inspect(queries_file.1.contains("package testdb"), content="true")
}

test "golden: column_overrides and nullable_overrides affect Users struct" {
  let req = make_users_request()
  let col_overrides: Array[ColumnOverride] = [{ table: "users", column: "id", moonbit_type: "String" }]
  let null_overrides: Array[String] = ["int4"]
  let result = generate_source(req, { package_name: "testdb", overrides: [], emit_json_tags: false, emit_db_tags: false, renames: [], emit_sql_as_comment: false, omit_unused_structs: false, emit_empty_slices: false, initialisms: "", json_tags_case_style: "snake", query_parameter_limit: 0, emit_exact_table_names: false, emit_methods_with_db_argument: false, column_overrides: col_overrides, nullable_overrides: null_overrides })
  // Column override changes id to String, nullable override wraps it in Option
  inspect(result.contains("id: Option[String]"), content="true")
  // name is text, not_null, not affected by any override
  inspect(result.contains("name: String"), content="true")
  // email is text, nullable, not affected by any override
  inspect(result.contains("email: Option[String]"), content="true")
  // Query result types use nullable_override (int4 becomes Option)
  inspect(result.contains("id: Option[Int64]"), content="true")
}
