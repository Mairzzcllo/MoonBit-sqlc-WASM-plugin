///|
/// WASM compilation tests — P0-026.
/// Verifies the generated MoonBit code compiles with moonc without errors.

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
  let db: DB = { exec_fn: fn(_sql) { 0 }, execrows_fn: fn(_sql) { 0L } }
  let count = query_delete_user(db, 42)
  inspect(count, content="0")
}

test "wasm-compile: UserRole enum variants accessible" {
  let role: UserRole = Admin
  inspect(match role { Admin => "admin"; _ => "other" }, content="admin")
}

test "wasm-compile: query_list_users accepts DB" {
  let db: DB = { exec_fn: fn(_sql) { 0 }, execrows_fn: fn(_sql) { 0L } }
  let result: Array[ListUsersRow] = query_list_users(db)
  inspect(result.length(), content="0")
}
