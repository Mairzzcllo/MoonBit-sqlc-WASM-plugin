///|
/// Golden Tests — P0-011.
/// End-to-end pipeline verification with fixed inputs.

const GOLDEN_USERS: String = "/// users table\npub struct Users {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\npub enum UserRole {\n  Admin\n  Editor\n  Viewer\n}\n\n/// List all users\npub struct ListUsersRow {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// Get user by ID\npub struct GetUserRow {\n  id: Int\n  name: String\n  /// user email address\n  email: Option[String]\n}\n\n/// List all users\npub fn query_list_users(db: DB) -> Array[ListUsersRow] {\n  let sql = \"SELECT id, name, email FROM users\"\n  let _ = db.exec(sql)\n  []\n}\n\n/// Get user by ID\npub fn query_get_user(db: DB, id: Int) -> Option[GetUserRow] {\n  let sql = \"SELECT id, name, email FROM users WHERE id = $1\"\n  let _ = db.exec(sql)\n  None\n}\n\npub fn query_delete_user(db: DB, id: Int) -> Int {\n  let sql = \"DELETE FROM users WHERE id = $1\"\n  db.exec(sql)\n}\n"

test "golden: full pipeline matches expected output" {
  let req = make_users_request()
  let result = generate_source(req)
  inspect(result, content=GOLDEN_USERS)
}

test "golden: deterministic output" {
  let req = make_users_request()
  let result1 = generate_source(req)
  let result2 = generate_source(req)
  inspect(result1, content=result2)
}
