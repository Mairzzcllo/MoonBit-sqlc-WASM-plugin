///|
/// Query Code Generator — P0-009.
/// Generates MoonBit query function definitions from IR queries.
/// Produces FnDef AST nodes with db: DB first param, typed params, and SQL body.
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

/// Get the result struct type name for a query.
fn get_result_type_name(query: InternalQuery) -> String {
  snake_to_pascal(query.name) + "Row"
}

/// Convert an InternalParameter to a ParamDef, mapping the type through the type layer.
fn param_to_param_def(p: InternalParameter) -> ParamDef {
  let moon_type = map_internal_type_nullable(p.ty, p.not_null)
  { name: p.name, ty: moon_type }
}

/// Build the return TypeExpr for a query based on its cardinality and result type.
fn build_return_ty(cmd: QueryCardinality, result_type: String) -> TypeExpr {
  match cmd {
    OneRow => Parameterized("Option", [Named(result_type)])
    ManyRows => Parameterized("Array", [Named(result_type)])
    ExecResult => Named("Int")
    ExecCount => Named("Int64")
  }
}

/// Build the function body expressions for a query.
fn build_body(query: InternalQuery, result_type: String) -> Array[Expr] {
  let sql_let = Let("sql", StrLit(query.text))
  let db_call = match query.cmd {
    OneRow | ManyRows => Call("db.query", [Ident("sql")])
    ExecResult => Call("db.exec", [Ident("sql")])
    ExecCount => Call("db.execrows", [Ident("sql")])
  }
  // Wrap db call in let _ = to discard the Int/Int64 return value
  let discard = Let("_", db_call)
  let return_val = match query.cmd {
    OneRow => Ident("None")
    ManyRows => ArrLit([])
    ExecResult | ExecCount => db_call
  }
  match query.cmd {
    ExecResult | ExecCount => [sql_let, db_call]
    OneRow | ManyRows => [sql_let, discard, return_val]
  }
}

/// Generate a single query function FnDef.
pub fn generate_query_fn(query: InternalQuery) -> FnDef {
  let fn_name = "query_" + query.name
  let result_type = get_result_type_name(query)
  // First param is always db: DB
  let db_param: ParamDef = { name: "db", ty: Named("DB") }
  // Convert IR params to AST params
  let query_params = query.params.map(param_to_param_def)
  let all_params = [db_param] + query_params
  // Return type
  let return_ty = build_return_ty(query.cmd, result_type)
  // Body
  let body = build_body(query, result_type)
  // Doc comment
  let doc = if query.comments.length() > 0 { Some(query.comments[0]) } else { None }
  { name: fn_name, params: all_params, return_ty: return_ty, body: body, doc: doc, is_pub: true }
}

/// Generate all query function TopLevel items from IR queries.
pub fn generate_query_fns(queries: Array[InternalQuery]) -> Array[TopLevel] {
  queries.map(fn(q) { Fn(generate_query_fn(q)) })
}

// === Tests ===

