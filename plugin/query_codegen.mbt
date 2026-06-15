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
fn get_result_type_name(query: InternalQuery, initialisms: Array[String]) -> String {
  escape_keyword(snake_to_pascal(query.name, initialisms) + "Row")
}

/// Convert an InternalParameter to a ParamDef, mapping the type through the type layer.
fn param_to_param_def(p: InternalParameter, overrides: Array[(String, String)], nullable_overrides: Array[String]) -> ParamDef {
  let moon_type = map_internal_type_nullable(p.ty, p.not_null, overrides, nullable_overrides, [])
  { name: escape_keyword(p.name), ty: moon_type }
}

/// Build a single Value constructor expression for a parameter.
fn param_to_value_expr(p: InternalParameter, overrides: Array[(String, String)]) -> Expr {
  let ctor_name = type_to_value_constructor(p.ty, overrides)
  let escaped_name = escape_keyword(p.name)
  if p.not_null {
    Call(ctor_name, [Ident(escaped_name)])
  } else {
    Match(Ident(escaped_name), [
      ("None", Ident("Null")),
      ("Some(" + escaped_name + ")", Call(ctor_name, [Ident(escaped_name)])),
    ])
  }
}

/// Build the Array[Value] params expression from query parameters.
fn build_params_expr(params: Array[InternalParameter], overrides: Array[(String, String)], _nullable_overrides: Array[String]) -> Expr {
  let value_exprs = params.map(fn(p) { param_to_value_expr(p, overrides) })
  ArrLit(value_exprs)
}

/// Build the return TypeExpr for a query based on its cardinality, result type,
/// and result shape. ExecResult/ExecCount with Rows (e.g. RETURNING *) produce
/// Result[T, DBError] (same as OneRow), while without rows produce Result[Int64, DBError].
fn build_return_ty(cmd: QueryCardinality, result_type: String, result_shape: InternalResultShape) -> TypeExpr {
  match cmd {
    OneRow => Parameterized("Result", [Named(result_type), Named("DBError")])
    ManyRows => Parameterized("Result", [Parameterized("Array", [Named(result_type)]), Named("DBError")])
    ExecResult => match result_shape {
      Rows(_) => Parameterized("Result", [Named(result_type), Named("DBError")])
      None => Parameterized("Result", [Named("ExecResult"), Named("DBError")])
    }
    ExecCount => match result_shape {
      Rows(_) => Parameterized("Result", [Named(result_type), Named("DBError")])
      None => Parameterized("Result", [Named("Int64"), Named("DBError")])
    }
  }
}

