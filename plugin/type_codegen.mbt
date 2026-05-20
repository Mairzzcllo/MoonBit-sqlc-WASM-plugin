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

/// Capitalize the first ASCII lowercase character.
fn capitalize_first(s: String) -> String {
  if s.length() == 0 { return s }
  let first = s[0]
  if first >= 'a' && first <= 'z' {
    let upper = (first.to_int() - 32).unsafe_to_char()
    [upper] + s[1:].to_owned()
  } else {
    s
  }
}

/// Convert snake_case to PascalCase.
pub fn snake_to_pascal(s: String) -> String {
  if s.length() == 0 { return "" }
  let parts = s.split("_")
  let mut result = ""
  for part in parts {
    result = result + capitalize_first(part.to_owned())
  }
  result
}

/// Generate a StructDef from a list of InternalFields.
/// Each field is mapped through the type mapping layer with nullability handling.
pub fn generate_struct_from_fields(
  type_name: String,
  fields: Array[InternalField],
  doc: Option[String],
  is_pub: Bool,
) -> StructDef {
  let field_defs = fields.map(fn(f) {
    let moon_type = map_internal_type_nullable(f.ty, f.not_null)
    let field_doc: Option[String] = if f.comment == "" { None } else { Some(f.comment) }
    { name: f.name, ty: moon_type, doc: field_doc }
  })
  { name: type_name, fields: field_defs, doc: doc, is_pub: is_pub }
}

/// Generate a StructDef from a catalog table.
pub fn generate_struct_from_table(table_name: String, columns: Array[AdaptColumn], comment: String) -> StructDef {
  let type_name = snake_to_pascal(table_name)
  let doc: Option[String] = if comment == "" { None } else { Some(comment) }
  let fields = columns.map(fn(c) {
    let ir_type = if c.is_array { Arr(Named(c.ty.name)) } else { Named(c.ty.name) }
    let moon_type = map_internal_type_nullable(ir_type, c.not_null)
    let field_doc: Option[String] = if c.comment == "" { None } else { Some(c.comment) }
    { name: c.name, ty: moon_type, doc: field_doc }
  })
  { name: type_name, fields: fields, doc: doc, is_pub: true }
}

/// Generate an EnumDef from a catalog enum.
pub fn generate_enum_from_enum(name: String, vals: Array[String], comment: String) -> EnumDef {
  let type_name = snake_to_pascal(name)
  let doc: Option[String] = if comment == "" { None } else { Some(comment) }
  let variants = vals.map(fn(v) { { name: snake_to_pascal(v), doc: (None: Option[String]) } })
  { name: type_name, variants: variants, doc: doc, is_pub: true }
}

/// Generate all type definitions from an AdaptCatalog.
/// Produces StructDef for each table (with decode method) and EnumDef for every enum.
pub fn generate_types_from_catalog(catalog: AdaptCatalog) -> Array[TopLevel] {
  let items: Array[TopLevel] = []
  for schema in catalog.schemas {
    for table in schema.tables {
      let sd = generate_struct_from_table(table.name, table.columns, table.comment)
      items.push(Struct(sd))
      items.push(Fn(generate_decode_fn(sd)))
    }
    for e in schema.enums {
      let ed = generate_enum_from_enum(e.name, e.vals, e.comment)
      items.push(Enum(ed))
    }
  }
  items
}

/// Generate struct definitions for query result types.
/// Produces a StructDef (with decode method) for each query that has a Rows result shape.
/// The struct is named `<QueryName>Row` in PascalCase.
pub fn generate_types_from_queries(queries: Array[InternalQuery]) -> Array[TopLevel] {
  let items: Array[TopLevel] = []
  for q in queries {
    match q.result_shape {
      Rows(fields) => {
        let type_name = snake_to_pascal(q.name) + "Row"
        let doc: Option[String] = if q.comments.length() > 0 { Some(q.comments[0]) } else { None }
        let sd = generate_struct_from_fields(type_name, fields, doc, true)
        items.push(Struct(sd))
        items.push(Fn(generate_decode_fn(sd)))
      }
      None => ()
    }
  }
  items
}

/// Generate all type definitions from both catalog and queries.
/// Each struct is followed by its decode method.
pub fn generate_types(catalog: AdaptCatalog, queries: Array[InternalQuery]) -> Array[TopLevel] {
  let items = generate_types_from_catalog(catalog)
  let query_items = generate_types_from_queries(queries)
  for item in query_items {
    items.push(item)
  }
  items
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
    _ => "string"
  }
}

/// Build a getter call expression for a field at a given index.
fn field_getter_call(field: FieldDef, _index: Int) -> (String, String) {
  let (suffix, nullable) = match field.ty {
    Named(s) => (type_to_getter_suffix(s), false)
    Option(inner) => {
      let inner_name = match inner {
        Named(n) => n
        Parameterized("Array", [Named(n)]) => n
        _ => "String"
      }
      (type_to_getter_suffix(inner_name), true)
    }
    Parameterized("Array", [_]) => ("string", true)
    _ => ("string", false)
  }
  let getter_name = if nullable {
    "row.get_nullable_" + suffix
  } else {
    "row.get_" + suffix
  }
  (getter_name, suffix)
}

/// Build a nested match expression for decoding all fields.
/// For N fields, produces N levels of nested match.
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
    let getter_call = Call(getter_name, [IntLit(i)])
    let ok_branch = Match(getter_call, [
      ("Ok(" + f.name + ")", build_decode_match(fields, i + 1)),
      ("Err(e)", Call("Err", [Ident("e")])),
    ])
    ok_branch
  }
}

