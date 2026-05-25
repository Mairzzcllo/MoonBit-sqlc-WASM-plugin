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

/// Map an internal type to a Value constructor name.
fn type_to_value_constructor(ir_type: InternalType) -> String {
  let name = match ir_type {
    Named(s) => s
    Arr(_) => return "String"
  }
  match name {
    "int4" | "int8" | "int2" | "integer" | "bigint" | "smallint" | "serial" | "bigserial" | "smallserial" | "int" => "Int64"
    "float4" | "float8" | "real" | "double" => "Double"
    "numeric" | "decimal" => "String"
    "bool" | "boolean" => "Bool"
    "bytea" => "Bytes"
    "json" | "jsonb" => "JsonValue"
    "date" => "Date"
    "timestamp" | "timestamptz" | "time" | "timetz" => "DateTime"
    _ => "String"
  }
}

/// Build a single Value constructor expression for a parameter.
fn param_to_value_expr(p: InternalParameter) -> Expr {
  let ctor_name = type_to_value_constructor(p.ty)
  if p.not_null {
    Call(ctor_name, [Ident(p.name)])
  } else {
    Match(Ident(p.name), [
      ("None", Ident("Null")),
      ("Some(" + p.name + ")", Call(ctor_name, [Ident(p.name)])),
    ])
  }
}

/// Build the Array[Value] params expression from query parameters.
fn build_params_expr(params: Array[InternalParameter]) -> Expr {
  let value_exprs = params.map(param_to_value_expr)
  ArrLit(value_exprs)
}

/// Build the return TypeExpr for a query based on its cardinality and result type.
fn build_return_ty(cmd: QueryCardinality, result_type: String) -> TypeExpr {
  match cmd {
    OneRow => Parameterized("Result", [Named(result_type), Named("DBError")])
    ManyRows => Parameterized("Result", [Parameterized("Array", [Named(result_type)]), Named("DBError")])
    ExecResult | ExecCount => Parameterized("Result", [Named("Int64"), Named("DBError")])
  }
}

/// Build the function body expressions for a query.
fn build_body(query: InternalQuery, result_type: String, conn_name: String) -> Array[Expr] {
  let sql_let = Let("sql", StrLit(query.text))
  let params_expr = build_params_expr(query.params)
  let params_let = Let("params", params_expr)
  match query.cmd {
    OneRow => [
      sql_let,
      params_let,
      Match(Call(conn_name + ".query_row", [Ident("sql"), Ident("params")]), [
        ("Ok(row)", Call(result_type + "::decode", [Ident("row")])),
        ("Err(e)", Call("Err", [Ident("e")])),
      ]),
    ]
    ManyRows => [
      sql_let,
      params_let,
      Match(Call(conn_name + ".query", [Ident("sql"), Ident("params")]), [
        ("Ok(iter)", Match(Call("iter.collect", []), [
          ("Ok(rows)", Block([
            Let("result", ArrLit([])),
            ForLoop("row", Ident("rows"), [
              Match(Call(result_type + "::decode", [Ident("row")]), [
                ("Ok(v)", Call("result.push", [Ident("v")])),
                ("Err(e)", Return(Call("Err", [Ident("e")]))),
              ]),
            ]),
            Call("Ok", [Ident("result")]),
          ])),
          ("Err(e)", Call("Err", [Ident("e")])),
        ])),
        ("Err(e)", Call("Err", [Ident("e")])),
      ]),
    ]
    ExecResult => [sql_let, params_let, Call(conn_name + ".exec", [Ident("sql"), Ident("params")])]
    ExecCount => [sql_let, params_let, Call(conn_name + ".execrows", [Ident("sql"), Ident("params")])]
  }
}

