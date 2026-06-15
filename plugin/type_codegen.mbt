///|
/// Type Code Generator — P0-008.
/// Generates MoonBit struct/enum AST nodes from IR types and catalog data.
/// Handles nullable strategy (Option[T]) and naming conversion (snake_case → PascalCase).
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

/// Generate a StructDef from a list of InternalFields.
/// Each field is mapped through the type mapping layer with nullability handling.
pub fn generate_struct_from_fields(
  type_name: String,
  fields: Array[InternalField],
  doc: Option[String],
  is_pub: Bool,
  emit_json_tags: Bool,
  emit_db_tags: Bool,
  overrides: Array[(String, String)],
  nullable_overrides: Array[String],
  json_tags_case_style: String,
  _initialisms: Array[String],
) -> StructDef {
  let field_defs = fields.map(fn(f) {
    let moon_type = map_internal_type_nullable(f.ty, f.not_null, overrides, nullable_overrides, [])
    let field_doc: Option[String] = if f.comment == "" { None } else { Some(f.comment) }
    let field_name = match f.rename_to {
      Some(r) => escape_keyword(r)
      None => escape_keyword(f.name)
    }
    // json_tag/db_tag use original column name (database column name), not renamed
    let tag_value = apply_case_style(f.name, json_tags_case_style)
    let json_tag: Option[String] = if emit_json_tags { Some(tag_value) } else { None }
    let db_tag: Option[String] = if emit_db_tags { Some(tag_value) } else { None }
    { name: field_name, col_name: f.name, ty: moon_type, doc: field_doc, json_tag: json_tag, db_tag: db_tag }
  })
  { name: type_name, fields: field_defs, doc: doc, is_pub: is_pub }
}

/// Generate a StructDef from a catalog table.
/// emit_exact_table_names is accepted for API compatibility. Currently the struct name is
/// always PascalCase via snake_to_pascal(table_name). When proper singularization is added
/// in the future, emit_exact_table_names=true will skip singularization.
pub fn generate_struct_from_table(
  table_name: String,
  columns: Array[AdaptColumn],
  comment: String,
  emit_json_tags: Bool,
  emit_db_tags: Bool,
  overrides: Array[(String, String)],
  column_overrides: Array[ColumnOverride],
  nullable_overrides: Array[String],
  renames: Array[(String, String)],
  _emit_exact_table_names: Bool,
  json_tags_case_style: String,
  initialisms: Array[String],
  enum_renames: Array[(String, String)],
) -> StructDef {
  let type_name = escape_keyword(snake_to_pascal(table_name, initialisms))
  let doc: Option[String] = if comment == "" { None } else { Some(comment) }
  let fields = columns.map(fn(c) {
    let ir_type = if c.is_array { Arr(Named(c.ty.name)) } else { Named(c.ty.name) }
    let moon_type = match lookup_column_override(table_name, c.name, column_overrides) {
      Some(mapped) => {
        let base = TypeExpr::Named(mapped)
        if c.not_null {
          if is_nullable_override(c.ty.name, nullable_overrides) { Option(base) } else { base }
        } else {
          Option(base)
        }
      }
      None => map_internal_type_nullable(ir_type, c.not_null, overrides, nullable_overrides, enum_renames)
    }
    let field_doc: Option[String] = if c.comment == "" { None } else { Some(c.comment) }
    let rename_to = lookup_rename(c.name, renames)
    let field_name = match rename_to {
      Some(r) => escape_keyword(r)
      None => escape_keyword(c.name)
    }
    // json_tag/db_tag use original column name (database column name), not renamed
    let tag_value = apply_case_style(c.name, json_tags_case_style)
    let json_tag: Option[String] = if emit_json_tags { Some(tag_value) } else { None }
    let db_tag: Option[String] = if emit_db_tags { Some(tag_value) } else { None }
    { name: field_name, col_name: c.name, ty: moon_type, doc: field_doc, json_tag: json_tag, db_tag: db_tag }
  })
  { name: type_name, fields: fields, doc: doc, is_pub: true }
}

