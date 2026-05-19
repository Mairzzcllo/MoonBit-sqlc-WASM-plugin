///|
/// Protobuf Adapter Layer — P0-003.
/// Converts raw protobuf types (from types.mbt) into the plugin's internal model.
/// This is the semantic boundary between protobuf schema and downstream IR/codegen.
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

/// Parsed query command kind from sqlc's `:one`, `:many`, `:exec`, `:execrows`.
pub enum QueryCmd {
  One
  Many
  Exec
  ExecRows
}

impl Show for QueryCmd with to_string(self) -> String {
  match self {
    One => "One"
    Many => "Many"
    Exec => "Exec"
    ExecRows => "ExecRows"
  }
}

/// Parse a sqlc cmd string into a QueryCmd.
pub fn parse_query_cmd(cmd: String) -> QueryCmd {
  match cmd {
    ":one" => One
    ":many" => Many
    ":exec" => Exec
    ":execrows" => ExecRows
    _ => Exec
  }
}

/// Internal model — cleaned-up identifier.
pub struct AdaptIdentifier {
  catalog : String
  schema : String
  name : String
}

/// Internal model — cleaned-up column.
pub struct AdaptColumn {
  name : String
  not_null : Bool
  is_array : Bool
  ty : AdaptIdentifier
  length : Int
  comment : String
  table : AdaptIdentifier
}

/// Internal model — cleaned-up enum.
pub struct AdaptEnum {
  name : String
  vals : Array[String]
  comment : String
}

/// Internal model — cleaned-up table.
pub struct AdaptTable {
  name : String
  schema : String
  columns : Array[AdaptColumn]
  comment : String
}

/// Internal model — cleaned-up parameter.
pub struct AdaptParameter {
  number : Int
  column : AdaptColumn
}

/// Internal model — cleaned-up query with parsed cmd.
pub struct AdaptQuery {
  text : String
  name : String
  cmd : QueryCmd
  columns : Array[AdaptColumn]
  params : Array[AdaptParameter]
  comments : Array[String]
  filename : String
}

/// Internal model — cleaned-up schema.
pub struct AdaptSchema {
  name : String
  comment : String
  tables : Array[AdaptTable]
  enums : Array[AdaptEnum]
}

/// Internal model — cleaned-up catalog.
pub struct AdaptCatalog {
  name : String
  default_schema : String
  schemas : Array[AdaptSchema]
}

/// Internal model — cleaned-up settings.
pub struct AdaptSettings {
  version : String
  engine : String
}

/// Top-level internal model for a code generation request.
pub struct AdaptRequest {
  settings : AdaptSettings
  catalog : AdaptCatalog
  queries : Array[AdaptQuery]
  sqlc_version : String
}

/// Parsed plugin/global options from codegen configuration.
pub struct PluginOptions {
  /// Package name for generated code (e.g. "myapp" from codegen.options.package_name).
  package_name : String
}

/// Parse plugin_options bytes into a PluginOptions struct.
/// Silently returns defaults on empty data or parse failure.
pub fn parse_plugin_options(data: Bytes) -> PluginOptions {
  if data.length() == 0 { return { package_name: "" } }
  let text = @utf8.decode_lossy(data[:])
  let mut package_name = ""
  for line in text.split("\n") {
    let s = line.trim().to_string()
    if s.has_prefix("package_name=") {
      package_name = s[14:].trim().to_string()
    } else if s.has_prefix("package_name =") {
      package_name = s[15:].trim().to_string()
    }
  }
  { package_name: package_name }
}

// === Converters: raw protobuf types → internal model ===

fn convert_identifier(id: Identifier) -> AdaptIdentifier {
  { catalog: id.catalog, schema: id.schema, name: id.name }
}

fn convert_column(col: Column) -> AdaptColumn {
  {
    name: col.name,
    not_null: col.not_null,
    is_array: col.is_array,
    ty: convert_identifier(col.ty),
    length: col.length,
    comment: col.comment,
    table: convert_identifier(col.table),
  }
}

fn convert_parameter(p: Parameter) -> AdaptParameter {
  { number: p.number, column: convert_column(p.column) }
}