/// Build the function body expressions for a query.
/// ExecResult/ExecCount with Rows (e.g. RETURNING *) generate decode paths
/// instead of exec/execrows calls.
/// When emit_empty_slices is true, :many queries return an empty array
/// instead of an error when no rows are returned.
fn build_body(query: InternalQuery, result_type: String, conn_name: String, result_shape: InternalResultShape, overrides: Array[(String, String)], nullable_overrides: Array[String], emit_empty_slices: Bool) -> Array[Expr] {
  let sql_let = Let("sql", StrLit(query.text))
  let params_expr = build_params_expr(query.params, overrides, nullable_overrides)
  let params_let = Let("params", params_expr)
  match query.cmd {
    OneRow => [
      sql_let,
      params_let,
      Match(Call(conn_name + ".query", [Ident("sql"), Ident("params")]), [
        ("Ok(rows)", Match(Call("rows.collect_limited", [IntLit(2)]), [
          ("Ok(collected)", Match(Call("collected.length", []), [
            ("0", Call("Err", [Ident("NoRows")])),
            ("1", Call(result_type + "::decode", [Index(Ident("collected"), IntLit(0))])),
            ("_", Call("Err", [Call("TooManyRows", [Call("collected.length", []), Ident("sql")])])),
          ])),
          ("Err(TooManyRows(n, _))", Call("Err", [Call("TooManyRows", [Ident("n"), Ident("sql")])])),
          ("Err(e)", Call("Err", [Ident("e")])),
        ])),
        ("Err(e)", Call("Err", [Ident("e")])),
      ]),
    ]
    ManyRows => {
      let ok_arm = ("Ok(rows)", Block([
        Let("result", ArrLit([])),
        ForLoop("row", Ident("rows"), [
          Match(Call(result_type + "::decode", [Ident("row")]), [
            ("Ok(v)", Call("result.push", [Ident("v")])),
            ("Err(e)", Return(Call("Err", [Ident("e")]))),
          ]),
        ]),
        Call("Ok", [Ident("result")]),
      ]))
      let err_arm = ("Err(e)", Call("Err", [Ident("e")]))
      let collect_arms: Array[(String, Expr)] = if emit_empty_slices {
        [ok_arm, ("Err(NoRows)", Call("Ok", [ArrLit([])])), err_arm]
      } else {
        [ok_arm, err_arm]
      }
      [
        sql_let,
        params_let,
        Match(Call(conn_name + ".query", [Ident("sql"), Ident("params")]), [
          ("Ok(iter)", Match(Call("iter.collect", []), collect_arms)),
          ("Err(e)", Call("Err", [Ident("e")])),
        ]),
      ]
    }
    ExecResult => match result_shape {
      // RETURNING * — use query_row + decode (single row)
      Rows(_) => [
        sql_let,
        params_let,
        Match(Call(conn_name + ".query_row", [Ident("sql"), Ident("params")]), [
          ("Ok(row)", Call(result_type + "::decode", [Ident("row")])),
          ("Err(e)", Call("Err", [Ident("e")])),
        ]),
      ]
      None => {
        let method_name = match query.raw_cmd {
          CopyFrom => ".copyfrom"
          Batch => ".batch"
          ExecLastId => ".execlastid"
          _ => ".exec"
        }
        let conn_call = Call(conn_name + method_name, [Ident("sql"), Ident("params")])
        let (zero_or_n, one_or_n) = match query.raw_cmd {
          ExecLastId => ("n", "1L")
          _ => ("0L", "n")
        }
        [
          sql_let,
          params_let,
          Match(conn_call, [
            ("Ok(n)", Call("Ok", [Call("ExecResult::new", [Ident(zero_or_n), Ident(one_or_n)])])),
            ("Err(e)", Call("Err", [Ident("e")])),
          ]),
        ]
      }
    }
    ExecCount => match result_shape {
      // RETURNING * — use query + collect + decode (multiple rows)
      Rows(_) => {
        let ok_arm = ("Ok(rows)", Block([
          Let("result", ArrLit([])),
          ForLoop("row", Ident("rows"), [
            Match(Call(result_type + "::decode", [Ident("row")]), [
              ("Ok(v)", Call("result.push", [Ident("v")])),
              ("Err(e)", Return(Call("Err", [Ident("e")]))),
            ]),
          ]),
          Call("Ok", [Ident("result")]),
        ]))
        let err_arm = ("Err(e)", Call("Err", [Ident("e")]))
        let collect_arms: Array[(String, Expr)] = if emit_empty_slices {
        [ok_arm, ("Err(NoRows)", Call("Ok", [ArrLit([])])), err_arm]
        } else {
          [ok_arm, err_arm]
        }
        [
          sql_let,
          params_let,
          Match(Call(conn_name + ".query", [Ident("sql"), Ident("params")]), [
            ("Ok(iter)", Match(Call("iter.collect", []), collect_arms)),
            ("Err(e)", Call("Err", [Ident("e")])),
          ]),
        ]
      }
      None => [sql_let, params_let, Call(conn_name + ".execrows", [Ident("sql"), Ident("params")])]
    }
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
/// emit_methods_with_db_argument is accepted for API compatibility with sqlc's other plugins.
/// MoonBit 0.1 always generates standalone functions with DB as first param (see generate_query_fns).
pub fn generate_query_fn(query: InternalQuery, conn_name: String, conn_ty: TypeExpr, overrides: Array[(String, String)], nullable_overrides: Array[String], emit_sql_as_comment: Bool, _emit_methods_with_db_argument: Bool, emit_empty_slices: Bool, initialisms: Array[String]) -> FnDef {
  let fn_name = "query_" + to_snake_case(query.name)
  let result_type = get_result_type_name(query, initialisms)
  // First param is connection (db: DB or tx: Transaction)
  let conn_param: ParamDef = { name: conn_name, ty: conn_ty }
  // Convert IR params to AST params
  let query_params = query.params.map(fn(p) { param_to_param_def(p, overrides, nullable_overrides) })
  let all_params = [conn_param] + query_params
  // Return type (respects RETURNING * for ExecResult/ExecCount)
  let return_ty = build_return_ty(query.cmd, result_type, query.result_shape)
  // Body (respects RETURNING * for ExecResult/ExecCount)
  let body = build_body(query, result_type, conn_name, query.result_shape, overrides, nullable_overrides, emit_empty_slices)
  // Doc comment — if emit_sql_as_comment is true, include SQL text in doc comment
  let doc = if query.comments.length() > 0 {
    let comment = query.comments[0]
    if emit_sql_as_comment {
      Some(comment + "\n\n" + query.text)
    } else {
      Some(comment)
    }
  } else {
    if emit_sql_as_comment {
      Some(query.text)
    } else {
      None
    }
  }
  { name: fn_name, params: all_params, return_ty: return_ty, body: body, doc: doc, is_pub: true }
}

/// Whether a raw QueryCmd is supported on the Transaction struct.
/// Transaction only has exec/execrows/query/query_row — no copyfrom/batch/execlastid.
fn supports_transaction(cmd: QueryCmd) -> Bool {
  match cmd {
    One | Many | Exec | ExecRows => true
    CopyFrom | Batch | ExecLastId => false
  }
}

/// Generate all query function TopLevel items from IR queries.
/// Always generates a `db: DB` overload. Only generates a `tx: Transaction` overload
/// for queries whose `raw_cmd` is supported by Transaction (One, Many, Exec, ExecRows).
///
/// emit_methods_with_db_argument:
///   The current codegen strategy always produces standalone functions with `db: DB` as
///   the first parameter (e.g., `pub fn query_list_users(db: DB) -> ...`). This is the
///   only feasible approach in MoonBit 0.1 since trait objects and method dispatch are
///   not fully supported. Both `true` and `false` produce identical output — standalone
///   functions with a DB argument. A future version might use `fn DB::query_list_users()`
///   method receiver syntax when MoonBit supports it, at which point `false` could mean
///   "emit as method on DB type". For now, the option is accepted for API compatibility
///   with sqlc's other plugins but is a no-op.
pub fn generate_query_fns(queries: Array[InternalQuery], overrides: Array[(String, String)], nullable_overrides: Array[String], emit_sql_as_comment: Bool, emit_methods_with_db_argument: Bool, emit_empty_slices: Bool, initialisms: Array[String]) -> Array[TopLevel] {
  let items: Array[TopLevel] = []
  for q in queries {
    items.push(Fn(generate_query_fn(q, "db", Named("DB"), overrides, nullable_overrides, emit_sql_as_comment, emit_methods_with_db_argument, emit_empty_slices, initialisms)))
    if supports_transaction(q.raw_cmd) {
      items.push(Fn(generate_query_fn(q, "tx", Named("Transaction"), overrides, nullable_overrides, emit_sql_as_comment, emit_methods_with_db_argument, emit_empty_slices, initialisms)))
    }
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
  let name = get_result_type_name(q, [])
  inspect(name, content="GetUserRow")
}

test "param_to_param_def: not_null param" {
  let p: InternalParameter = { number: 1, name: "id", ty: Named("int4"), not_null: true }
  let pd = param_to_param_def(p, [], [])
  inspect(pd.name, content="id")
  inspect(pd.ty, content="Named(\"Int64\")")
}

test "param_to_param_def: nullable param" {
  let p: InternalParameter = { number: 1, name: "email", ty: Named("text"), not_null: false }
  let pd = param_to_param_def(p, [], [])
  inspect(pd.ty, content="Option(Named(\"String\"))")
}

test "build_return_ty: OneRow returns Result[T, DBError]" {
  let t = build_return_ty(OneRow, "User", None)
  inspect(t, content="Parameterized(\"Result\", [Named(\"User\"), Named(\"DBError\")])")
}

test "build_return_ty: ManyRows returns Result[Array[T], DBError]" {
  let t = build_return_ty(ManyRows, "User", None)
  inspect(t, content="Parameterized(\"Result\", [Parameterized(\"Array\", [Named(\"User\")]), Named(\"DBError\")])")
}

test "build_return_ty: ExecResult returns Result[ExecResult, DBError]" {
  let t = build_return_ty(ExecResult, "User", None)
  inspect(t, content="Parameterized(\"Result\", [Named(\"ExecResult\"), Named(\"DBError\")])")
}

test "build_return_ty: ExecCount returns Result[Int64, DBError]" {
  let t = build_return_ty(ExecCount, "User", None)
  inspect(t, content="Parameterized(\"Result\", [Named(\"Int64\"), Named(\"DBError\")])")
}

test "build_return_ty: ExecResult with Rows returns Result[T, DBError]" {
  let t = build_return_ty(ExecResult, "CreateUserRow", (Rows(Array::make(0, { name: "", ty: Named(""), not_null: false, comment: "", rename_to: (None: Option[String]) })) : InternalResultShape))
  inspect(t, content="Parameterized(\"Result\", [Named(\"CreateUserRow\"), Named(\"DBError\")])")
}

test "build_return_ty: ExecCount with Rows returns Result[T, DBError]" {
  let t = build_return_ty(ExecCount, "UpdateUserRow", (Rows(Array::make(0, { name: "", ty: Named(""), not_null: false, comment: "", rename_to: (None: Option[String]) })) : InternalResultShape))
  inspect(t, content="Parameterized(\"Result\", [Named(\"UpdateUserRow\"), Named(\"DBError\")])")
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
  let fn_def = generate_query_fn(q, "db", Named("DB"), [], [], false, false, false, [])
  inspect(fn_def.name, content="query_get_user")
  inspect(fn_def.params.length(), content="2")
  inspect(fn_def.params[0].name, content="db")
  inspect(fn_def.params[0].ty, content="Named(\"DB\")")
  inspect(fn_def.params[1].name, content="id")
  inspect(fn_def.params[1].ty, content="Named(\"Int64\")")
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
  let fn_def = generate_query_fn(q, "db", Named("DB"), [], [], true, false, false, [])
  inspect(fn_def.name, content="query_list_users")
  inspect(fn_def.params.length(), content="1")
  inspect(fn_def.params[0].name, content="db")
  inspect(fn_def.return_ty, content="Parameterized(\"Result\", [Parameterized(\"Array\", [Named(\"ListUsersRow\")]), Named(\"DBError\")])")
}

test "generate_query_fn: :exec query returns Result[ExecResult, DBError]" {
  let q: InternalQuery = {
    name: "delete_user", text: "DELETE FROM users WHERE id = $1", cmd: ExecResult, raw_cmd: Exec,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"), [], [], true, false, false, [])
  inspect(fn_def.name, content="query_delete_user")
  inspect(fn_def.return_ty, content="Parameterized(\"Result\", [Named(\"ExecResult\"), Named(\"DBError\")])")
  inspect(fn_def.body.length(), content="3")
  let sql_text = match fn_def.body[0] {
    Let(_, StrLit(s)) => s
    _ => ""
  }
  inspect(sql_text, content="DELETE FROM users WHERE id = $1")
  // body[2] is now a Match wrapping the db.exec call
  let is_match = match fn_def.body[2] {
    Match(_, _) => true
    _ => false
  }
  inspect(is_match, content="true")
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
  let fn_def = generate_query_fn(q, "db", Named("DB"), [], [], true, false, false, [])
  inspect(fn_def.return_ty, content="Parameterized(\"Result\", [Named(\"Int64\"), Named(\"DBError\")])")
  inspect(fn_def.params.length(), content="3")
  inspect(fn_def.params[1].name, content="email")
  inspect(fn_def.params[2].name, content="id")
}

test "generate_query_fn: full function emission matches expected pattern" {
  let q: InternalQuery = {
    name: "get_user", text: "SELECT id, name FROM users WHERE id = $1", cmd: OneRow, raw_cmd: One,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: ["Get a user by ID"], filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"), [], [], true, false, false, [])
  let sf: SourceFile = { items: [Fn(fn_def)] }
  let result = emit_source_file(sf)
  // P0-062: :one queries now use db.query() + collect_limited(2) for TooManyRows detection
  inspect(result.contains("match db.query(sql, params)"), content="true")
  inspect(result.contains("match rows.collect_limited(2)"), content="true")
  inspect(result.contains("TooManyRows"), content="true")
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

test "build_body: CopyFrom raw_cmd uses conn.copyfrom" {
  let q: InternalQuery = {
    name: "copy_users", text: "COPY users FROM stdin", cmd: ExecResult, raw_cmd: CopyFrom,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "CopyUsersRow", "db", None, [], [], false)
  let call_name = match body[2] { Match(Call(name, _), _) => name; _ => "" }
  inspect(call_name, content="db.copyfrom")
}

test "build_body: Batch raw_cmd uses conn.batch" {
  let q: InternalQuery = {
    name: "batch_insert", text: "INSERT INTO t VALUES ($1)", cmd: ExecResult, raw_cmd: Batch,
    params: [{ number: 1, name: "val", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "BatchInsertRow", "db", None, [], [], false)
  let call_name = match body[2] { Match(Call(name, _), _) => name; _ => "" }
  inspect(call_name, content="db.batch")
}

test "build_body: ExecLastId raw_cmd uses conn.execlastid" {
  let q: InternalQuery = {
    name: "insert_user", text: "INSERT INTO users (name) VALUES ($1)", cmd: ExecResult, raw_cmd: ExecLastId,
    params: [{ number: 1, name: "name", ty: Named("text"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "InsertUserRow", "db", None, [], [], false)
  let call_name = match body[2] { Match(Call(name, _), _) => name; _ => "" }
  inspect(call_name, content="db.execlastid")
}

test "build_body: Exec raw_cmd uses conn.exec (default)" {
  let q: InternalQuery = {
    name: "delete_user", text: "DELETE FROM users WHERE id = $1", cmd: ExecResult, raw_cmd: Exec,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "DeleteUserRow", "db", None, [], [], false)
  let call_name = match body[2] { Match(Call(name, _), _) => name; _ => "" }
  inspect(call_name, content="db.exec")
}

test "build_body: ExecResult+None Exec constructs ExecResult::new(0L, n) in Match arm" {
  let q: InternalQuery = {
    name: "delete_user", text: "DELETE FROM users WHERE id = $1", cmd: ExecResult, raw_cmd: Exec,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "DeleteUserRow", "db", None, [], [], false)
  let (arm0_pat, arm0_arg0, arm0_arg1) = match body[2] {
    Match(_, [
      ("Ok(n)", Call("Ok", [Call("ExecResult::new", [Ident(zero), Ident(one)])])),
      ("Err(e)", Call("Err", [Ident("e")])),
    ]) => ("Ok(n)", zero, one)
    _ => ("", "", "")
  }
  inspect(arm0_pat, content="Ok(n)")
  inspect(arm0_arg0, content="0L")
  inspect(arm0_arg1, content="n")
}

test "build_body: ExecResult+None CopyFrom constructs ExecResult::new(0L, n) in Match arm" {
  let q: InternalQuery = {
    name: "copy_users", text: "COPY users FROM stdin", cmd: ExecResult, raw_cmd: CopyFrom,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "CopyUsersRow", "db", None, [], [], false)
  let (arm0_pat, arm0_arg0, arm0_arg1) = match body[2] {
    Match(_, [
      ("Ok(n)", Call("Ok", [Call("ExecResult::new", [Ident(zero), Ident(one)])])),
      ("Err(e)", Call("Err", [Ident("e")])),
    ]) => ("Ok(n)", zero, one)
    _ => ("", "", "")
  }
  inspect(arm0_pat, content="Ok(n)")
  inspect(arm0_arg0, content="0L")
  inspect(arm0_arg1, content="n")
}

test "build_body: ExecResult+None Batch constructs ExecResult::new(0L, n) in Match arm" {
  let q: InternalQuery = {
    name: "batch_insert", text: "INSERT INTO t VALUES ($1)", cmd: ExecResult, raw_cmd: Batch,
    params: [{ number: 1, name: "val", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "BatchInsertRow", "db", None, [], [], false)
  let (arm0_pat, arm0_arg0, arm0_arg1) = match body[2] {
    Match(_, [
      ("Ok(n)", Call("Ok", [Call("ExecResult::new", [Ident(zero), Ident(one)])])),
      ("Err(e)", Call("Err", [Ident("e")])),
    ]) => ("Ok(n)", zero, one)
    _ => ("", "", "")
  }
  inspect(arm0_pat, content="Ok(n)")
  inspect(arm0_arg0, content="0L")
  inspect(arm0_arg1, content="n")
}

test "build_body: ExecResult+None ExecLastId constructs ExecResult::new(n, 1L) in Match arm" {
  let q: InternalQuery = {
    name: "insert_user", text: "INSERT INTO users (name) VALUES ($1)", cmd: ExecResult, raw_cmd: ExecLastId,
    params: [{ number: 1, name: "name", ty: Named("text"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "InsertUserRow", "db", None, [], [], false)
  let (arm0_pat, arm0_arg0, arm0_arg1) = match body[2] {
    Match(_, [
      ("Ok(n)", Call("Ok", [Call("ExecResult::new", [Ident(zero), Ident(one)])])),
      ("Err(e)", Call("Err", [Ident("e")])),
    ]) => ("Ok(n)", zero, one)
    _ => ("", "", "")
  }
  inspect(arm0_pat, content="Ok(n)")
  inspect(arm0_arg0, content="n")
  inspect(arm0_arg1, content="1L")
}

test "build_body: CopyFrom with Rows uses query_row + decode (result_shape > raw_cmd)" {
  let q: InternalQuery = {
    name: "copy_users", text: "COPY users FROM stdin RETURNING id", cmd: ExecResult, raw_cmd: CopyFrom,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (Rows([{ name: "id", ty: Named("int4"), not_null: true, comment: "", rename_to: (None: Option[String]) }]) : InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let body = build_body(q, "CopyUsersRow", "db", q.result_shape, [], [], false)
  let call_name = match body[2] {
    Match(Call(name, _), _) => name
    _ => ""
  }
  inspect(call_name, content="db.query_row")
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
  let fn_def = generate_query_fn(q, "db", Named("DB"), [], [], true, false, false, [])
  inspect(fn_def.name, content="query_get_user")
}

test "supports_transaction: One returns true" {
  inspect(supports_transaction(One), content="true")
}

test "supports_transaction: Many returns true" {
  inspect(supports_transaction(Many), content="true")
}

test "supports_transaction: Exec returns true" {
  inspect(supports_transaction(Exec), content="true")
}

test "supports_transaction: ExecRows returns true" {
  inspect(supports_transaction(ExecRows), content="true")
}

test "supports_transaction: CopyFrom returns false" {
  inspect(supports_transaction(CopyFrom), content="false")
}

test "supports_transaction: Batch returns false" {
  inspect(supports_transaction(Batch), content="false")
}

test "supports_transaction: ExecLastId returns false" {
  inspect(supports_transaction(ExecLastId), content="false")
}

test "generate_query_fns: CopyFrom only generates 1 fn (no tx overload)" {
  let q: InternalQuery = {
    name: "copy_users", text: "COPY users FROM stdin", cmd: ExecResult, raw_cmd: CopyFrom,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q], [], [], true, false, false, [])
  inspect(items.length(), content="1")
  let param0_name = match items[0] { Fn(f) => f.params[0].name; _ => "" }
  inspect(param0_name, content="db")
}

test "generate_query_fns: Batch only generates 1 fn (no tx overload)" {
  let q: InternalQuery = {
    name: "batch_insert", text: "INSERT INTO t VALUES ($1)", cmd: ExecResult, raw_cmd: Batch,
    params: [{ number: 1, name: "val", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q], [], [], true, false, false, [])
  inspect(items.length(), content="1")
  let param0_name = match items[0] { Fn(f) => f.params[0].name; _ => "" }
  inspect(param0_name, content="db")
}

test "generate_query_fns: ExecLastId only generates 1 fn (no tx overload)" {
  let q: InternalQuery = {
    name: "insert_user", text: "INSERT INTO users (name) VALUES ($1)", cmd: ExecResult, raw_cmd: ExecLastId,
    params: [{ number: 1, name: "name", ty: Named("text"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q], [], [], true, false, false, [])
  inspect(items.length(), content="1")
  let param0_name = match items[0] { Fn(f) => f.params[0].name; _ => "" }
  inspect(param0_name, content="db")
}

test "generate_query_fns: One still generates 2 fns (db + tx)" {
  let q: InternalQuery = {
    name: "get_user", text: "SELECT * FROM users WHERE id = $1", cmd: OneRow, raw_cmd: One,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q], [], [], true, false, false, [])
  inspect(items.length(), content="2")
  let param0_name = match items[0] { Fn(f) => f.params[0].name; _ => "" }
  let param1_name = match items[1] { Fn(f) => f.params[0].name; _ => "" }
  inspect(param0_name, content="db")
  inspect(param1_name, content="tx")
}

test "generate_query_fns: Exec still generates 2 fns (db + tx)" {
  let q: InternalQuery = {
    name: "delete_user", text: "DELETE FROM users WHERE id = $1", cmd: ExecResult, raw_cmd: Exec,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q], [], [], true, false, false, [])
  inspect(items.length(), content="2")
  let param0_name = match items[0] { Fn(f) => f.params[0].name; _ => "" }
  let param1_name = match items[1] { Fn(f) => f.params[0].name; _ => "" }
  inspect(param0_name, content="db")
  inspect(param1_name, content="tx")
}

test "generate_query_fns: Many still generates 2 fns (db + tx)" {
  let q: InternalQuery = {
    name: "list_users", text: "SELECT * FROM users", cmd: ManyRows, raw_cmd: Many,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q], [], [], true, false, false, [])
  inspect(items.length(), content="2")
  let param0_name = match items[0] { Fn(f) => f.params[0].name; _ => "" }
  let param1_name = match items[1] { Fn(f) => f.params[0].name; _ => "" }
  inspect(param0_name, content="db")
  inspect(param1_name, content="tx")
}

test "generate_query_fns: ExecRows still generates 2 fns (db + tx)" {
  let q: InternalQuery = {
    name: "update_email", text: "UPDATE users SET email = $1 WHERE id = $2", cmd: ExecCount, raw_cmd: ExecRows,
    params: [
      { number: 1, name: "email", ty: Named("text"), not_null: true },
      { number: 2, name: "id", ty: Named("int4"), not_null: true },
    ],
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let items = generate_query_fns([q], [], [], true, false, false, [])
  inspect(items.length(), content="2")
  let param0_name = match items[0] { Fn(f) => f.params[0].name; _ => "" }
  let param1_name = match items[1] { Fn(f) => f.params[0].name; _ => "" }
  inspect(param0_name, content="db")
  inspect(param1_name, content="tx")
}

// === P0-065: Keyword escaping tests ===

test "P0-065: parameter name 'type' is escaped to 'ty'" {
  let p: InternalParameter = { number: 1, name: "type", ty: Named("text"), not_null: true }
  let pd = param_to_param_def(p, [], [])
  inspect(pd.name, content="ty")
}

test "P0-065: parameter name 'fn' is escaped to 'fn_'" {
  let p: InternalParameter = { number: 1, name: "fn", ty: Named("int4"), not_null: true }
  let pd = param_to_param_def(p, [], [])
  inspect(pd.name, content="fn_")
}

test "P0-065: non-keyword parameter name passes through" {
  let p: InternalParameter = { number: 1, name: "user_id", ty: Named("int4"), not_null: true }
  let pd = param_to_param_def(p, [], [])
  inspect(pd.name, content="user_id")
}

test "P0-065: get_result_type_name: query named 'type' produces TypeRow" {
  let q: InternalQuery = {
    name: "type", text: "", cmd: OneRow, raw_cmd: One,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let name = get_result_type_name(q, [])
  inspect(name, content="TypeRow")
}

test "P0-065: get_result_type_name: query named 'int' produces IntRow" {
  let q: InternalQuery = {
    name: "int", text: "", cmd: OneRow, raw_cmd: One,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""), filename: "",
  }
  let name = get_result_type_name(q, [])
  inspect(name, content="IntRow")
}

// === P0-062: :one query TooManyRows detection tests ===

/// Helper to generate and emit a :one query function for string-based assertions.
fn emit_one_query_body() -> String {
  let q: InternalQuery = {
    name: "get_user", text: "SELECT id, name FROM users WHERE id = $1", cmd: OneRow, raw_cmd: One,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: ["Get a user by ID"], filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "db", Named("DB"), [], [], true, false, false, [])
  let sf: SourceFile = { items: [Fn(fn_def)] }
  emit_source_file(sf)
}

/// Helper to generate and emit a :one query function with tx connection for string-based assertions.
fn emit_one_query_tx_body() -> String {
  let q: InternalQuery = {
    name: "get_user", text: "SELECT id, name FROM users WHERE id = $1", cmd: OneRow, raw_cmd: One,
    params: [{ number: 1, name: "id", ty: Named("int4"), not_null: true }],
    result_shape: (None: InternalResultShape),
    comments: ["Get a user by ID"], filename: "q.sql",
  }
  let fn_def = generate_query_fn(q, "tx", Named("Transaction"), [], [], true, false, false, [])
  let sf: SourceFile = { items: [Fn(fn_def)] }
  emit_source_file(sf)
}

test "P0-062: :one query uses db.query() instead of db.query_row()" {
  let result = emit_one_query_body()
  inspect(result.contains("match db.query(sql, params)"), content="true")
  inspect(result.contains("db.query_row"), content="false")
}

test "P0-062: :one query uses collect_limited(2) for row count guard" {
  let result = emit_one_query_body()
  inspect(result.contains("collect_limited(2)"), content="true")
}

test "P0-062: :one query has Err(NoRows) arm for empty result" {
  let result = emit_one_query_body()
  inspect(result.contains("0 => Err(NoRows)"), content="true")
}

test "P0-062: :one query decodes collected[0] for single row" {
  let result = emit_one_query_body()
  inspect(result.contains("GetUserRow::decode(collected[0])"), content="true")
}

test "P0-062: :one query has Err(TooManyRows) arm for 2+ rows" {
  let result = emit_one_query_body()
  inspect(result.contains("Err(TooManyRows"), content="true")
}

test "P0-062: :one query handles TooManyRows from collect_limited (3+ rows)" {
  let result = emit_one_query_body()
  inspect(result.contains("Err(TooManyRows(n, _))"), content="true")
  inspect(result.contains("Err(TooManyRows(n, sql))"), content="true")
}

test "P0-062: :one query general error propagation preserved" {
  let result = emit_one_query_body()
  inspect(result.contains("Err(e) => Err(e)"), content="true")
}

test "P0-062: :one query tx overload also uses tx.query() with TooManyRows detection" {
  let result = emit_one_query_tx_body()
  inspect(result.contains("match tx.query(sql, params)"), content="true")
  inspect(result.contains("tx.query_row"), content="false")
  inspect(result.contains("collect_limited(2)"), content="true")
}