/// Generate an EnumDef from a catalog enum with an optional pre-resolved type name.
pub fn generate_enum_from_enum(_name: String, vals: Array[String], comment: String, initialisms: Array[String], type_name: String) -> EnumDef {
  let doc: Option[String] = if comment == "" { None } else { Some(comment) }
  let variants = vals.map(fn(v) { { name: escape_keyword(snake_to_pascal(v, initialisms)), doc: (None: Option[String]) } })
  { name: type_name, variants: variants, doc: doc, is_pub: true }
}

/// P1-060: pick a non-colliding enum type name when a struct already uses `base_pascal`.
fn disambiguate_enum_type_name(base_pascal: String, struct_names: Array[String]) -> String {
  if !struct_names.contains(base_pascal) { return base_pascal }
  let with_type = base_pascal + "Type"
  if !struct_names.contains(with_type) { return with_type }
  for n in 1..<100 {
    let candidate = base_pascal + n.to_string()
    if !struct_names.contains(candidate) { return candidate }
  }
  with_type
}

/// P1-060: build PG enum name → disambiguated MoonBit type name map for a schema.
fn build_enum_renames(schema: AdaptSchema, struct_names: Array[String], initialisms: Array[String]) -> Array[(String, String)] {
  let renames: Array[(String, String)] = []
  for e in schema.enums {
    let pascal = escape_keyword(snake_to_pascal(e.name, initialisms))
    let resolved = disambiguate_enum_type_name(pascal, struct_names)
    if resolved != pascal {
      renames.push((e.name.to_lower(), resolved))
    }
  }
  renames
}

/// Generate all type definitions from an AdaptCatalog.
/// Produces StructDef for each table (with decode method) and EnumDef for every enum.
/// When omit_unused_structs is true and referenced_tables is non-empty, only tables
/// whose names appear in the referenced_tables list are included.
pub fn generate_types_from_catalog(catalog: AdaptCatalog, emit_json_tags: Bool, emit_db_tags: Bool, overrides: Array[(String, String)], column_overrides: Array[ColumnOverride], nullable_overrides: Array[String], renames: Array[(String, String)], omit_unused_structs: Bool, referenced_tables: Array[String], emit_exact_table_names: Bool, json_tags_case_style: String, initialisms: Array[String]) -> Array[TopLevel] {
  catalog.schemas.map(fn(schema) {
    let tables_to_use = if omit_unused_structs && referenced_tables.length() > 0 {
      schema.tables.filter(fn(t) { referenced_tables.contains(t.name) })
    } else {
      schema.tables
    }
    let struct_names: Array[String] = []
    for table in tables_to_use {
      struct_names.push(escape_keyword(snake_to_pascal(table.name, initialisms)))
    }
    let enum_renames = build_enum_renames(schema, struct_names, initialisms)
    let table_items = tables_to_use.map(fn(table) {
      let sd = generate_struct_from_table(table.name, table.columns, table.comment, emit_json_tags, emit_db_tags, overrides, column_overrides, nullable_overrides, renames, emit_exact_table_names, json_tags_case_style, initialisms, enum_renames)
      [Struct(sd), Fn(generate_decode_fn(sd))]
    }).flatten()
    let enum_items = schema.enums.map(fn(e) {
      let pascal = escape_keyword(snake_to_pascal(e.name, initialisms))
      let resolved = disambiguate_enum_type_name(pascal, struct_names)
      Enum(generate_enum_from_enum(e.name, e.vals, e.comment, initialisms, resolved))
    })
    table_items + enum_items
  }).flatten()
}

/// Generate struct definitions for query result types.
/// Produces a StructDef (with decode method) for each query that has a Rows result shape.
/// The struct is named `<QueryName>Row` in PascalCase.
pub fn generate_types_from_queries(queries: Array[InternalQuery], emit_json_tags: Bool, emit_db_tags: Bool, overrides: Array[(String, String)], nullable_overrides: Array[String], json_tags_case_style: String, initialisms: Array[String]) -> Array[TopLevel] {
  queries.map(fn(q) {
    match q.result_shape {
      Rows(fields) => {
        let type_name = escape_keyword(snake_to_pascal(q.name, initialisms) + "Row")
        let doc: Option[String] = if q.comments.length() > 0 { Some(q.comments[0]) } else { None }
        let sd = generate_struct_from_fields(type_name, fields, doc, true, emit_json_tags, emit_db_tags, overrides, nullable_overrides, json_tags_case_style, initialisms)
        [Struct(sd), Fn(generate_decode_fn(sd))]
      }
      None => []
    }
  }).flatten()
}

