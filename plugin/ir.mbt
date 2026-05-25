///|
/// Internal IR Definition — P0-004.
/// Semantic boundary between protobuf adapter (P0-003) and MoonBit AST (P0-005).
/// All types are independent of both protobuf schema and MoonBit syntax.
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

/// Query cardinality — determines generated function signature shape.
pub enum QueryCardinality {
  OneRow
  ManyRows
  ExecResult
  ExecCount
}

impl Show for QueryCardinality with to_string(self) -> String {
  match self {
    OneRow => "OneRow"
    ManyRows => "ManyRows"
    ExecResult => "ExecResult"
    ExecCount => "ExecCount"
  }
}

/// IR type — resolved or unresolved type reference.
pub enum InternalType {
  /// Named type (e.g. "int4", "text", "bool") — resolved by Type Mapping Layer
  Named(String)
  /// Array of element type
  Arr(InternalType)
}

impl Show for InternalType with to_string(self) -> String {
  match self {
    Named(s) => "Named(\"" + s + "\")"
    Arr(elem) => "Arr(" + elem.to_string() + ")"
  }
}

/// IR field — a named field in a query result or table struct.
pub struct InternalField {
  name : String
  ty : InternalType
  not_null : Bool
  comment : String
}

/// IR parameter — a query parameter with position and type.
pub struct InternalParameter {
  number : Int
  name : String
  ty : InternalType
  not_null : Bool
}

/// IR result shape — describes the structure of query results.
pub enum InternalResultShape {
  /// Named columns (for :one/:many)
  Rows(Array[InternalField])
  /// No result rows (for :exec/:execrows)
  None
}

/// IR query — complete codegen-ready query representation.
pub struct InternalQuery {
  name : String
  text : String
  cmd : QueryCardinality
  raw_cmd : QueryCmd
  params : Array[InternalParameter]
  result_shape : InternalResultShape
  comments : Array[String]
  filename : String
}

// === Converters: adapter types → IR ===

fn cmd_to_cardinality(cmd: QueryCmd) -> QueryCardinality {
  match cmd {
    One => OneRow
    Many => ManyRows
    Exec => ExecResult
    ExecRows => ExecCount
    CopyFrom => ExecResult
    Batch => ExecResult
    ExecLastId => ExecResult
  }
}

fn adapt_column_to_field(col: AdaptColumn) -> InternalField {
  {
    name: col.name,
    ty: if col.is_array { Arr(Named(col.ty.name)) } else { Named(col.ty.name) },
    not_null: col.not_null,
    comment: col.comment,
  }
}

fn adapt_parameter_to_ir(p: AdaptParameter) -> InternalParameter {
  {
    number: p.number,
    name: p.column.name,
    ty: if p.column.is_array { Arr(Named(p.column.ty.name)) } else { Named(p.column.ty.name) },
    not_null: p.column.not_null,
  }
}

fn build_result_shape(cmd: QueryCardinality, fields: Array[InternalField]) -> InternalResultShape {
  match cmd {
    // PostgreSQL RETURNING *: exec-like commands may have result columns
    ExecResult | ExecCount =>
      if fields.length() > 0 { Rows(fields) } else { None }
    OneRow | ManyRows => Rows(fields)
  }
}

fn build_query(q: AdaptQuery) -> InternalQuery {
  let card = cmd_to_cardinality(q.cmd)
  let fields = q.columns.map(adapt_column_to_field)
  {
    name: q.name,
    text: q.text,
    cmd: card,
    raw_cmd: q.cmd,
    params: q.params.map(adapt_parameter_to_ir),
    result_shape: build_result_shape(card, fields),
    comments: q.comments,
    filename: q.filename,
  }
}

/// Convert an adapted request into IR queries.
pub fn build_ir(req: AdaptRequest) -> Array[InternalQuery] {
  req.queries.map(build_query)
}

// === Tests ===

test "cmd_to_cardinality: One → OneRow" {
  let c = cmd_to_cardinality(One)
  inspect(c, content="OneRow")
}

test "cmd_to_cardinality: Many → ManyRows" {
  let c = cmd_to_cardinality(Many)
  inspect(c, content="ManyRows")
}

test "cmd_to_cardinality: Exec → ExecResult" {
  let c = cmd_to_cardinality(Exec)
  inspect(c, content="ExecResult")
}

test "cmd_to_cardinality: ExecRows → ExecCount" {
  let c = cmd_to_cardinality(ExecRows)
  inspect(c, content="ExecCount")
}

test "cmd_to_cardinality: CopyFrom → ExecResult" {
  let c = cmd_to_cardinality(CopyFrom)
  inspect(c, content="ExecResult")
}

test "cmd_to_cardinality: Batch → ExecResult" {
  let c = cmd_to_cardinality(Batch)
  inspect(c, content="ExecResult")
}

