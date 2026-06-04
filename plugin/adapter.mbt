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

/// Parsed query command kind from sqlc's `:one`, `:many`, `:exec`, `:execrows`, `:copyfrom`, `:batch`, `:execlastid`.
pub enum QueryCmd {
  One
  Many
  Exec
  ExecRows
  CopyFrom
  Batch
  ExecLastId
}

impl Show for QueryCmd with to_string(self) -> String {
  match self {
    One => "One"
    Many => "Many"
    Exec => "Exec"
    ExecRows => "ExecRows"
    CopyFrom => "CopyFrom"
    Batch => "Batch"
    ExecLastId => "ExecLastId"
  }
}

/// Parse a sqlc cmd string into a QueryCmd.
pub fn parse_query_cmd(cmd: String) -> QueryCmd {
  match cmd {
    ":one" => One
    ":many" => Many
    ":exec" => Exec
    ":execrows" => ExecRows
    ":copyfrom" => CopyFrom
    ":batch" => Batch
    ":execlastid" => ExecLastId
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

/// A column-level type override: maps a specific table.column to a MoonBit type.
pub struct ColumnOverride {
  table : String
  column : String
  moonbit_type : String
}

/// Parsed plugin/global options from codegen configuration.
pub struct PluginOptions {
  /// Package name for generated code (e.g. "myapp" from codegen.options.package_name).
  package_name : String
  /// Type overrides: Array of (pg_type, moonbit_type) pairs.
  /// Parsed from lines like `override_int4=String` in plugin_options bytes.
  overrides : Array[(String, String)]
  /// Emit @json.tag("column_name") annotations on struct fields.
  emit_json_tags : Bool
  /// Emit @db.tag("column_name") annotations on struct fields.
  emit_db_tags : Bool
  /// Rename mappings: Array of (original_name, new_name) pairs.
  /// Parsed from lines like `rename_created_at=CreatedAt` in plugin_options bytes.
  renames : Array[(String, String)]
  /// Emit SQL as doc comment above generated functions (default: true).
  emit_sql_as_comment : Bool
  /// Omit structs not referenced by any query (default: false).
  omit_unused_structs : Bool
  /// When true, return empty array instead of error for :many with no rows (default: false).
  emit_empty_slices : Bool
  /// Comma-separated list of initialisms (e.g. "ID,URL,HTTP") for naming conversion (default: "").
  initialisms : String
  /// Case style for JSON tags: "snake", "camel", "pascal" (default: "snake").
  json_tags_case_style : String
  /// Use exact table names instead of singularized form for struct names (default: false).
  emit_exact_table_names : Bool
  /// Generate standalone functions accepting DB as argument instead of method receivers (default: false).
  emit_methods_with_db_argument : Bool
  /// Column-level overrides: Array of ColumnOverride, parsed from `override_column_<table>.<column>=<MoonBitType>`.
  column_overrides : Array[ColumnOverride]
  /// PG type names to always treat as nullable, parsed from `override_nullable_<pg_type>=true`.
  nullable_overrides : Array[String]
}

/// Find first occurrence of a character in a string.
fn find_char(s: String, c: Char) -> Option[Int] {
  let n = s.length()
  let target = c.to_int()
  for i = 0; i < n; i = i + 1 {
    if s[i].to_int() == target { return Some(i) }
  }
  None
}

/// Parse plugin_options bytes into a PluginOptions struct.
/// Silently returns defaults on empty data or parse failure.
pub fn parse_plugin_options(data: Bytes) -> PluginOptions raise {
  if data.length() == 0 {
    return {
      package_name: "",
      overrides: [],
      emit_json_tags: false,
      emit_db_tags: false,
      renames: [],
      emit_sql_as_comment: true,
      omit_unused_structs: false,
      emit_empty_slices: false,
      initialisms: "",
      json_tags_case_style: "snake",
      emit_exact_table_names: false,
      emit_methods_with_db_argument: false,
      column_overrides: [],
      nullable_overrides: [],
    }
  }
  let text = @utf8.decode_lossy(data[:])
  let mut package_name = ""
  let mut has_package_name = false
  let overrides: Array[(String, String)] = []
  let renames: Array[(String, String)] = []
  let mut emit_json_tags = false
  let mut emit_db_tags = false
  let mut emit_sql_as_comment = true
  let mut omit_unused_structs = false
  let mut emit_empty_slices = false
  let mut initialisms = ""
  let mut json_tags_case_style = "snake"
  let mut emit_exact_table_names = false
  let mut emit_methods_with_db_argument = false
  let column_overrides: Array[ColumnOverride] = []
  let nullable_overrides: Array[String] = []
  for line in text.split("\n") {
    let s = line.trim().to_owned()
    if s.has_prefix("package_name=") {
      if has_package_name {
        debug_inspect("duplicate package_name option: keeping last value")
      }
      package_name = s[13:].trim().to_owned()
      has_package_name = true
    } else if s.has_prefix("package_name =") {
      if has_package_name {
        debug_inspect("duplicate package_name option: keeping last value")
      }
      package_name = s[14:].trim().to_owned()
      has_package_name = true
    } else if s.has_prefix("package=") {
      if has_package_name {
        debug_inspect("duplicate package_name option: keeping last value")
      }
      package_name = s[8:].trim().to_owned()
      has_package_name = true
    } else if s.has_prefix("package =") {
      if has_package_name {
        debug_inspect("duplicate package_name option: keeping last value")
      }
      package_name = s[9:].trim().to_owned()
      has_package_name = true
    } else if s.has_prefix("override_column_") {
      let eq_pos = find_char(s, '=')
      match eq_pos {
        Some(pos) => {
          let key = s[16:pos].trim().to_owned()
          let moon_type = s[pos + 1:].trim().to_owned()
          let dot_pos = key.rev_find(".")
          match dot_pos {
            Some(d) => {
              let table = key[:d].to_owned()
              let column = key[d + 1:].to_owned()
              column_overrides.push({ table: table, column: column, moonbit_type: moon_type })
            }
            None => ()
          }
        }
        None => ()
      }
    } else if s.has_prefix("override_nullable_") {
      let eq_pos = find_char(s, '=')
      match eq_pos {
        Some(pos) => {
          let pg_type = s[18:pos].trim().to_owned()
          let val = s[pos + 1:].trim().to_owned()
          if val == "true" { nullable_overrides.push(pg_type.to_lower()) }
        }
        None => ()
      }
    } else if s.has_prefix("override_") {
      let eq_pos = find_char(s, '=')
      match eq_pos {
        Some(pos) => {
          let pg_type = s[9:pos].trim().to_owned()
          let moon_type = s[pos + 1:].trim().to_owned()
          overrides.push((pg_type.to_lower(), moon_type))
        }
        None => ()
      }
    } else if s.has_prefix("rename_") {
      let eq_pos = find_char(s, '=')
      match eq_pos {
        Some(pos) => {
          let key = s[7:pos].trim().to_owned()   // after "rename_"
          let val = s[pos + 1:].trim().to_owned()
          renames.push((key, val))
        }
        None => ()
      }
    } else if s == "emit_json_tags=true" || s == "emit_json_tags = true" {
      emit_json_tags = true
    } else if s == "emit_json_tags=false" || s == "emit_json_tags = false" {
      emit_json_tags = false
    } else if s == "emit_db_tags=true" || s == "emit_db_tags = true" {
      emit_db_tags = true
    } else if s == "emit_db_tags=false" || s == "emit_db_tags = false" {
      emit_db_tags = false
    } else if s == "emit_sql_as_comment=true" || s == "emit_sql_as_comment = true" {
      emit_sql_as_comment = true
    } else if s == "emit_sql_as_comment=false" || s == "emit_sql_as_comment = false" {
      emit_sql_as_comment = false
    } else if s == "omit_unused_structs=true" || s == "omit_unused_structs = true" {
      omit_unused_structs = true
    } else if s == "omit_unused_structs=false" || s == "omit_unused_structs = false" {
      omit_unused_structs = false
    } else if s == "emit_empty_slices=true" || s == "emit_empty_slices = true" {
      emit_empty_slices = true
    } else if s == "emit_empty_slices=false" || s == "emit_empty_slices = false" {
      emit_empty_slices = false
    } else if s.has_prefix("initialisms=") {
      initialisms = s[12:].trim().to_owned()
    } else if s.has_prefix("initialisms =") {
      initialisms = s[13:].trim().to_owned()
    } else if s.has_prefix("json_tags_case_style=") {
      json_tags_case_style = s[21:].trim().to_owned()
    } else if s.has_prefix("json_tags_case_style =") {
      json_tags_case_style = s[22:].trim().to_owned()
    } else if s.has_prefix("query_parameter_limit =") {
    } else if s == "emit_exact_table_names=true" || s == "emit_exact_table_names = true" {
      emit_exact_table_names = true
    } else if s == "emit_exact_table_names=false" || s == "emit_exact_table_names = false" {
      emit_exact_table_names = false
    } else if s == "emit_methods_with_db_argument=true" || s == "emit_methods_with_db_argument = true" {
      emit_methods_with_db_argument = true
    } else if s == "emit_methods_with_db_argument=false" || s == "emit_methods_with_db_argument = false" {
      emit_methods_with_db_argument = false
    }
    // Support kebab-case variants for all new options
    else if s == "emit-json-tags=true" || s == "emit-json-tags = true" {
      emit_json_tags = true
    } else if s == "emit-json-tags=false" || s == "emit-json-tags = false" {
      emit_json_tags = false
    } else if s == "emit-db-tags=true" || s == "emit-db-tags = true" {
      emit_db_tags = true
    } else if s == "emit-db-tags=false" || s == "emit-db-tags = false" {
      emit_db_tags = false
    } else if s == "emit-sql-as-comment=true" || s == "emit-sql-as-comment = true" {
      emit_sql_as_comment = true
    } else if s == "emit-sql-as-comment=false" || s == "emit-sql-as-comment = false" {
      emit_sql_as_comment = false
    } else if s == "omit-unused-structs=true" || s == "omit-unused-structs = true" {
      omit_unused_structs = true
    } else if s == "omit-unused-structs=false" || s == "omit-unused-structs = false" {
      omit_unused_structs = false
    } else if s == "emit-empty-slices=true" || s == "emit-empty-slices = true" {
      emit_empty_slices = true
    } else if s == "emit-empty-slices=false" || s == "emit-empty-slices = false" {
      emit_empty_slices = false
    } else if s.has_prefix("json-tags-case-style=") {
      json_tags_case_style = s[21:].trim().to_owned()
    } else if s.has_prefix("json-tags-case-style =") {
      json_tags_case_style = s[22:].trim().to_owned()
    } else if s == "emit-exact-table-names=true" || s == "emit-exact-table-names = true" {
      emit_exact_table_names = true
    } else if s == "emit-exact-table-names=false" || s == "emit-exact-table-names = false" {
      emit_exact_table_names = false
    } else if s == "emit-methods-with-db-argument=true" || s == "emit-methods-with-db-argument = true" {
      emit_methods_with_db_argument = true
    } else if s == "emit-methods-with-db-argument=false" || s == "emit-methods-with-db-argument = false" {
      emit_methods_with_db_argument = false
    }
  }
  {
    package_name: package_name,
    overrides: overrides,
    emit_json_tags: emit_json_tags,
    emit_db_tags: emit_db_tags,
    renames: renames,
    emit_sql_as_comment: emit_sql_as_comment,
    omit_unused_structs: omit_unused_structs,
    emit_empty_slices: emit_empty_slices,
    initialisms: initialisms,
    json_tags_case_style: json_tags_case_style,
    emit_exact_table_names: emit_exact_table_names,
    emit_methods_with_db_argument: emit_methods_with_db_argument,
    column_overrides: column_overrides,
    nullable_overrides: nullable_overrides,
  }
}

// === Converters: raw protobuf types → internal model ===

fn convert_identifier(id: Identifier) -> AdaptIdentifier {
  { catalog: id.catalog, schema: id.schema, name: id.name }
}

/// Trim leading and trailing whitespace from a string.
/// MoonBit String currently lacks a @builtin trim, so we implement it manually.
fn trim_str(s: String) -> String {
  let mut start = 0
  let n = s.length()
  while start < n && (s[start] == ' ' || s[start] == '\t' || s[start] == '\n' || s[start] == '\r') {
    start = start + 1
  }
  let mut end = n
  while end > start && (s[end - 1] == ' ' || s[end - 1] == '\t' || s[end - 1] == '\n' || s[end - 1] == '\r') {
    end = end - 1
  }
  s[start:end].to_owned()
}

fn convert_column(col: Column) -> AdaptColumn {
  let col_name = if trim_str(col.name).length() == 0 { "column_unnamed" } else { col.name }
  {
    name: col_name,
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
  let q_name = if trim_str(q.name).length() == 0 { "unnamed_query" } else { q.name }
  {
    text: q.text,
    name: q_name,
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

test "parse_query_cmd: :copyfrom" {
  inspect(parse_query_cmd(":copyfrom"), content="CopyFrom")
}

test "parse_query_cmd: :batch" {
  inspect(parse_query_cmd(":batch"), content="Batch")
}

test "parse_query_cmd: :execlastid" {
  inspect(parse_query_cmd(":execlastid"), content="ExecLastId")
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

test "parse_plugin_options: empty bytes returns empty package_name" {
  let opts = parse_plugin_options(b"")
  inspect(opts.package_name, content="")
  inspect(opts.emit_json_tags, content="false")
  inspect(opts.emit_db_tags, content="false")
}

test "parse_plugin_options: package_name= prefix parsed" {
  let opts = parse_plugin_options(b"package_name=myapp")
  inspect(opts.package_name, content="myapp")
}

test "parse_plugin_options: package= prefix (short form) parsed" {
  let opts = parse_plugin_options(b"package=myapp")
  inspect(opts.package_name, content="myapp")
}

test "parse_plugin_options: package_name = with spaces parsed" {
  let opts = parse_plugin_options(b"package_name = spaced_name")
  inspect(opts.package_name, content="spaced_name")
}

test "parse_plugin_options: package = with spaces parsed" {
  let opts = parse_plugin_options(b"package = spaced_name")
  inspect(opts.package_name, content="spaced_name")
}

test "parse_plugin_options: unknown keys are ignored" {
  let opts = parse_plugin_options(b"unknown=val\npackage_name=myapp")
  inspect(opts.package_name, content="myapp")
}

test "parse_plugin_options: multiline with trailing newline" {
  let opts = parse_plugin_options(b"package_name=myapp\n")
  inspect(opts.package_name, content="myapp")
}

test "parse_plugin_options: emit_json_tags=true parsed" {
  let opts = parse_plugin_options(b"emit_json_tags=true")
  inspect(opts.emit_json_tags, content="true")
  inspect(opts.emit_db_tags, content="false")
}

test "parse_plugin_options: emit_db_tags=true parsed" {
  let opts = parse_plugin_options(b"emit_db_tags=true")
  inspect(opts.emit_db_tags, content="true")
  inspect(opts.emit_json_tags, content="false")
}

test "parse_plugin_options: emit_json_tags and emit_db_tags both true" {
  let opts = parse_plugin_options(b"emit_json_tags=true\nemit_db_tags=true")
  inspect(opts.emit_json_tags, content="true")
  inspect(opts.emit_db_tags, content="true")
}

test "parse_plugin_options: emit_json_tags=false by default" {
  let opts = parse_plugin_options(b"package_name=test")
  inspect(opts.emit_json_tags, content="false")
  inspect(opts.emit_db_tags, content="false")
}

test "parse_plugin_options: emit_json_tags = true with spaces parsed" {
  let opts = parse_plugin_options(b"emit_json_tags = true")
  inspect(opts.emit_json_tags, content="true")
}

test "parse_plugin_options: emit_db_tags = true with spaces parsed" {
  let opts = parse_plugin_options(b"emit_db_tags = true")
  inspect(opts.emit_db_tags, content="true")
}

test "parse_plugin_options: single override_ line parsed" {
  let opts = parse_plugin_options(b"package_name=testdb\noverride_numeric=Decimal")
  inspect(opts.package_name, content="testdb")
  inspect(opts.overrides.length(), content="1")
  inspect(opts.overrides[0].0, content="numeric")
  inspect(opts.overrides[0].1, content="Decimal")
}

test "parse_plugin_options: multiple override_ lines parsed" {
  let opts = parse_plugin_options(b"package_name=testdb\noverride_numeric=Decimal\noverride_int4=String\noverride_bool=Int64")
  inspect(opts.overrides.length(), content="3")
  inspect(opts.overrides[0].0, content="numeric")
  inspect(opts.overrides[0].1, content="Decimal")
  inspect(opts.overrides[1].0, content="int4")
  inspect(opts.overrides[1].1, content="String")
  inspect(opts.overrides[2].0, content="bool")
  inspect(opts.overrides[2].1, content="Int64")
}

test "parse_plugin_options: override with spaces around = works" {
  let opts = parse_plugin_options(b"package_name=testdb\noverride_numeric = Decimal")
  inspect(opts.overrides.length(), content="1")
  inspect(opts.overrides[0].0, content="numeric")
  inspect(opts.overrides[0].1, content="Decimal")
}

test "parse_plugin_options: override without = is silently skipped" {
  let opts = parse_plugin_options(b"override_numeric")
  inspect(opts.overrides.length(), content="0")
}

test "parse_plugin_options: empty bytes returns empty overrides" {
  let opts = parse_plugin_options(b"")
  inspect(opts.overrides.length(), content="0")
}

test "parse_plugin_options: only overrides without package_name" {
  let opts = parse_plugin_options(b"override_numeric=Decimal")
  inspect(opts.package_name, content="")
  inspect(opts.overrides.length(), content="1")
}

test "parse_plugin_options: override with spaces in value" {
  let opts = parse_plugin_options(b"override_int4 = Option[Int64]")
  inspect(opts.overrides.length(), content="1")
  inspect(opts.overrides[0].0, content="int4")
  inspect(opts.overrides[0].1, content="Option[Int64]")
}

test "parse_plugin_options: rename_ line parsed" {
  let opts = parse_plugin_options(b"package_name=testdb\nrename_created_at=CreatedAt\nrename_updated_at=UpdatedAt")
  inspect(opts.renames.length(), content="2")
  inspect(opts.renames[0].0, content="created_at")
  inspect(opts.renames[0].1, content="CreatedAt")
  inspect(opts.renames[1].0, content="updated_at")
  inspect(opts.renames[1].1, content="UpdatedAt")
}

test "parse_plugin_options: rename_ with spaces around = works" {
  let opts = parse_plugin_options(b"rename_created_at = CreatedAt")
  inspect(opts.renames.length(), content="1")
  inspect(opts.renames[0].0, content="created_at")
  inspect(opts.renames[0].1, content="CreatedAt")
}

test "parse_plugin_options: rename_ without = is silently skipped" {
  let opts = parse_plugin_options(b"rename_created_at")
  inspect(opts.renames.length(), content="0")
}

test "parse_plugin_options: empty bytes returns empty renames" {
  let opts = parse_plugin_options(b"")
  inspect(opts.renames.length(), content="0")
}

test "parse_plugin_options: unknown keys do not produce renames" {
  let opts = parse_plugin_options(b"rename_foo=bar\nunknown=val")
  inspect(opts.renames.length(), content="1")
  inspect(opts.renames[0].0, content="foo")
  inspect(opts.renames[0].1, content="bar")
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

// === P0-057: Plugin options inline tests ===

test "parse_plugin_options: emit_sql_as_comment=true parsed" {
  let opts = parse_plugin_options(b"emit_sql_as_comment=true")
  inspect(opts.emit_sql_as_comment, content="true")
}

test "parse_plugin_options: emit_sql_as_comment=false parsed" {
  let opts = parse_plugin_options(b"emit_sql_as_comment=false")
  inspect(opts.emit_sql_as_comment, content="false")
}

test "parse_plugin_options: omit_unused_structs=true parsed" {
  let opts = parse_plugin_options(b"omit_unused_structs=true")
  inspect(opts.omit_unused_structs, content="true")
}

test "parse_plugin_options: emit_empty_slices=true parsed" {
  let opts = parse_plugin_options(b"emit_empty_slices=true")
  inspect(opts.emit_empty_slices, content="true")
}

test "parse_plugin_options: initialisms=ID,URL,HTTP parsed" {
  let opts = parse_plugin_options(b"initialisms=ID,URL,HTTP")
  inspect(opts.initialisms, content="ID,URL,HTTP")
}

test "parse_plugin_options: initialisms with spaces parsed" {
  let opts = parse_plugin_options(b"initialisms = ID,URL,HTTP")
  inspect(opts.initialisms, content="ID,URL,HTTP")
}

test "parse_plugin_options: json_tags_case_style=camel parsed" {
  let opts = parse_plugin_options(b"json_tags_case_style=camel")
  inspect(opts.json_tags_case_style, content="camel")
}

test "parse_plugin_options: json_tags_case_style with spaces parsed" {
  let opts = parse_plugin_options(b"json_tags_case_style = pascal")
  inspect(opts.json_tags_case_style, content="pascal")
}

test "parse_plugin_options: emit_exact_table_names=true parsed" {
  let opts = parse_plugin_options(b"emit_exact_table_names=true")
  inspect(opts.emit_exact_table_names, content="true")
}

test "parse_plugin_options: emit_methods_with_db_argument=true parsed" {
  let opts = parse_plugin_options(b"emit_methods_with_db_argument=true")
  inspect(opts.emit_methods_with_db_argument, content="true")
}

test "parse_plugin_options: kebab-case emit-sql-as-comment=false parsed" {
  let opts = parse_plugin_options(b"emit-sql-as-comment=false")
  inspect(opts.emit_sql_as_comment, content="false")
}

test "parse_plugin_options: kebab-case omit-unused-structs=true parsed" {
  let opts = parse_plugin_options(b"omit-unused-structs=true")
  inspect(opts.omit_unused_structs, content="true")
}

test "parse_plugin_options: kebab-case emit-empty-slices=true parsed" {
  let opts = parse_plugin_options(b"emit-empty-slices=true")
  inspect(opts.emit_empty_slices, content="true")
}

test "parse_plugin_options: kebab-case json-tags-case-style=pascal parsed" {
  let opts = parse_plugin_options(b"json-tags-case-style=pascal")
  inspect(opts.json_tags_case_style, content="pascal")
}

test "parse_plugin_options: kebab-case emit-exact-table-names=true parsed" {
  let opts = parse_plugin_options(b"emit-exact-table-names=true")
  inspect(opts.emit_exact_table_names, content="true")
}

test "parse_plugin_options: kebab-case emit-methods-with-db-argument=true parsed" {
  let opts = parse_plugin_options(b"emit-methods-with-db-argument=true")
  inspect(opts.emit_methods_with_db_argument, content="true")
}

test "parse_plugin_options: kebab-case with spaces emit-sql-as-comment = false parsed" {
  let opts = parse_plugin_options(b"emit-sql-as-comment = false")
  inspect(opts.emit_sql_as_comment, content="false")
}

test "parse_plugin_options: kebab-case json-tags-case-style = camel parsed" {
  let opts = parse_plugin_options(b"json-tags-case-style = camel")
  inspect(opts.json_tags_case_style, content="camel")
}

test "parse_plugin_options: mixed combination emit_empty_slices + json_tags_case_style" {
  let opts = parse_plugin_options(b"emit_empty_slices=true\njson_tags_case_style=camel")
  inspect(opts.emit_empty_slices, content="true")
  inspect(opts.json_tags_case_style, content="camel")
}

test "parse_plugin_options: mixed combination kebab + snake" {
  let opts = parse_plugin_options(b"emit-empty-slices=true\njson_tags_case_style=pascal")
  inspect(opts.emit_empty_slices, content="true")
  inspect(opts.json_tags_case_style, content="pascal")
}

test "parse_plugin_options: all new options simultaneously" {
  let opts = parse_plugin_options(b"emit_sql_as_comment=false\nomit_unused_structs=true\nemit_empty_slices=true\ninitialisms=ID,URL\njson_tags_case_style=camel\nemit_exact_table_names=true\nemit_methods_with_db_argument=true")
  inspect(opts.emit_sql_as_comment, content="false")
  inspect(opts.omit_unused_structs, content="true")
  inspect(opts.emit_empty_slices, content="true")
  inspect(opts.initialisms, content="ID,URL")
  inspect(opts.json_tags_case_style, content="camel")
  inspect(opts.emit_exact_table_names, content="true")
  inspect(opts.emit_methods_with_db_argument, content="true")
}

test "parse_plugin_options: emit_sql_as_comment default true when not set" {
  let opts = parse_plugin_options(b"package_name=test")
  inspect(opts.emit_sql_as_comment, content="true")
}

test "parse_plugin_options: omit_unused_structs=false parsed (snake_case)" {
  let opts = parse_plugin_options(b"omit_unused_structs=false")
  inspect(opts.omit_unused_structs, content="false")
}

test "parse_plugin_options: emit_empty_slices=false parsed (snake_case)" {
  let opts = parse_plugin_options(b"emit_empty_slices=false")
  inspect(opts.emit_empty_slices, content="false")
}

test "parse_plugin_options: emit_exact_table_names=false parsed (snake_case)" {
  let opts = parse_plugin_options(b"emit_exact_table_names=false")
  inspect(opts.emit_exact_table_names, content="false")
}

test "parse_plugin_options: emit_methods_with_db_argument=false parsed (snake_case)" {
  let opts = parse_plugin_options(b"emit_methods_with_db_argument=false")
  inspect(opts.emit_methods_with_db_argument, content="false")
}

test "parse_plugin_options: omit-unused-structs=false parsed (kebab-case)" {
  let opts = parse_plugin_options(b"omit-unused-structs=false")
  inspect(opts.omit_unused_structs, content="false")
}

test "parse_plugin_options: emit-empty-slices=false parsed (kebab-case)" {
  let opts = parse_plugin_options(b"emit-empty-slices=false")
  inspect(opts.emit_empty_slices, content="false")
}

test "parse_plugin_options: emit-exact-table-names=false parsed (kebab-case)" {
  let opts = parse_plugin_options(b"emit-exact-table-names=false")
  inspect(opts.emit_exact_table_names, content="false")
}

test "parse_plugin_options: emit-methods-with-db-argument=false parsed (kebab-case)" {
  let opts = parse_plugin_options(b"emit-methods-with-db-argument=false")
  inspect(opts.emit_methods_with_db_argument, content="false")
}

test "parse_plugin_options: false branches do not override true values later" {
  // Setting false then true should result in true (last wins)
  let opts = parse_plugin_options(b"emit_empty_slices=false\nemit_empty_slices=true")
  inspect(opts.emit_empty_slices, content="true")
}

test "parse_plugin_options: true branches do not override false values later" {
  // Setting true then false should result in false (last wins)
  let opts = parse_plugin_options(b"emit_empty_slices=true\nemit_empty_slices=false")
  inspect(opts.emit_empty_slices, content="false")
}

test "parse_plugin_options: override_column_ single line parsed" {
  let opts = parse_plugin_options(b"override_column_users.id=String")
  inspect(opts.column_overrides.length(), content="1")
  inspect(opts.column_overrides[0].table, content="users")
  inspect(opts.column_overrides[0].column, content="id")
  inspect(opts.column_overrides[0].moonbit_type, content="String")
}

test "parse_plugin_options: override_column_ multiple lines parsed" {
  let opts = parse_plugin_options(b"override_column_users.id=String\noverride_column_posts.title=Int64")
  inspect(opts.column_overrides.length(), content="2")
  inspect(opts.column_overrides[0].table, content="users")
  inspect(opts.column_overrides[0].column, content="id")
  inspect(opts.column_overrides[0].moonbit_type, content="String")
  inspect(opts.column_overrides[1].table, content="posts")
  inspect(opts.column_overrides[1].column, content="title")
  inspect(opts.column_overrides[1].moonbit_type, content="Int64")
}

test "parse_plugin_options: override_column_ malformed no dot silently skipped" {
  let opts = parse_plugin_options(b"override_column_usersid=String")
  inspect(opts.column_overrides.length(), content="0")
}

test "parse_plugin_options: override_column_ with spaces around = works" {
  let opts = parse_plugin_options(b"override_column_users.id = String")
  inspect(opts.column_overrides.length(), content="1")
  inspect(opts.column_overrides[0].table, content="users")
  inspect(opts.column_overrides[0].column, content="id")
  inspect(opts.column_overrides[0].moonbit_type, content="String")
}

test "parse_plugin_options: override_column_ no = silently skipped" {
  let opts = parse_plugin_options(b"override_column_users.id")
  inspect(opts.column_overrides.length(), content="0")
}

test "parse_plugin_options: override_nullable_ true parsed" {
  let opts = parse_plugin_options(b"override_nullable_int4=true")
  inspect(opts.nullable_overrides.length(), content="1")
  inspect(opts.nullable_overrides[0], content="int4")
}

test "parse_plugin_options: override_nullable_ false ignored" {
  let opts = parse_plugin_options(b"override_nullable_int4=false")
  inspect(opts.nullable_overrides.length(), content="0")
}

test "parse_plugin_options: override_nullable_ multiple types parsed" {
  let opts = parse_plugin_options(b"override_nullable_int4=true\noverride_nullable_text=true")
  inspect(opts.nullable_overrides.length(), content="2")
  inspect(opts.nullable_overrides[0], content="int4")
  inspect(opts.nullable_overrides[1], content="text")
}

test "parse_plugin_options: override_nullable_ uppercase normalized to lowercase" {
  let opts = parse_plugin_options(b"override_nullable_INT4=true")
  inspect(opts.nullable_overrides.length(), content="1")
  inspect(opts.nullable_overrides[0], content="int4")
}

test "parse_plugin_options: override_column_ combined with other options" {
  let opts = parse_plugin_options(b"package_name=testdb\noverride_column_users.id=String\noverride_nullable_int4=true\noverride_numeric=Decimal")
  inspect(opts.package_name, content="testdb")
  inspect(opts.column_overrides.length(), content="1")
  inspect(opts.column_overrides[0].table, content="users")
  inspect(opts.column_overrides[0].moonbit_type, content="String")
  inspect(opts.nullable_overrides.length(), content="1")
  inspect(opts.nullable_overrides[0], content="int4")
  inspect(opts.overrides.length(), content="1")
  inspect(opts.overrides[0].0, content="numeric")
  inspect(opts.overrides[0].1, content="Decimal")
}

// === P0-066: Empty identifier fallback tests ===

test "P0-066: convert_column handles empty name" {
  let id: Identifier = { catalog: "", schema: "", name: "int4" }
  let tbl: Identifier = { catalog: "", schema: "public", name: "test_tbl" }
  let embed_tbl: Identifier = { catalog: "", schema: "", name: "" }
  let col = { name: "", not_null: true, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: tbl, table_alias: "", ty: id, is_sqlc_slice: false, embed_table: embed_tbl, original_name: "", unsigned: false, array_dims: 0 }
  let adapted = convert_column(col)
  inspect(adapted.name.length() > 0, content="true")
}

test "P0-066: convert_query handles empty name" {
  let id: Identifier = { catalog: "", schema: "", name: "int4" }
  let tbl: Identifier = { catalog: "", schema: "", name: "test_tbl" }
  let embed_tbl: Identifier = { catalog: "", schema: "", name: "" }
  let insert_tbl: Identifier = { catalog: "", schema: "", name: "" }
  let col = { name: "id", not_null: true, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: tbl, table_alias: "", ty: id, is_sqlc_slice: false, embed_table: embed_tbl, original_name: "id", unsigned: false, array_dims: 0 }
  let q = { text: "SELECT id FROM t", name: "", cmd: ":many", columns: [col], params: [], comments: [], filename: "test.sql", insert_into_table: insert_tbl }
  let adapted = convert_query(q)
  inspect(adapted.name.length() > 0, content="true")
}

test "P0-066: convert_column handles whitespace-only name" {
  let id: Identifier = { catalog: "", schema: "", name: "int4" }
  let tbl: Identifier = { catalog: "", schema: "public", name: "test_tbl" }
  let embed_tbl: Identifier = { catalog: "", schema: "", name: "" }
  let col = { name: "   ", not_null: true, is_array: false, comment: "", length: 0, is_named_param: false, is_func_call: false, scope: "", table: tbl, table_alias: "", ty: id, is_sqlc_slice: false, embed_table: embed_tbl, original_name: "   ", unsigned: false, array_dims: 0 }
  let adapted = convert_column(col)
  inspect(adapted.name.length() > 0, content="true")
}