test "get_result_type_name: basic" {
  let q: InternalQuery = {
    name: "get_user", text: "", cmd: OneRow,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let name = get_result_type_name(q)
  inspect(name, content="GetUserRow")
}

test "param_to_param_def: not_null param" {
  let p: InternalParameter = { number: 1, name: "id", ty: Named("int4"), not_null: true }
  let pd = param_to_param_def(p)
  inspect(pd.name, content="id")
  inspect(pd.ty, content="Named(\"Int\")")
}

test "param_to_param_def: nullable param" {
  let p: InternalParameter = { number: 1, name: "email", ty: Named("text"), not_null: false }
  let pd = param_to_param_def(p)
  inspect(pd.ty, content="Option(Named(\"String\"))")
}

test "build_return_ty: OneRow returns Option[T]" {
  let t = build_return_ty(OneRow, "User")
  inspect(t, content="Parameterized(\"Option\", [Named(\"User\")])")
}

test "build_return_ty: ManyRows returns Array[T]" {
  let t = build_return_ty(ManyRows, "User")
  inspect(t, content="Parameterized(\"Array\", [Named(\"User\")])")
}

test "build_return_ty: ExecResult returns Int" {
  let t = build_return_ty(ExecResult, "User")
  inspect(t, content="Named(\"Int\")")
}

test "build_return_ty: ExecCount returns Int64" {
  let t = build_return_ty(ExecCount, "User")
  inspect(t, content="Named(\"Int64\")")
}

test "generate_query_fn: :one query has db param and option return" {
  let params: Array[InternalParameter] = [
    { number: 1, name: "id", ty: Named("int4"), not_null: true },
  ]
  let q: InternalQuery = {
    name: "get_user", text: "SELECT * FROM users WHERE id = $1", cmd: OneRow,
    params: params,
    result_shape: (None: InternalResultShape),
    comments: ["Get a user by ID"], filename: "q.sql",
  }
  let fn_def = generate_query_fn(q)
  inspect(fn_def.name, content="query_get_user")
  inspect(fn_def.params.length(), content="2")
  inspect(fn_def.params[0].name, content="db")
  inspect(fn_def.params[0].ty, content="Named(\"DB\")")
  inspect(fn_def.params[1].name, content="id")
  inspect(fn_def.params[1].ty, content="Named(\"Int\")")
  inspect(fn_def.return_ty, content="Parameterized(\"Option\", [Named(\"GetUserRow\")])")
  inspect(fn_def.doc, content="Some(Get a user by ID)")
  inspect(fn_def.is_pub, content="true")
}

test "generate_query_fn: :many query has no params" {
  let q: InternalQuery = {
    name: "list_users", text: "SELECT * FROM users", cmd: ManyRows,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "q.sql",
  }
  let fn_def = generate_query_fn(q)
  inspect(fn_def.name, content="query_list_users")
  inspect(fn_def.params.length(), content="1")
  inspect(fn_def.params[0].name, content="db")
  inspect(fn_def.return_ty, content="Parameterized(\"Array\", [Named(\"ListUsersRow\")])")
}

test "generate_query_fn: :exec query returns Int" {
  let q: InternalQuery = {
    name: "delete_user", text: "DELETE FROM users WHERE id = $1", cmd: ExecResult,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "q.sql",
  }
  let fn_def = generate_query_fn(q)
  inspect(fn_def.name, content="query_delete_user")
  inspect(fn_def.return_ty, content="Named(\"Int\")")
  inspect(fn_def.body.length(), content="2")
  // First body expr is let sql
  let sql_text = match fn_def.body[0] {
    Let(_, StrLit(s)) => s
    _ => ""
  }
  inspect(sql_text, content="DELETE FROM users WHERE id = $1")
}

test "generate_query_fn: :execrows query returns Int64" {
  let q: InternalQuery = {
    name: "update_user_email", text: "UPDATE users SET email = $1 WHERE id = $2", cmd: ExecCount,
    params: [
      { number: 1, name: "email", ty: Named("text"), not_null: true },
      { number: 2, name: "id", ty: Named("int4"), not_null: true },
    ],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "q.sql",
  }
  let fn_def = generate_query_fn(q)
  inspect(fn_def.return_ty, content="Named(\"Int64\")")
  inspect(fn_def.params.length(), content="3")
  inspect(fn_def.params[1].name, content="email")
  inspect(fn_def.params[2].name, content="id")
}

test "generate_query_fns: multiple queries" {
  let q1: InternalQuery = {
    name: "q1", text: "S1", cmd: ManyRows,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let q2: InternalQuery = {
    name: "q2", text: "S2", cmd: ExecResult,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q1, q2])
  inspect(items.length(), content="2")
  let name1 = match items[0] { Fn(f) => f.name; _ => "" }
  let name2 = match items[1] { Fn(f) => f.name; _ => "" }
  inspect(name1, content="query_q1")
  inspect(name2, content="query_q2")
}

test "build_body: :many body uses db.query" {
  let q: InternalQuery = {
    name: "list", text: "SELECT 1", cmd: ManyRows,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "ListRow")
  inspect(body.length(), content="3")
  // Second expression is let _ = db.query(sql)
  let discard_name = match body[1] { Let(name, _) => name; _ => "" }
  inspect(discard_name, content="_")
  // Third expression is the return value (empty array)
  let is_arr = match body[2] { ArrLit(_) => true; _ => false }
  inspect(is_arr, content="true")
}

test "build_body: :one body has 3 items ending with None" {
  let q: InternalQuery = {
    name: "get", text: "SELECT 1 WHERE id = $1", cmd: OneRow,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "GetRow")
  inspect(body.length(), content="3")
  // Second is discard
  let discard_name = match body[1] { Let(name, _) => name; _ => "" }
  inspect(discard_name, content="_")
  // Third expression is None
  let is_none = match body[2] { Ident(s) => s == "None"; _ => false }
  inspect(is_none, content="true")
}

test "build_body: :execrows uses db.execrows" {
  let q: InternalQuery = {
    name: "del", text: "DELETE FROM t", cmd: ExecCount,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "DelRow")
  let call_name = match body[1] { Call(name, _) => name; _ => "" }
  inspect(call_name, content="db.execrows")
}

test "generate_query_fn: full function emission matches expected pattern" {
  let q: InternalQuery = {
    name: "get_user", text: "SELECT id, name FROM users WHERE id = $1", cmd: OneRow,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: ["Get a user by ID"], filename: "q.sql",
  }
  let fn_def = generate_query_fn(q)
  let sf: SourceFile = { items: [Fn(fn_def)] }
  let result = emit_source_file(sf)
  // Verify the emitted code matches expected output
  inspect(result, content="/// Get a user by ID\npub fn query_get_user(db: DB, id: Int) -> Option[GetUserRow] {\n  let sql = \"SELECT id, name FROM users WHERE id = \\$1\"\n  let _ = db.query(sql)\n  None\n}\n")
}