fn convert_enum(e: Enum) -> AdaptEnum {
  { name: e.name, vals: e.vals, comment: e.comment }
}

fn convert_table(t: Table) -> AdaptTable {
  {
    name: t.rel.name,
    schema: t.rel.schema,
    columns: t.columns.map(convert_column),
    comment: t.comment,
  }
}

fn convert_schema(s: Schema) -> AdaptSchema {
  {
    name: s.name,
    comment: s.comment,
    tables: s.tables.map(convert_table),
    enums: s.enums.map(convert_enum),
  }
}

fn convert_catalog(c: Catalog) -> AdaptCatalog {
  {
    name: c.name,
    default_schema: c.default_schema,
    schemas: c.schemas.map(convert_schema),
  }
}

fn convert_settings(s: Settings) -> AdaptSettings {
  { version: s.version, engine: s.engine }
}

fn convert_query(q: Query) -> AdaptQuery {
  {
    text: q.text,
    name: q.name,
    cmd: parse_query_cmd(q.cmd),
    columns: q.columns.map(convert_column),
    params: q.params.map(convert_parameter),
    comments: q.comments,
    filename: q.filename,
  }
}

/// Convert a raw GenerateRequest into the internal adapter model.
pub fn convert_request(req: GenerateRequest) -> AdaptRequest {
  {
    settings: convert_settings(req.settings),
    catalog: convert_catalog(req.catalog),
    queries: req.queries.map(convert_query),
    sqlc_version: req.sqlc_version,
  }
}

// === Tests ===

test "parse_query_cmd: :one" {
  inspect(parse_query_cmd(":one"), content="One")
}

test "parse_query_cmd: :many" {
  inspect(parse_query_cmd(":many"), content="Many")
}

test "parse_query_cmd: :exec" {
  inspect(parse_query_cmd(":exec"), content="Exec")
}

test "parse_query_cmd: :execrows" {
  inspect(parse_query_cmd(":execrows"), content="ExecRows")
}

test "parse_query_cmd: empty string falls back to Exec" {
  inspect(parse_query_cmd(""), content="Exec")
}

test "parse_query_cmd: unknown cmd falls back to Exec" {
  inspect(parse_query_cmd(":unknown"), content="Exec")
}

test "convert_request: minimal empty request" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let cg: Codegen = { out: "", plugin: "", options: b"", env: Array::make(0, ""), process: None, wasm: None }
  let settings: Settings = { version: "v1", engine: "postgresql", schema: Array::make(0, ""), queries: Array::make(0, ""), codegen: cg }
  let schema: Schema = { comment: "", name: "public", tables: Array::make(0, { rel: empty_id, columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), comment: "" }), enums: Array::make(0, { name: "", vals: Array::make(0, ""), comment: "" }), composite_types: Array::make(0, { name: "", comment: "" }) }
  let catalog: Catalog = { comment: "", default_schema: "public", name: "testdb", schemas: [schema] }
  let req: GenerateRequest = { settings: settings, catalog: catalog, queries: Array::make(0, { text: "", name: "", cmd: "", columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), params: Array::make(0, { number: 0, column: { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 } }), comments: Array::make(0, ""), filename: "", insert_into_table: empty_id }), sqlc_version: "1.0.0", plugin_options: b"", global_options: b"" }

  let adapted = convert_request(req)
  inspect(adapted.settings.version, content="v1")
  inspect(adapted.settings.engine, content="postgresql")
  inspect(adapted.catalog.name, content="testdb")
  inspect(adapted.catalog.default_schema, content="public")
  inspect(adapted.catalog.schemas.length(), content="1")
  inspect(adapted.catalog.schemas[0].name, content="public")
  inspect(adapted.sqlc_version, content="1.0.0")
}