/// Collect all table names referenced by query columns from adapter queries.
fn collect_referenced_table_names(queries: Array[AdaptQuery]) -> Array[String] {
  let names: Array[String] = []
  for q in queries {
    for c in q.columns {
      let tbl_name = c.table.name
      if tbl_name.length() > 0 && !names.contains(tbl_name) {
        names.push(tbl_name)
      }
    }
  }
  names
}

/// Generate all type definitions from both catalog and queries.
/// Each struct is followed by its decode method.
pub fn generate_types(catalog: AdaptCatalog, queries: Array[InternalQuery], adapt_queries: Array[AdaptQuery], emit_json_tags: Bool, emit_db_tags: Bool, overrides: Array[(String, String)], column_overrides: Array[ColumnOverride], nullable_overrides: Array[String], renames: Array[(String, String)], omit_unused_structs: Bool, emit_exact_table_names: Bool, json_tags_case_style: String, initialisms_str: String) -> Array[TopLevel] {
  let parsed_initialisms = parse_initialisms(initialisms_str)
  let referenced_tables = collect_referenced_table_names(adapt_queries)
  generate_types_from_catalog(catalog, emit_json_tags, emit_db_tags, overrides, column_overrides, nullable_overrides, renames, omit_unused_structs, referenced_tables, emit_exact_table_names, json_tags_case_style, parsed_initialisms) + generate_types_from_queries(queries, emit_json_tags, emit_db_tags, overrides, nullable_overrides, json_tags_case_style, parsed_initialisms)
}

/// Map a MoonBit struct type name to the corresponding typed getter suffix.
fn type_to_getter_suffix(type_name: String) -> String {
  match type_name {
    "Int64" => "int64"
    "Int" => "int64"
    "String" => "string"
    "Bool" => "bool"
    "Double" => "double"
    "Bytes" => "bytes"
    "JsonValue" => "json"
    "Date" => "date"
    "DateTime" => "datetime"
    "Decimal" => "decimal"
    "Uuid" => "uuid"
    "Duration" => "duration"
    "Time" => "time"
    "TimeTZ" => "timetz"
    "IpAddr" => "ipaddr"
    _ => "string"
  }
}

/// Build a getter call expression for a field at a given index.
fn field_getter_call(field: FieldDef, _index: Int) -> (String, String) {
  let (getter_name, suffix) = match field.ty {
    Named(s) => {
      let suffix = type_to_getter_suffix(s)
      ("row.get_" + suffix, suffix)
    }
    Option(inner) => {
      match inner {
        Parameterized("Array", [elem]) => {
          let inner_suffix = match elem {
            Named(n) => type_to_getter_suffix(n)
            _ => "string"
          }
          ("row.decode_nullable_array_" + inner_suffix, inner_suffix)
        }
        _ => {
          let inner_name = match inner {
            Named(n) => n
            _ => "String"
          }
          let suffix = type_to_getter_suffix(inner_name)
          ("row.get_nullable_" + suffix, suffix)
        }
      }
    }
    Parameterized("Array", [inner]) => {
      let inner_name = match inner {
        Named(n) => n
        _ => "String"
      }
      let suffix = type_to_getter_suffix(inner_name)
      ("row.decode_array_" + suffix, suffix)
    }
    _ => ("row.get_string", "string")
  }
  (getter_name, suffix)
}

/// Build the decode body using column name lookup (P0-063).
/// Each getter call uses `row.index_of("column_name")` as the index argument,
/// so column reordering does not break decoding.
pub fn build_decode_body(fields: Array[FieldDef]) -> Array[Expr] {
  [build_decode_match(fields, 0)]
}