test "cmd_to_cardinality: ExecLastId → ExecResult" {
  let c = cmd_to_cardinality(ExecLastId)
  inspect(c, content="ExecResult")
}

test "build_ir: empty queries" {
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir.length(), content="0")
}

test "build_ir: :one query produces Rows result shape" {
  let col: AdaptColumn = {
    name: "id",
    not_null: true,
    is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0,
    comment: "",
    table: { catalog: "", schema: "public", name: "users" },
  }
  let q: AdaptQuery = {
    text: "SELECT id FROM users WHERE id = $1",
    name: "get_user",
    cmd: One,
    columns: [col],
    params: [],
    comments: [],
    filename: "query.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir.length(), content="1")
  inspect(ir[0].name, content="get_user")
  inspect(ir[0].cmd, content="OneRow")
  inspect(ir[0].params.length(), content="0")
  // result_shape should be Rows with 1 field
  let has_rows = match ir[0].result_shape {
    Rows(_) => true
    None => false
  }
  inspect(has_rows, content="true")
  let fields = match ir[0].result_shape {
    Rows(f) => f
    None => []
  }
  inspect(fields.length(), content="1")
  inspect(fields[0].name, content="id")
  inspect(fields[0].ty, content="Named(\"int4\")")
  inspect(fields[0].not_null, content="true")
}

test "build_ir: :many query with multiple columns" {
  let col1: AdaptColumn = {
    name: "id", not_null: true, is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "users" },
  }
  let col2: AdaptColumn = {
    name: "email", not_null: false, is_array: false,
    ty: { catalog: "", schema: "", name: "text" },
    length: 255, comment: "user email",
    table: { catalog: "", schema: "public", name: "users" },
  }
  let q: AdaptQuery = {
    text: "SELECT id, email FROM users",
    name: "list_users",
    cmd: Many,
    columns: [col1, col2],
    params: [],
    comments: ["list all users"],
    filename: "query.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].cmd, content="ManyRows")
  inspect(ir[0].comments.length(), content="1")
  inspect(ir[0].comments[0], content="list all users")
  let fields = match ir[0].result_shape {
    Rows(f) => f
    None => []
  }
  inspect(fields.length(), content="2")
  inspect(fields[0].name, content="id")
  inspect(fields[1].name, content="email")
  inspect(fields[1].not_null, content="false")
  inspect(fields[1].ty, content="Named(\"text\")")
  inspect(fields[1].comment, content="user email")
}

test "build_ir: :exec produces None result shape" {
  let q: AdaptQuery = {
    text: "DELETE FROM users WHERE id = $1",
    name: "delete_user",
    cmd: Exec,
    columns: [],
    params: [],
    comments: [],
    filename: "query.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].cmd, content="ExecResult")
  let is_none = match ir[0].result_shape {
    None => true
    Rows(_) => false
  }
  inspect(is_none, content="true")
}

test "build_ir: :execrows produces None result shape" {
  let q: AdaptQuery = {
    text: "UPDATE users SET name = $1 WHERE id = $2",
    name: "update_user",
    cmd: ExecRows,
    columns: [],
    params: [],
    comments: [],
    filename: "query.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].cmd, content="ExecCount")
  let is_none = match ir[0].result_shape {
    None => true
    Rows(_) => false
  }
  inspect(is_none, content="true")
}

test "build_ir: query with parameters" {
  let param_col: AdaptColumn = {
    name: "min_age", not_null: true, is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "", name: "" },
  }
  let param: AdaptParameter = { number: 1, column: param_col }
  let q: AdaptQuery = {
    text: "SELECT * FROM users WHERE age > $1",
    name: "older_than",
    cmd: Many,
    columns: [],
    params: [param],
    comments: [],
    filename: "query.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].params.length(), content="1")
  inspect(ir[0].params[0].number, content="1")
  inspect(ir[0].params[0].name, content="min_age")
  inspect(ir[0].params[0].ty, content="Named(\"int4\")")
  inspect(ir[0].params[0].not_null, content="true")
}

test "InternalType::Array construction" {
  let elem: InternalType = Named("int4")
  let arr: InternalType = Arr(elem)
  inspect(arr, content="Arr(Named(\"int4\"))")
}

test "build_ir: multiple queries" {
  let q1: AdaptQuery = {
    text: "SELECT * FROM users", name: "q1", cmd: Many,
    columns: [], params: [], comments: [], filename: "a.sql",
  }
  let q2: AdaptQuery = {
    text: "SELECT * FROM posts", name: "q2", cmd: One,
    columns: [], params: [], comments: [], filename: "b.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q1, q2],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir.length(), content="2")
  inspect(ir[0].name, content="q1")
  inspect(ir[1].name, content="q2")
}

test "adapt_column_to_field: is_array wraps type in Arr" {
  let col: AdaptColumn = {
    name: "tags", not_null: true, is_array: true,
    ty: { catalog: "", schema: "", name: "text" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "posts" },
  }
  let f = adapt_column_to_field(col)
  inspect(f.name, content="tags")
  inspect(f.ty, content="Arr(Named(\"text\"))")
  inspect(f.not_null, content="true")
}

test "adapt_column_to_field: is_array false does not wrap" {
  let col: AdaptColumn = {
    name: "id", not_null: true, is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "users" },
  }
  let f = adapt_column_to_field(col)
  inspect(f.ty, content="Named(\"int4\")")
}

test "build_ir: :many with array column preserves Arr type" {
  let col: AdaptColumn = {
    name: "tags", not_null: true, is_array: true,
    ty: { catalog: "", schema: "", name: "text" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "posts" },
  }
  let q: AdaptQuery = {
    text: "SELECT tags FROM posts", name: "list_tags", cmd: Many,
    columns: [col], params: [], comments: [], filename: "q.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  let fields = match ir[0].result_shape {
    Rows(f) => f
    None => []
  }
  inspect(fields.length(), content="1")
  inspect(fields[0].ty, content="Arr(Named(\"text\"))")
}

test "build_ir: :exec with RETURNING * produces Rows when columns non-empty" {
  let col: AdaptColumn = {
    name: "id", not_null: true, is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "users" },
  }
  let q: AdaptQuery = {
    text: "INSERT INTO users DEFAULT VALUES RETURNING id",
    name: "create_user", cmd: Exec,
    columns: [col], params: [], comments: [], filename: "q.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].cmd, content="ExecResult")
  let has_rows = match ir[0].result_shape {
    Rows(_) => true
    None => false
  }
  inspect(has_rows, content="true")
  let fields = match ir[0].result_shape {
    Rows(f) => f
    None => []
  }
  inspect(fields.length(), content="1")
  inspect(fields[0].name, content="id")
}

test "build_ir: :execrows with RETURNING * produces Rows when columns non-empty" {
  let col: AdaptColumn = {
    name: "new_name", not_null: false, is_array: false,
    ty: { catalog: "", schema: "", name: "text" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "users" },
  }
  let q: AdaptQuery = {
    text: "UPDATE users SET name = $1 WHERE id = $2 RETURNING name",
    name: "update_user", cmd: ExecRows,
    columns: [col], params: [], comments: [], filename: "q.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].cmd, content="ExecCount")
  let has_rows = match ir[0].result_shape {
    Rows(_) => true
    None => false
  }
  inspect(has_rows, content="true")
}

test "build_ir: :copyfrom produces ExecResult with None result shape" {
  let q: AdaptQuery = {
    text: "COPY users FROM stdin", name: "load_users", cmd: CopyFrom,
    columns: [], params: [], comments: [], filename: "q.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].cmd, content="ExecResult")
  let is_none = match ir[0].result_shape {
    None => true
    Rows(_) => false
  }
  inspect(is_none, content="true")
}

test "build_ir: :batch produces ExecResult with None result shape" {
  let q: AdaptQuery = {
    text: "INSERT INTO t VALUES (1), (2)", name: "batch_insert", cmd: Batch,
    columns: [], params: [], comments: [], filename: "q.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].cmd, content="ExecResult")
  let is_none = match ir[0].result_shape {
    None => true
    Rows(_) => false
  }
  inspect(is_none, content="true")
}

test "build_ir: :execlastid produces ExecResult with None result shape" {
  let q: AdaptQuery = {
    text: "INSERT INTO users (name) VALUES ($1)", name: "create_user", cmd: ExecLastId,
    columns: [], params: [], comments: [], filename: "q.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  inspect(ir[0].cmd, content="ExecResult")
  let is_none = match ir[0].result_shape {
    None => true
    Rows(_) => false
  }
  inspect(is_none, content="true")
}

test "build_ir: :exec with empty columns still produces None" {
  let q: AdaptQuery = {
    text: "DELETE FROM users WHERE id = $1", name: "del", cmd: Exec,
    columns: [], params: [], comments: [], filename: "q.sql",
  }
  let req: AdaptRequest = {
    settings: { version: "", engine: "" },
    catalog: { name: "", default_schema: "", schemas: [] },
    queries: [q],
    sqlc_version: "",
  }
  let ir = build_ir(req)
  let is_none = match ir[0].result_shape {
    None => true
    Rows(_) => false
  }
  inspect(is_none, content="true")
}

test "adapt_parameter_to_ir: is_array wraps type in Arr" {
  let col: AdaptColumn = {
    name: "ids", not_null: true, is_array: true,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "", name: "" },
  }
  let p: AdaptParameter = { number: 1, column: col }
  let param = adapt_parameter_to_ir(p)
  inspect(param.ty, content="Arr(Named(\"int4\"))")
}