test "convert_request: query with parsed cmd" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let cg: Codegen = { out: "", plugin: "", options: b"", env: Array::make(0, ""), process: None, wasm: None }
  let settings: Settings = { version: "", engine: "", schema: Array::make(0, ""), queries: Array::make(0, ""), codegen: cg }
  let schema: Schema = { comment: "", name: "", tables: Array::make(0, { rel: empty_id, columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), comment: "" }), enums: Array::make(0, { name: "", vals: Array::make(0, ""), comment: "" }), composite_types: Array::make(0, { name: "", comment: "" }) }
  let catalog: Catalog = { comment: "", default_schema: "", name: "", schemas: [schema] }

  // Build a query with :many cmd
  let col: Column = { name: "id", not_null: true, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: { catalog: "", schema: "", name: "int4" }, is_sqlc_slice: false, embed_table: empty_id, original_name: "id", unsigned: false, array_dims: 0 }
  let query: Query = { text: "SELECT * FROM users", name: "list_users", cmd: ":many", columns: [col], params: Array::make(0, { number: 0, column: { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 } }), comments: Array::make(0, ""), filename: "queries.sql", insert_into_table: empty_id }
  let req: GenerateRequest = { settings: settings, catalog: catalog, queries: [query], sqlc_version: "", plugin_options: b"", global_options: b"" }

  let adapted = convert_request(req)
  inspect(adapted.queries.length(), content="1")
  inspect(adapted.queries[0].name, content="list_users")
  inspect(adapted.queries[0].text, content="SELECT * FROM users")
  inspect(adapted.queries[0].cmd, content="Many")
  inspect(adapted.queries[0].filename, content="queries.sql")
  inspect(adapted.queries[0].columns.length(), content="1")
  inspect(adapted.queries[0].columns[0].name, content="id")
  inspect(adapted.queries[0].columns[0].not_null, content="true")
  inspect(adapted.queries[0].columns[0].ty.name, content="int4")
}

test "convert_request: table with identifier resolved to name/schema" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let cg: Codegen = { out: "", plugin: "", options: b"", env: Array::make(0, ""), process: None, wasm: None }
  let settings: Settings = { version: "", engine: "", schema: Array::make(0, ""), queries: Array::make(0, ""), codegen: cg }

  let tbl_rel: Identifier = { catalog: "", schema: "public", name: "users" }
  let tbl: Table = { rel: tbl_rel, columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), comment: "users table" }
  let schema: Schema = { comment: "", name: "public", tables: [tbl], enums: Array::make(0, { name: "", vals: Array::make(0, ""), comment: "" }), composite_types: Array::make(0, { name: "", comment: "" }) }
  let catalog: Catalog = { comment: "", default_schema: "public", name: "test", schemas: [schema] }
  let req: GenerateRequest = { settings: settings, catalog: catalog, queries: Array::make(0, { text: "", name: "", cmd: "", columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), params: Array::make(0, { number: 0, column: { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 } }), comments: Array::make(0, ""), filename: "", insert_into_table: empty_id }), sqlc_version: "", plugin_options: b"", global_options: b"" }

  let adapted = convert_request(req)
  inspect(adapted.catalog.schemas[0].tables.length(), content="1")
  inspect(adapted.catalog.schemas[0].tables[0].name, content="users")
  inspect(adapted.catalog.schemas[0].tables[0].schema, content="public")
  inspect(adapted.catalog.schemas[0].tables[0].comment, content="users table")
}

test "convert_request: enums in schema" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let cg: Codegen = { out: "", plugin: "", options: b"", env: Array::make(0, ""), process: None, wasm: None }
  let settings: Settings = { version: "", engine: "", schema: Array::make(0, ""), queries: Array::make(0, ""), codegen: cg }
  let e: Enum = { name: "mood", vals: ["happy", "sad", "neutral"], comment: "" }
  let schema: Schema = { comment: "", name: "public", tables: Array::make(0, { rel: empty_id, columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), comment: "" }), enums: [e], composite_types: Array::make(0, { name: "", comment: "" }) }
  let catalog: Catalog = { comment: "", default_schema: "public", name: "test", schemas: [schema] }
  let req: GenerateRequest = { settings: settings, catalog: catalog, queries: Array::make(0, { text: "", name: "", cmd: "", columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), params: Array::make(0, { number: 0, column: { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 } }), comments: Array::make(0, ""), filename: "", insert_into_table: empty_id }), sqlc_version: "", plugin_options: b"", global_options: b"" }

  let adapted = convert_request(req)
  inspect(adapted.catalog.schemas[0].enums.length(), content="1")
  inspect(adapted.catalog.schemas[0].enums[0].name, content="mood")
  inspect(adapted.catalog.schemas[0].enums[0].vals.length(), content="3")
  inspect(adapted.catalog.schemas[0].enums[0].vals[0], content="happy")
  inspect(adapted.catalog.schemas[0].enums[0].vals[1], content="sad")
  inspect(adapted.catalog.schemas[0].enums[0].vals[2], content="neutral")
}