/// Build a nested match expression for decoding all fields.
/// For N fields, produces 2N levels of nested match (one for index_of, one for getter).
/// P0-063: Uses `row.index_of("col_name")` with original DB column name for index lookups.
/// P0-062/064: Handles `row.index_of` returning `Result[Int, DBError]` via nested match.
fn build_decode_match(fields: Array[FieldDef], start_index: Int) -> Expr {
  let i = start_index
  if i >= fields.length() {
    // All fields decoded — build the Ok struct literal
    let mut literal_fields = ""
    let mut first = true
    for f in fields {
      if !first { literal_fields = literal_fields + ", " }
      literal_fields = literal_fields + f.name + ": " + f.name
      first = false
    }
    Call("Ok", [Ident("{ " + literal_fields + " }")])
  } else {
    let f = fields[i]
    let (getter_name, _) = field_getter_call(f, i)
    let idx_var = "_idx_" + i.to_string()
    // Match on row.index_of(original_column_name) — returns Result[Int, DBError]
    let index_call = Call("row.index_of", [StrLit(f.col_name)])
    let index_ok_body = {
      let getter_call = Call(getter_name, [Ident(idx_var)])
      Match(getter_call, [
        ("Ok(" + f.name + ")", build_decode_match(fields, i + 1)),
        ("Err(e)", Call("Err", [Ident("e")])),
      ])
    }
    Match(index_call, [
      ("Ok(" + idx_var + ")", index_ok_body),
      ("Err(e)", Call("Err", [Ident("e")])),
    ])
  }
}

/// Generate a decode function for a StructDef using typed getters.
/// Uses nested match instead of ? operator (not available in MoonBit 0.1).
/// P0-063: Uses `row.index_of("col_name")` with original DB column name.
/// Each field produces two nested match levels: one for index_of (Result[Int, DBError])
/// and one for the typed getter, so column reordering does not break decoding.
pub fn generate_decode_fn(sd: StructDef) -> FnDef {
  let params = [{ name: "row", ty: TypeExpr::Named("Row") }]
  let return_ty = Parameterized("Result", [Named(sd.name), Named("DBError")])
  let body = build_decode_body(sd.fields)
  let doc = Some("Decode a Row into a " + sd.name)
  { name: sd.name + "::decode", params: params, return_ty: return_ty, body: body, doc: doc, is_pub: true }
}

// === Tests ===

test "snake_to_pascal: single word" {
  inspect(snake_to_pascal("users", []), content="Users")
}

test "snake_to_pascal: multi word" {
  inspect(snake_to_pascal("user_profiles", []), content="UserProfiles")
}

test "snake_to_pascal: already PascalCase" {
  inspect(snake_to_pascal("Users", []), content="Users")
}

test "snake_to_pascal: empty string" {
  inspect(snake_to_pascal("", []), content="UnnamedType")
}

test "snake_to_pascal: single char" {
  inspect(snake_to_pascal("a", []), content="A")
}

test "snake_to_pascal: leading underscore" {
  inspect(snake_to_pascal("_private", []), content="Private")
}

test "snake_to_pascal: multiple underscores" {
  inspect(snake_to_pascal("blog_post_tags", []), content="BlogPostTags")
}