/// Generate a decode function for a StructDef using typed getters.
/// Uses nested match instead of ? operator (not available in MoonBit 0.1).
pub fn generate_decode_fn(sd: StructDef) -> FnDef {
  let params = [{ name: "row", ty: TypeExpr::Named("Row") }]
  let return_ty = Parameterized("Result", [Named(sd.name), Named("DBError")])
  let body = [build_decode_match(sd.fields, 0)]
  let doc = Some("Decode a Row into a " + sd.name)
  { name: sd.name + "::decode", params: params, return_ty: return_ty, body: body, doc: doc, is_pub: true }
}

// === Tests ===

test "snake_to_pascal: single word" {
  inspect(snake_to_pascal("users"), content="Users")
}

test "snake_to_pascal: multi word" {
  inspect(snake_to_pascal("user_profiles"), content="UserProfiles")
}

test "snake_to_pascal: already PascalCase" {
  inspect(snake_to_pascal("Users"), content="Users")
}

test "snake_to_pascal: empty string" {
  inspect(snake_to_pascal(""), content="")
}

test "snake_to_pascal: single char" {
  inspect(snake_to_pascal("a"), content="A")
}

test "snake_to_pascal: leading underscore" {
  inspect(snake_to_pascal("_private"), content="Private")
}

test "snake_to_pascal: multiple underscores" {
  inspect(snake_to_pascal("blog_post_tags"), content="BlogPostTags")
}

test "generate_struct_from_fields: basic struct" {
  let fields: Array[InternalField] = [
    { name: "id", ty: Named("int4"), not_null: true, comment: "" },
    { name: "email", ty: Named("text"), not_null: false, comment: "user email" },
  ]
  let sd = generate_struct_from_fields("User", fields, Some("A user"), true)
  inspect(sd.name, content="User")
  inspect(sd.fields.length(), content="2")
  inspect(sd.fields[0].name, content="id")
  inspect(sd.fields[0].ty, content="Named(\"Int\")")
  inspect(sd.fields[1].name, content="email")
  inspect(sd.fields[1].ty, content="Option(Named(\"String\"))")
}

test "generate_struct_from_fields: array field" {
  let fields: Array[InternalField] = [
    { name: "tags", ty: Arr(Named("text")), not_null: true, comment: "" },
  ]
  let sd = generate_struct_from_fields("Post", fields, (None: Option[String]), true)
  inspect(sd.fields[0].ty, content="Parameterized(\"Array\", [Named(\"String\")])")
}

test "generate_struct_from_table: snake_case table name to PascalCase" {
  let cols: Array[AdaptColumn] = [
    { name: "id", not_null: true, is_array: false, ty: { catalog: "", schema: "", name: "int4" }, length: 0, comment: "", table: { catalog: "", schema: "public", name: "user_profiles" } },
  ]
  let sd = generate_struct_from_table("user_profiles", cols, "User profiles table")
  inspect(sd.name, content="UserProfiles")
  debug_inspect(sd.doc, content="Some(\"User profiles table\")")
  inspect(sd.fields[0].name, content="id")
  inspect(sd.fields[0].ty, content="Named(\"Int\")")
}

test "generate_struct_from_table: nullable column becomes Option" {
  let cols: Array[AdaptColumn] = [
    { name: "nickname", not_null: false, is_array: false, ty: { catalog: "", schema: "", name: "text" }, length: 0, comment: "", table: { catalog: "", schema: "public", name: "users" } },
  ]
  let sd = generate_struct_from_table("users", cols, "")
  inspect(sd.fields[0].ty, content="Option(Named(\"String\"))")
}

test "generate_struct_from_table: array column becomes Array[T]" {
  let cols: Array[AdaptColumn] = [
    { name: "tags", not_null: true, is_array: true, ty: { catalog: "", schema: "", name: "text" }, length: 0, comment: "", table: { catalog: "", schema: "public", name: "posts" } },
  ]
  let sd = generate_struct_from_table("posts", cols, "")
  inspect(sd.fields[0].ty, content="Parameterized(\"Array\", [Named(\"String\")])")
}

test "generate_enum_from_enum: basic enum" {
  let ed = generate_enum_from_enum("mood", ["happy", "sad", "neutral"], "User mood")
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
  let items = generate_types_from_catalog(catalog)
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
  let items = generate_types_from_catalog(catalog)
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
    { name: "id", ty: Named("int4"), not_null: true, comment: "" },
    { name: "name", ty: Named("text"), not_null: false, comment: "" },
  ]
  let q: InternalQuery = {
    name: "list_users",
    text: "SELECT * FROM users",
    cmd: ManyRows,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: Rows(fields),
    comments: ["List all users"],
    filename: "query.sql",
  }
  let items = generate_types_from_queries([q])
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
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: (None: InternalResultShape),
    comments: Array::make(0, ""),
    filename: "q.sql",
  }
  let items = generate_types_from_queries([q])
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
    { name: "id", ty: Named("int4"), not_null: true, comment: "" },
  ]
  let q: InternalQuery = {
    name: "get_user",
    text: "SELECT * FROM users",
    cmd: OneRow,
    params: Array::make(0, { number: 0, name: "", ty: Named(""), not_null: false }),
    result_shape: Rows(fields),
    comments: Array::make(0, ""),
    filename: "q.sql",
  }
  let items = generate_types(catalog, [q])
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

test "capitalize_first: lowercase letter" {
  inspect(snake_to_pascal("hello"), content="Hello")
}

test "generate_struct_from_fields: int8 maps to Int64" {
  let fields: Array[InternalField] = [
    { name: "big_id", ty: Named("int8"), not_null: true, comment: "" },
  ]
  let sd = generate_struct_from_fields("Big", fields, (None: Option[String]), true)
  inspect(sd.fields[0].ty, content="Named(\"Int64\")")
}