test "convert_request: query with parameter" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let cg: Codegen = { out: "", plugin: "", options: b"", env: Array::make(0, ""), process: None, wasm: None }
  let settings: Settings = { version: "", engine: "", schema: Array::make(0, ""), queries: Array::make(0, ""), codegen: cg }
  let schema: Schema = { comment: "", name: "", tables: Array::make(0, { rel: empty_id, columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), comment: "" }), enums: Array::make(0, { name: "", vals: Array::make(0, ""), comment: "" }), composite_types: Array::make(0, { name: "", comment: "" }) }
  let catalog: Catalog = { comment: "", default_schema: "", name: "", schemas: [schema] }
  let param_col: Column = { name: "min_age", not_null: true, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: { catalog: "", schema: "", name: "int4" }, is_sqlc_slice: false, embed_table: empty_id, original_name: "min_age", unsigned: false, array_dims: 0 }
  let param: Parameter = { number: 1, column: param_col }
  let query: Query = { text: "SELECT * FROM users WHERE age > $1", name: "older_than", cmd: ":many", columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), params: [param], comments: Array::make(0, ""), filename: "queries.sql", insert_into_table: empty_id }
  let req: GenerateRequest = { settings: settings, catalog: catalog, queries: [query], sqlc_version: "", plugin_options: b"", global_options: b"" }

  let adapted = convert_request(req)
  inspect(adapted.queries[0].params.length(), content="1")
  inspect(adapted.queries[0].params[0].number, content="1")
  inspect(adapted.queries[0].params[0].column.name, content="min_age")
  inspect(adapted.queries[0].params[0].column.ty.name, content="int4")
}

test "convert_request: column with type info preserved" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let cg: Codegen = { out: "", plugin: "", options: b"", env: Array::make(0, ""), process: None, wasm: None }
  let settings: Settings = { version: "", engine: "", schema: Array::make(0, ""), queries: Array::make(0, ""), codegen: cg }

  let ty_id: Identifier = { catalog: "", schema: "", name: "text" }
  let tbl_id: Identifier = { catalog: "", schema: "public", name: "users" }
  let col: Column = { name: "email", not_null: true, is_array: false, comment: "user email", length: 255, is_named_param: false, is_func_call: false, scope: "", table: tbl_id, table_alias: "u", ty: ty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "email_addr", unsigned: false, array_dims: 0 }
  let tbl: Table = { rel: tbl_id, columns: [col], comment: "users table" }
  let schema: Schema = { comment: "", name: "public", tables: [tbl], enums: Array::make(0, { name: "", vals: Array::make(0, ""), comment: "" }), composite_types: Array::make(0, { name: "", comment: "" }) }
  let catalog: Catalog = { comment: "", default_schema: "public", name: "test", schemas: [schema] }
  let req: GenerateRequest = { settings: settings, catalog: catalog, queries: Array::make(0, { text: "", name: "", cmd: "", columns: Array::make(0, { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 }), params: Array::make(0, { number: 0, column: { name: "", not_null: false, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: empty_id, table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id, original_name: "", unsigned: false, array_dims: 0 } }), comments: Array::make(0, ""), filename: "", insert_into_table: empty_id }), sqlc_version: "", plugin_options: b"", global_options: b"" }

  let adapted = convert_request(req)
  let adapted_col = adapted.catalog.schemas[0].tables[0].columns[0]
  inspect(adapted_col.name, content="email")
  inspect(adapted_col.not_null, content="true")
  inspect(adapted_col.is_array, content="false")
  inspect(adapted_col.ty.name, content="text")
  inspect(adapted_col.length, content="255")
  inspect(adapted_col.comment, content="user email")
  inspect(adapted_col.table.schema, content="public")
  inspect(adapted_col.table.name, content="users")
}