test "generate_struct_from_fields: basic struct" {
  let fields: Array[InternalField] = [
    { name: "id", ty: Named("int4"), not_null: true, comment: "", rename_to: (None: Option[String]) },
    { name: "email", ty: Named("text"), not_null: false, comment: "user email", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("User", fields, Some("A user"), true, false, false, [], [], "snake", [])
  inspect(sd.name, content="User")
  inspect(sd.fields.length(), content="2")
  inspect(sd.fields[0].name, content="id")
  inspect(sd.fields[0].ty, content="Named(\"Int64\")")
  inspect(sd.fields[1].name, content="email")
  inspect(sd.fields[1].ty, content="Option(Named(\"String\"))")
}

test "generate_struct_from_fields: array field" {
  let fields: Array[InternalField] = [
    { name: "tags", ty: Arr(Named("text")), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("Post", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  inspect(sd.fields[0].ty, content="Parameterized(\"Array\", [Named(\"String\")])")
}

test "generate_struct_from_table: snake_case table name to PascalCase" {
  let cols: Array[AdaptColumn] = [
    { name: "id", not_null: true, is_array: false, ty: { catalog: "", schema: "", name: "int4" }, length: 0, comment: "", table: { catalog: "", schema: "public", name: "user_profiles" } },
  ]
  let sd = generate_struct_from_table("user_profiles", cols, "User profiles table", false, false, [], [], [], [], false, "snake", [], [])
  inspect(sd.name, content="UserProfiles")
  debug_inspect(sd.doc, content="Some(\"User profiles table\")")
  inspect(sd.fields[0].name, content="id")
  inspect(sd.fields[0].ty, content="Named(\"Int64\")")
}

test "generate_struct_from_table: nullable column becomes Option" {
  let cols: Array[AdaptColumn] = [
    { name: "nickname", not_null: false, is_array: false, ty: { catalog: "", schema: "", name: "text" }, length: 0, comment: "", table: { catalog: "", schema: "public", name: "users" } },
  ]
  let sd = generate_struct_from_table("users", cols, "", false, false, [], [], [], [], false, "snake", [], [])
  inspect(sd.fields[0].ty, content="Option(Named(\"String\"))")
}

test "generate_struct_from_table: array column becomes Array[T]" {
  let cols: Array[AdaptColumn] = [
    { name: "tags", not_null: true, is_array: true, ty: { catalog: "", schema: "", name: "text" }, length: 0, comment: "", table: { catalog: "", schema: "public", name: "posts" } },
  ]
  let sd = generate_struct_from_table("posts", cols, "", false, false, [], [], [], [], false, "snake", [], [])
  inspect(sd.fields[0].ty, content="Parameterized(\"Array\", [Named(\"String\")])")
}

test "generate_enum_from_enum: basic enum" {
  let ed = generate_enum_from_enum("mood", ["happy", "sad", "neutral"], "User mood", [], "Mood")
  inspect(ed.name, content="Mood")
  inspect(ed.variants.length(), content="3")
  inspect(ed.variants[0].name, content="Happy")
  inspect(ed.variants[1].name, content="Sad")
}

test "generate_types_from_catalog: single schema with table" {
  let col: AdaptColumn = {
    name: "id", not_null: true, is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "users" },
  }
  let schema: AdaptSchema = {
    name: "public", comment: "",
    tables: [{ name: "users", schema: "public", columns: [col], comment: "" }],
    enums: [],
  }
  let catalog: AdaptCatalog = { name: "", default_schema: "public", schemas: [schema] }
  let items = generate_types_from_catalog(catalog, false, false, [], [], [], [], false, [], false, "snake", [])
  inspect(items.length(), content="2")
  let name = match items[0] {
    Struct(s) => s.name
    _ => ""
  }
  inspect(name, content="Users")
  let fn_name = match items[1] {
    Fn(f) => f.name
    _ => ""
  }
  inspect(fn_name, content="Users::decode")
}

test "generate_types_from_catalog: table and enum" {
  let col: AdaptColumn = {
    name: "id", not_null: true, is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "orders" },
  }
  let schema: AdaptSchema = {
    name: "public", comment: "",
    tables: [{ name: "orders", schema: "public", columns: [col], comment: "" }],
    enums: [{ name: "status", vals: ["pending", "shipped"], comment: "" }],
  }
  let catalog: AdaptCatalog = { name: "", default_schema: "public", schemas: [schema] }
  let items = generate_types_from_catalog(catalog, false, false, [], [], [], [], false, [], false, "snake", [])
  inspect(items.length(), content="3")
  let names = items.map(fn(item) {
    match item {
      Struct(s) => s.name
      Enum(e) => e.name
      Fn(f) => f.name
      _ => ""
    }
  })
  inspect(names[0], content="Orders")
  inspect(names[1], content="Orders::decode")
  inspect(names[2], content="Status")
}

test "generate_types_from_queries: :many query produces Row struct" {
  let fields: Array[InternalField] = [
    { name: "id", ty: Named("int4"), not_null: true, comment: "", rename_to: (None: Option[String]) },
    { name: "name", ty: Named("text"), not_null: false, comment: "", rename_to: (None: Option[String]) },
  ]
  let q: InternalQuery = {
    name: "list_users",
    text: "SELECT * FROM users",
    cmd: ManyRows,
    raw_cmd: Many,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: Rows(fields),
    comments: ["List all users"],
    filename: "query.sql",
  }
  let items = generate_types_from_queries([q], false, false, [], [], "snake", [])
  inspect(items.length(), content="2")
  let sd = match items[0] {
    Struct(s) => s
    _ => { name: "", fields: [], doc: (None: Option[String]), is_pub: false }
  }
  inspect(sd.name, content="ListUsersRow")
  inspect(sd.fields.length(), content="2")
  inspect(sd.fields[0].name, content="id")
  inspect(sd.fields[1].name, content="name")
  let fn_name = match items[1] {
    Fn(f) => f.name
    _ => ""
  }
  inspect(fn_name, content="ListUsersRow::decode")
}

test "generate_types_from_queries: :exec query produces no struct" {
  let q: InternalQuery = {
    name: "delete_user",
    text: "DELETE FROM users",
    cmd: ExecResult,
    raw_cmd: Exec,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""),
    filename: "q.sql",
  }
  let items = generate_types_from_queries([q], false, false, [], [], "snake", [])
  inspect(items.length(), content="0")
}

test "generate_types: combines catalog and query types" {
  let col: AdaptColumn = {
    name: "id", not_null: true, is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "users" },
  }
  let schema: AdaptSchema = {
    name: "public", comment: "",
    tables: [{ name: "users", schema: "public", columns: [col], comment: "" }],
    enums: [],
  }
  let catalog: AdaptCatalog = { name: "", default_schema: "public", schemas: [schema] }
  let fields: Array[InternalField] = [
    { name: "id", ty: Named("int4"), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let q: InternalQuery = {
    name: "get_user",
    text: "SELECT * FROM users",
    cmd: OneRow,
    raw_cmd: One,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: Rows(fields),
    comments: Array::make(0, ""),
    filename: "q.sql",
  }
  let items = generate_types(catalog, [q], [], false, false, [], [], [], [], false, false, "snake", "")
  inspect(items.length(), content="4")
  let first_name = match items[0] {
    Struct(s) => s.name
    _ => ""
  }
  let second_name = match items[1] {
    Fn(f) => f.name
    _ => ""
  }
  let third_name = match items[2] {
    Struct(s) => s.name
    _ => ""
  }
  let fourth_name = match items[3] {
    Fn(f) => f.name
    _ => ""
  }
  inspect(first_name, content="Users")
  inspect(second_name, content="Users::decode")
  inspect(third_name, content="GetUserRow")
  inspect(fourth_name, content="GetUserRow::decode")
}

test "snake_to_pascal with empty initialisms: single word" {
  inspect(snake_to_pascal("hello", []), content="Hello")
}

test "generate_struct_from_fields: int8 maps to Int64" {
  let fields: Array[InternalField] = [
    { name: "big_id", ty: Named("int8"), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("Big", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  inspect(sd.fields[0].ty, content="Named(\"Int64\")")
}

// === P0-065: Keyword escaping tests ===

test "P0-065: field name 'type' is escaped to 'ty'" {
  let fields: Array[InternalField] = [
    { name: "type", ty: Named("text"), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("User", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  inspect(sd.fields[0].name, content="ty")
}

test "P0-065: field name 'fn' is escaped to 'fn_'" {
  let fields: Array[InternalField] = [
    { name: "fn", ty: Named("text"), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("User", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  inspect(sd.fields[0].name, content="fn_")
}

test "P0-065: field name 'let' is escaped to 'let_'" {
  let fields: Array[InternalField] = [
    { name: "let", ty: Named("text"), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("User", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  inspect(sd.fields[0].name, content="let_")
}

test "P0-065: field name 'struct' is escaped to 'struct_'" {
  let fields: Array[InternalField] = [
    { name: "struct", ty: Named("text"), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("User", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  inspect(sd.fields[0].name, content="struct_")
}

test "P0-065: field name 'enum' is escaped to 'enum_'" {
  let fields: Array[InternalField] = [
    { name: "enum", ty: Named("text"), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("User", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  inspect(sd.fields[0].name, content="enum_")
}

test "P0-065: non-keyword field name passes through unchanged" {
  let fields: Array[InternalField] = [
    { name: "user_name", ty: Named("text"), not_null: true, comment: "", rename_to: (None: Option[String]) },
  ]
  let sd = generate_struct_from_fields("User", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  inspect(sd.fields[0].name, content="user_name")
}

test "P0-065: rename_to non-keyword value passes through" {
  let fields: Array[InternalField] = [
    { name: "type", ty: Named("text"), not_null: true, comment: "", rename_to: Some("kind") },
  ]
  let sd = generate_struct_from_fields("User", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  // "kind" is not a MoonBit keyword, so escape_keyword returns it unchanged
  inspect(sd.fields[0].name, content="kind")
}

test "P0-065: rename_to keyword value is escaped" {
  let fields: Array[InternalField] = [
    { name: "category", ty: Named("text"), not_null: true, comment: "", rename_to: Some("fn") },
  ]
  let sd = generate_struct_from_fields("User", fields, (None: Option[String]), true, false, false, [], [], "snake", [])
  // "fn" is a MoonBit keyword, so escape_keyword returns "fn_"
  inspect(sd.fields[0].name, content="fn_")
}

test "P0-065: enum variant 'self' is escaped to 'Self_'" {
  let ed = generate_enum_from_enum("status", ["active", "self", "pending"], "", [], "Status")
  inspect(ed.variants[1].name, content="Self_")
}

test "P0-065: struct type name that shadows built-in type is escaped" {
  let cols: Array[AdaptColumn] = [
    { name: "value", not_null: true, is_array: false, ty: { catalog: "", schema: "", name: "int4" }, length: 0, comment: "", table: { catalog: "", schema: "public", name: "int" } },
  ]
  let sd = generate_struct_from_table("int", cols, "", false, false, [], [], [], [], false, "snake", [], [])
  inspect(sd.name, content="Int_")
}

test "P0-065: struct type name 'Struct' passes through (Struct is not a keyword in MoonBit)" {
  let cols: Array[AdaptColumn] = [
    { name: "value", not_null: true, is_array: false, ty: { catalog: "", schema: "", name: "int4" }, length: 0, comment: "", table: { catalog: "", schema: "public", name: "struct" } },
  ]
  let sd = generate_struct_from_table("struct", cols, "", false, false, [], [], [], [], false, "snake", [], [])
  inspect(sd.name, content="Struct")
}

test "P0-065: enum type name that shadows built-in type is escaped" {
  let ed = generate_enum_from_enum("string", ["a", "b"], "", [], "String_")
  inspect(ed.name, content="String_")
}

test "P1-060: table and enum same name disambiguates enum with Type suffix" {
  let col: AdaptColumn = {
    name: "id", not_null: true, is_array: false,
    ty: { catalog: "", schema: "", name: "int4" },
    length: 0, comment: "",
    table: { catalog: "", schema: "public", name: "status" },
  }
  let schema: AdaptSchema = {
    name: "public", comment: "",
    tables: [{ name: "status", schema: "public", columns: [col], comment: "" }],
    enums: [{ name: "status", vals: ["active", "inactive"], comment: "" }],
  }
  let catalog: AdaptCatalog = { name: "db", default_schema: "public", schemas: [schema] }
  let items = generate_types_from_catalog(catalog, false, false, [], [], [], [], false, [], false, "snake", [])
  let mut has_struct = false
  let mut has_enum = false
  for item in items {
    match item {
      Struct(sd) => if sd.name == "Status" { has_struct = true }
      Enum(ed) => if ed.name == "StatusType" { has_enum = true }
      _ => ()
    }
  }
  inspect(has_struct, content="true")
  inspect(has_enum, content="true")
}
