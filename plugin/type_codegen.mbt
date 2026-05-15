///|
/// Type Code Generator — P0-008.
/// Generates MoonBit struct/enum AST nodes from IR types and catalog data.
/// Handles nullable strategy (Option[T]) and naming conversion (snake_case → PascalCase).

/// Capitalize the first ASCII lowercase byte of a string.
fn capitalize_first(s: String) -> String {
  if s.length() == 0 { return s }
  let bytes = s.to_bytes()
  let first = bytes[0]
  if first >= 97 && first <= 122 {
    let upper: Byte = (first.to_int() - 32).to_byte()
    let result = Bytes::makei(bytes.length(), fn(i) {
      if i == 0 { upper } else { bytes[i] }
    })
    result.to_unchecked_string()
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
    result = result + capitalize_first(part.to_string())
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
/// Produces StructDef for each table and EnumDef for each enum in every schema.
pub fn generate_types_from_catalog(catalog: AdaptCatalog) -> Array[TopLevel] {
  let items: Array[TopLevel] = []
  for schema in catalog.schemas {
    for table in schema.tables {
      let sd = generate_struct_from_table(table.name, table.columns, table.comment)
      items.push(Struct(sd))
    }
    for e in schema.enums {
      let ed = generate_enum_from_enum(e.name, e.vals, e.comment)
      items.push(Enum(ed))
    }
  }
  items
}

/// Generate struct definitions for query result types.
/// Produces a StructDef for each query that has a Rows result shape.
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
      }
      None => ()
    }
  }
  items
}

/// Generate all type definitions from both catalog and queries.
pub fn generate_types(catalog: AdaptCatalog, queries: Array[InternalQuery]) -> Array[TopLevel] {
  let items = generate_types_from_catalog(catalog)
  let query_items = generate_types_from_queries(queries)
  for item in query_items {
    items.push(item)
  }
  items
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
  inspect(sd.doc, content="Some(User profiles table)")
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
  inspect(items.length(), content="1")
  let name = match items[0] {
    Struct(s) => s.name
    _ => ""
  }
  inspect(name, content="Users")
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
  inspect(items.length(), content="2")
  let names = items.map(fn(item) {
    match item {
      Struct(s) => s.name
      Enum(e) => e.name
      _ => ""
    }
  })
  inspect(names[0], content="Orders")
  inspect(names[1], content="Status")
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
  inspect(items.length(), content="1")
  let sd = match items[0] {
    Struct(s) => s
    _ => { name: "", fields: [], doc: (None: Option[String]), is_pub: false }
  }
  inspect(sd.name, content="ListUsersRow")
  inspect(sd.fields.length(), content="2")
  inspect(sd.fields[0].name, content="id")
  inspect(sd.fields[1].name, content="name")
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
  inspect(items.length(), content="2")
  let first_name = match items[0] {
    Struct(s) => s.name
    _ => ""
  }
  let second_name = match items[1] {
    Struct(s) => s.name
    _ => ""
  }
  inspect(first_name, content="Users")
  inspect(second_name, content="GetUserRow")
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