/// Convert PascalCase or camelCase to snake_case.
/// Handles: "GetUser" → "get_user", "getUser" → "get_user", "list_users" → "list_users"
fn to_snake_case(s: String) -> String {
  let mut result = ""
  let mut i = 0
  while i < s.length() {
    if s[i] >= 'A' && s[i] <= 'Z' {
      if i > 0 {
        if s[i - 1] >= 'a' && s[i - 1] <= 'z' {
          result = result + "_"
        } else if i + 1 < s.length() && s[i + 1] >= 'a' && s[i + 1] <= 'z' {
          result = result + "_"
        }
      }
    }
    result = result + s[i : i + 1].to_owned()
    i = i + 1
  }
  result.to_lower()
}

/// Generate a single query function FnDef.
pub fn generate_query_fn(query: InternalQuery, conn_name: String, conn_ty: TypeExpr) -> FnDef {
  let fn_name = "query_" + to_snake_case(query.name)
  let result_type = get_result_type_name(query)
  // First param is connection (db: DB or tx: Transaction)
  let conn_param: ParamDef = { name: conn_name, ty: conn_ty }
  // Convert IR params to AST params
  let query_params = query.params.map(param_to_param_def)
  let all_params = [conn_param] + query_params
  // Return type
  let return_ty = build_return_ty(query.cmd, result_type)
  // Body
  let body = build_body(query, result_type, conn_name)
  // Doc comment
  let doc = if query.comments.length() > 0 { Some(query.comments[0]) } else { None }
  { name: fn_name, params: all_params, return_ty: return_ty, body: body, doc: doc, is_pub: true }
}

/// Generate all query function TopLevel items from IR queries.
/// Generates two overloads for each query: one accepting DB, one accepting Transaction.
pub fn generate_query_fns(queries: Array[InternalQuery]) -> Array[TopLevel] {
  let items: Array[TopLevel] = []
  for q in queries {
    items.push(Fn(generate_query_fn(q, "db", Named("DB"))))
    items.push(Fn(generate_query_fn(q, "tx", Named("Transaction"))))
  }
  items
}

// === Tests ===

