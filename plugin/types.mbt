///|
/// sqlc WASM plugin protocol types.
/// Mirrors protos/plugin/codegen.proto from sqlc-dev/sqlc.
pub struct File {
  name : String
  contents : Bytes
}

pub struct Settings {
  version : String
  engine : String
  schema : Array[String]
  queries : Array[String]
  codegen : Codegen
}

pub struct Codegen {
  out : String
  plugin : String
  options : Bytes
  env : Array[String]
  process : Option[CodegenProcess]
  wasm : Option[CodegenWASM]
}

pub struct CodegenProcess {
  cmd : String
}

pub struct CodegenWASM {
  url : String
  sha256 : String
}

pub struct Catalog {
  comment : String
  default_schema : String
  name : String
  schemas : Array[Schema]
}

pub struct Schema {
  comment : String
  name : String
  tables : Array[Table]
  enums : Array[Enum]
  composite_types : Array[CompositeType]
}

pub struct CompositeType {
  name : String
  comment : String
}

pub struct Enum {
  name : String
  vals : Array[String]
  comment : String
}

pub struct Table {
  rel : Identifier
  columns : Array[Column]
  comment : String
}

pub struct Identifier {
  catalog : String
  schema : String
  name : String
}

pub struct Column {
  name : String
  not_null : Bool
  is_array : Bool
  comment : String
  length : Int
  is_named_param : Bool
  is_func_call : Bool
  scope : String
  table : Identifier
  table_alias : String
  ty : Identifier
  is_sqlc_slice : Bool
  embed_table : Identifier
  original_name : String
  unsigned : Bool
  array_dims : Int
}

pub struct Query {
  text : String
  name : String
  cmd : String
  columns : Array[Column]
  params : Array[Parameter]
  comments : Array[String]
  filename : String
  insert_into_table : Identifier
}

pub struct Parameter {
  number : Int
  column : Column
}

pub struct GenerateRequest {
  settings : Settings
  catalog : Catalog
  queries : Array[Query]
  sqlc_version : String
  plugin_options : Bytes
  global_options : Bytes
}

pub struct GenerateResponse {
  files : Array[File]
}

test "File construction" {
  let f : File = { name : "test.txt", contents : b"hello" }
  inspect(f.name, content="test.txt")
}

test "Settings construction" {
  let cg : Codegen = { out : "gen", plugin : "test", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let s : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  inspect(s.engine, content="postgresql")
}

test "Catalog construction" {
  let schema : Schema = { comment : "", name : "public", tables : Array::make(0, { rel : { catalog : "", schema : "", name : "" }, columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : { catalog : "", schema : "", name : "" }, table_alias : "", ty : { catalog : "", schema : "", name : "" }, is_sqlc_slice : false, embed_table : { catalog : "", schema : "", name : "" }, original_name : "", unsigned : false, array_dims : 0 }), comment : "" }), enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let cat : Catalog = { comment : "", default_schema : "public", name : "test", schemas : [schema] }
  inspect(cat.name, content="test")
}

test "Column construction" {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let col : Column = {
    name : "id",
    not_null : true,
    is_array : false,
    comment : "",
    length : 0,
    is_named_param : false,
    is_func_call : false,
    scope : "",
    table : empty_id,
    table_alias : "",
    ty : empty_id,
    is_sqlc_slice : false,
    embed_table : empty_id,
    original_name : "id",
    unsigned : false,
    array_dims : 0,
  }
  inspect(col.name, content="id")
  inspect(col.not_null, content="true")
}

test "Query construction" {
  let id : Identifier = { catalog : "", schema : "", name : "users" }
  let q : Query = { text : "SELECT * FROM users", name : "list", cmd : ":many", columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : { catalog : "", schema : "", name : "" }, table_alias : "", ty : { catalog : "", schema : "", name : "" }, is_sqlc_slice : false, embed_table : { catalog : "", schema : "", name : "" }, original_name : "", unsigned : false, array_dims : 0 }), params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : { catalog : "", schema : "", name : "" }, table_alias : "", ty : { catalog : "", schema : "", name : "" }, is_sqlc_slice : false, embed_table : { catalog : "", schema : "", name : "" }, original_name : "", unsigned : false, array_dims : 0 } }), comments : Array::make(0, ""), filename : "query.sql", insert_into_table : id }
  inspect(q.name, content="list")
}

test "GenerateRequest construction" {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "", engine : "", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let schema : Schema = { comment : "", name : "", tables : Array::make(0, { rel : empty_id, columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 }), comment : "" }), enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "", name : "", schemas : [schema] }
  let req : GenerateRequest = { settings : settings, catalog : catalog, queries : Array::make(0, { text : "", name : "", cmd : "", columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 }), params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : Array::make(0, ""), filename : "", insert_into_table : empty_id }), sqlc_version : "1.0.0", plugin_options : b"", global_options : b"" }
  inspect(req.sqlc_version, content="1.0.0")
}

test "GenerateResponse construction" {
  let resp : GenerateResponse = { files : Array::make(0, { name : "", contents : b"" }) }
  inspect(resp.files.length(), content="0")
}