test "get_result_type_name: basic" {
  let q: InternalQuery = {
    name: "get_user", text: "", cmd: OneRow, raw_cmd: One,
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

test "build_return_ty: OneRow returns Result[T, DBError]" {
  let t = build_return_ty(OneRow, "User")
  inspect(t, content="Parameterized(\"Result\", [Named(\"User\"), Named(\"DBError\")])")
}

test "build_return_ty: ManyRows returns Result[Array[T], DBError]" {
  let t = build_return_ty(ManyRows, "User")
  inspect(t, content="Parameterized(\"Result\", [Parameterized(\"Array\", [Named(\"User\")]), Named(\"DBError\")])")
}

test "build_return_ty: ExecResult returns Result[Int64, DBError]" {
  let t = build_return_ty(ExecResult, "User")
  inspect(t, content="Parameterized(\"Result\", [Named(\"Int64\"), Named(\"DBError\")])")
}

test "build_return_ty: ExecCount returns Result[Int64, DBError]" {
  let t = build_return_ty(ExecCount, "User")
  inspect(t, content="Parameterized(\"Result\", [Named(\"Int64\"), Named(\"DBError\")])")
}

test "generate_query_fn: :one query has db param and result return" {
  let params: Array[InternalParameter] = [
    { number: 1, name: "id", ty: Named("int4"), not_null: true },
  ]
  let q: InternalQuery = {
    name: "get_user", text: "SELECT * FROM users WHERE id = $1", cmd: OneRow, raw_cmd: One,
    params: params,
    result_shape: (None: InternalResultShape),
    comments: ["Get a user by ID"], filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"))
  inspect(fn_def.name, content="query_get_user")
  inspect(fn_def.params.length(), content="2")
  inspect(fn_def.params[0].name, content="db")
  inspect(fn_def.params[0].ty, content="Named(\"DB\")")
  inspect(fn_def.params[1].name, content="id")
  inspect(fn_def.params[1].ty, content="Named(\"Int\")")
  inspect(fn_def.return_ty, content="Parameterized(\"Result\", [Named(\"GetUserRow\"), Named(\"DBError\")])")
  debug_inspect(fn_def.doc, content="Some(\"Get a user by ID\")")
  inspect(fn_def.is_pub, content="true")
}

test "generate_query_fn: :many query has no params" {
  let q: InternalQuery = {
    name: "list_users", text: "SELECT * FROM users", cmd: ManyRows, raw_cmd: Many,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"))
  inspect(fn_def.name, content="query_list_users")
  inspect(fn_def.params.length(), content="1")
  inspect(fn_def.params[0].name, content="db")
  inspect(fn_def.return_ty, content="Parameterized(\"Result\", [Parameterized(\"Array\", [Named(\"ListUsersRow\")]), Named(\"DBError\")])")
}

test "generate_query_fn: :exec query returns Result[Int64, DBError]" {
  let q: InternalQuery = {
    name: "delete_user", text: "DELETE FROM users WHERE id = $1", cmd: ExecResult, raw_cmd: Exec,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"))
  inspect(fn_def.name, content="query_delete_user")
  inspect(fn_def.return_ty, content="Parameterized(\"Result\", [Named(\"Int64\"), Named(\"DBError\")])")
  inspect(fn_def.body.length(), content="3")
  let sql_text = match fn_def.body[0] {
    Let(_, StrLit(s)) => s
    _ => ""
  }
  inspect(sql_text, content="DELETE FROM users WHERE id = $1")
}

test "generate_query_fn: :execrows query returns Result[Int64, DBError]" {
  let q: InternalQuery = {
    name: "update_user_email", text: "UPDATE users SET email = $1 WHERE id = $2", cmd: ExecCount, raw_cmd: ExecRows,
    params: [
      { number: 1, name: "email", ty: Named("text"), not_null: true },
      { number: 2, name: "id", ty: Named("int4"), not_null: true },
    ],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"))
  inspect(fn_def.return_ty, content="Parameterized(\"Result\", [Named(\"Int64\"), Named(\"DBError\")])")
  inspect(fn_def.params.length(), content="3")
  inspect(fn_def.params[1].name, content="email")
  inspect(fn_def.params[2].name, content="id")
}

test "generate_query_fns: multiple queries" {
  let q1: InternalQuery = {
    name: "q1", text: "S1", cmd: ManyRows, raw_cmd: Many,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let q2: InternalQuery = {
    name: "q2", text: "S2", cmd: ExecResult, raw_cmd: Exec,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q1, q2])
  inspect(items.length(), content="4")
  let name1 = match items[0] { Fn(f) => f.name; _ => "" }
  let name2 = match items[1] { Fn(f) => f.name; _ => "" }
  inspect(name1, content="query_q1")
  inspect(name2, content="query_q1")
}

test "generate_query_fns: produces two items per query (DB + Transaction)" {
  let q: InternalQuery = {
    name: "test", text: "SELECT 1", cmd: ManyRows, raw_cmd: Many,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q])
  inspect(items.length(), content="2")
  // First is db: DB
  let param0_name = match items[0] { Fn(f) => f.params[0].name; _ => "" }
  let param0_ty = match items[0] { Fn(f) => f.params[0].ty; _ => Named("") }
  inspect(param0_name, content="db")
  inspect(param0_ty, content="Named(\"DB\")")
  // Second is tx: Transaction
  let param1_name = match items[1] { Fn(f) => f.params[0].name; _ => "" }
  let param1_ty = match items[1] { Fn(f) => f.params[0].ty; _ => Named("") }
  inspect(param1_name, content="tx")
  inspect(param1_ty, content="Named(\"Transaction\")")
}

test "generate_query_fn: transaction overload uses tx.method calls" {
  let q: InternalQuery = {
    name: "get", text: "SELECT 1", cmd: OneRow, raw_cmd: One,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let fn_def = generate_query_fn(q, "tx", Named("Transaction"))
  inspect(fn_def.params[0].name, content="tx")
  inspect(fn_def.params[0].ty, content="Named(\"Transaction\")")
  // Verify body uses tx.query_row
  let call_name = match fn_def.body[2] {
    Match(Call(name, _), _) => name
    _ => ""
  }
  inspect(call_name, content="tx.query_row")
}

test "build_body: :many body uses db.query + iter.collect + for loop" {
  let q: InternalQuery = {
    name: "list", text: "SELECT 1", cmd: ManyRows, raw_cmd: Many,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "ListRow", "db")
  inspect(body.length(), content="3")
  // First: let sql
  // Second: let params = []
  let params_name = match body[1] { Let(name, _) => name; _ => "" }
  inspect(params_name, content="params")
  // Third: match db.query(sql, params) { ... }
  let is_match = match body[2] {
    Match(_, _) => true
    _ => false
  }
  inspect(is_match, content="true")
}

test "build_body: :one body uses match db.query_row + decode" {
  let q: InternalQuery = {
    name: "get", text: "SELECT 1 WHERE id = $1", cmd: OneRow, raw_cmd: One,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "GetRow", "db")
  inspect(body.length(), content="3")
  // First: let sql
  // Second: let params = [Int64(id)]
  let params_name = match body[1] { Let(name, _) => name; _ => "" }
  inspect(params_name, content="params")
  // Third: match db.query_row(sql, params) { ... }
  let is_match = match body[2] {
    Match(_, _) => true
    _ => false
  }
  inspect(is_match, content="true")
}

test "build_body: :execrows uses db.execrows with params" {
  let q: InternalQuery = {
    name: "del", text: "DELETE FROM t", cmd: ExecCount, raw_cmd: ExecRows,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "DelRow", "db")
  let call_name = match body[2] { Call(name, _) => name; _ => "" }
  inspect(call_name, content="db.execrows")
}

test "build_body: conn_name parameterizes the method receiver" {
  let q: InternalQuery = {
    name: "get", text: "SELECT 1", cmd: OneRow, raw_cmd: One,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body_with_db = build_body(q, "Row", "db")
  let body_with_tx = build_body(q, "Row", "tx")
  let call_db = match body_with_db[2] {
    Match(Call(name, _), _) => name
    _ => ""
  }
  let call_tx = match body_with_tx[2] {
    Match(Call(name, _), _) => name
    _ => ""
  }
  inspect(call_db, content="db.query_row")
  inspect(call_tx, content="tx.query_row")
}

test "generate_query_fn: full function emission matches expected pattern" {
  let q: InternalQuery = {
    name: "get_user", text: "SELECT id, name FROM users WHERE id = $1", cmd: OneRow, raw_cmd: One,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: ["Get a user by ID"], filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"))
  let sf: SourceFile = { items: [Fn(fn_def)] }
  let result = emit_source_file(sf)
  inspect(result.contains("match db.query_row"), content="true")
  inspect(result.contains("Err(e) => Err(e)"), content="true")
}

test "to_snake_case: PascalCase GetUser converts to get_user" {
  let result = to_snake_case("GetUser")
  inspect(result, content="get_user")
}

test "to_snake_case: camelCase getUser converts to get_user" {
  let result = to_snake_case("getUser")
  inspect(result, content="get_user")
}

test "to_snake_case: already snake_case unchanged" {
  let result = to_snake_case("get_user")
  inspect(result, content="get_user")
}

test "to_snake_case: PascalCase with acronym GetUserByID" {
  let result = to_snake_case("GetUserByID")
  inspect(result, content="get_user_by_id")
}

test "generate_query_fn: PascalCase query name converted to snake_case fn name" {
  let params: Array[InternalParameter] = [
    { number: 1, name: "id", ty: Named("int4"), not_null: true },
  ]
  let q: InternalQuery = {
    name: "GetUser", text: "SELECT * FROM users WHERE id = $1", cmd: OneRow, raw_cmd: One,
    params: params,
    result_shape: (None: InternalResultShape),
    comments: ["Get a user by ID"], filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"))
  inspect(fn_def.name, content="query_get_user")
}
