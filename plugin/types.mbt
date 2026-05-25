///|
/// sqlc WASM plugin protocol types.
/// Mirrors protos/plugin/codegen.proto from sqlc-dev/sqlc.
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

/// Build a realistic GenerateRequest for golden tests.
pub fn make_users_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let tbl_rel : Identifier = { catalog : "", schema : "public", name : "users" }
  let int4_ty : Identifier = { catalog : "", schema : "", name : "int4" }
  let text_ty : Identifier = { catalog : "", schema : "", name : "text" }
  let col_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_name : Column = { name : "name", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "name", unsigned : false, array_dims : 0 }
  let col_email : Column = { name : "email", not_null : false, is_array : false, comment : "user email address", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "email", unsigned : false, array_dims : 0 }
  let tbl : Table = { rel : tbl_rel, columns : [col_id, col_name, col_email], comment : "users table" }
  let e : Enum = { name : "user_role", vals : ["admin", "editor", "viewer"], comment : "" }
  let schema : Schema = { comment : "", name : "public", tables : [tbl], enums : [e], composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  let q_list : Query = { text : "SELECT id, name, email FROM users", name : "list_users", cmd : ":many", columns : [col_id, col_name, col_email], params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["List all users"], filename : "users.sql", insert_into_table : empty_id }
  let param_col : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let q_get : Query = { text : "SELECT id, name, email FROM users WHERE id = $1", name : "get_user", cmd : ":one", columns : [col_id, col_name, col_email], params : [{ number : 1, column : param_col }], comments : ["Get user by ID"], filename : "users.sql", insert_into_table : empty_id }
  let param_del : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let q_del : Query = { text : "DELETE FROM users WHERE id = $1", name : "delete_user", cmd : ":exec", columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 }), params : [{ number : 1, column : param_del }], comments : Array::make(0, ""), filename : "users.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_list, q_get, q_del], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb", global_options : b"" }
}

/// Build a GenerateRequest with realistic sqlc input types: bigserial, schema-qualified,
/// array columns, and full type names like "timestamp with time zone".
pub fn make_realistic_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let tbl_rel : Identifier = { catalog : "", schema : "public", name : "posts" }
  let bigserial_ty : Identifier = { catalog : "", schema : "", name : "bigserial" }
  let pg_int8_ty : Identifier = { catalog : "", schema : "pg_catalog", name : "int8" }
  let text_ty : Identifier = { catalog : "", schema : "", name : "text" }
  let timestamptz_ty : Identifier = { catalog : "", schema : "", name : "timestamp with time zone" }
  let col_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : bigserial_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_author : Column = { name : "author_id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : pg_int8_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "author_id", unsigned : false, array_dims : 0 }
  let col_title : Column = { name : "title", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "title", unsigned : false, array_dims : 0 }
  let col_tags : Column = { name : "tags", not_null : false, is_array : true, comment : "post tags", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "tags", unsigned : false, array_dims : 0 }
  let col_created : Column = { name : "created_at", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : timestamptz_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "created_at", unsigned : false, array_dims : 0 }
  let tbl : Table = { rel : tbl_rel, columns : [col_id, col_author, col_title, col_tags, col_created], comment : "posts table" }
  let schema : Schema = { comment : "", name : "public", tables : [tbl], enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  let q_list : Query = { text : "SELECT id, author_id, title, tags, created_at FROM posts", name : "list_posts", cmd : ":many", columns : [col_id, col_author, col_title, col_tags, col_created], params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["List all posts"], filename : "posts.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_list], sqlc_version : "1.0.0", plugin_options : b"", global_options : b"" }
}

/// Build a GenerateRequest covering all PG types for comprehensive golden tests.
/// Includes bool, float8, bytea, date, timestamp, timestamptz, jsonb, numeric,
/// uuid, inet, int2, float4, time, interval, varchar, and text array.
pub fn make_all_types_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let tbl_rel : Identifier = { catalog : "", schema : "public", name : "all_types" }
  let int4_ty : Identifier = { catalog : "", schema : "", name : "int4" }
  let int2_ty : Identifier = { catalog : "", schema : "", name : "int2" }
  let float8_ty : Identifier = { catalog : "", schema : "", name : "float8" }
  let float4_ty : Identifier = { catalog : "", schema : "", name : "float4" }
  let bool_ty : Identifier = { catalog : "", schema : "", name : "bool" }
  let text_ty : Identifier = { catalog : "", schema : "", name : "text" }
  let bytea_ty : Identifier = { catalog : "", schema : "", name : "bytea" }
  let date_ty : Identifier = { catalog : "", schema : "", name : "date" }
  let timestamp_ty : Identifier = { catalog : "", schema : "", name : "timestamp" }
  let timestamptz_ty : Identifier = { catalog : "", schema : "", name : "timestamptz" }
  let jsonb_ty : Identifier = { catalog : "", schema : "", name : "jsonb" }
  let numeric_ty : Identifier = { catalog : "", schema : "", name : "numeric" }
  let uuid_ty : Identifier = { catalog : "", schema : "", name : "uuid" }
  let inet_ty : Identifier = { catalog : "", schema : "", name : "inet" }
  let varchar_ty : Identifier = { catalog : "", schema : "", name : "varchar" }
  let time_ty : Identifier = { catalog : "", schema : "", name : "time" }
  let interval_ty : Identifier = { catalog : "", schema : "", name : "interval" }
  let col_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_bool : Column = { name : "is_active", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : bool_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "is_active", unsigned : false, array_dims : 0 }
  let col_float8 : Column = { name : "score", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : float8_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "score", unsigned : false, array_dims : 0 }
  let col_bytea : Column = { name : "data", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : bytea_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "data", unsigned : false, array_dims : 0 }
  let col_date : Column = { name : "created_date", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : date_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "created_date", unsigned : false, array_dims : 0 }
  let col_ts : Column = { name : "created_at", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : timestamp_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "created_at", unsigned : false, array_dims : 0 }
  let col_tstz : Column = { name : "updated_at", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : timestamptz_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "updated_at", unsigned : false, array_dims : 0 }
  let col_jsonb : Column = { name : "metadata", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : jsonb_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "metadata", unsigned : false, array_dims : 0 }
  let col_numeric : Column = { name : "price", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : numeric_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "price", unsigned : false, array_dims : 0 }
  let col_uuid : Column = { name : "uid", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : uuid_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "uid", unsigned : false, array_dims : 0 }
  let col_inet : Column = { name : "device_ip", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : inet_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "device_ip", unsigned : false, array_dims : 0 }
  let col_int2 : Column = { name : "small_num", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int2_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "small_num", unsigned : false, array_dims : 0 }
  let col_float4 : Column = { name : "real_num", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : float4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "real_num", unsigned : false, array_dims : 0 }
  let col_varchar : Column = { name : "label", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : varchar_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "label", unsigned : false, array_dims : 0 }
  let col_time : Column = { name : "event_time", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : time_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "event_time", unsigned : false, array_dims : 0 }
  let col_interval : Column = { name : "duration", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : interval_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "duration", unsigned : false, array_dims : 0 }
  let col_tags : Column = { name : "tags", not_null : false, is_array : true, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "tags", unsigned : false, array_dims : 0 }
  let all_cols : Array[Column] = [col_id, col_bool, col_float8, col_bytea, col_date, col_ts, col_tstz, col_jsonb, col_numeric, col_uuid, col_inet, col_int2, col_float4, col_varchar, col_time, col_interval, col_tags]
  let tbl : Table = { rel : tbl_rel, columns : all_cols, comment : "all types table" }
  let schema : Schema = { comment : "", name : "public", tables : [tbl], enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  let q_list : Query = { text : "SELECT id, is_active, score, data, created_date, created_at, updated_at, metadata, price, uid, device_ip, small_num, real_num, label, event_time, duration, tags FROM all_types", name : "list_all_types", cmd : ":many", columns : all_cols, params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["List all types"], filename : "all_types.sql", insert_into_table : empty_id }
  let param_bool : Column = { name : "is_active", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : bool_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "is_active", unsigned : false, array_dims : 0 }
  let param_int4 : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let param_float8 : Column = { name : "score", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : float8_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "score", unsigned : false, array_dims : 0 }
  let param_text : Column = { name : "label", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : varchar_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "label", unsigned : false, array_dims : 0 }
  let q_get : Query = { text : "SELECT * FROM all_types WHERE id = $1 AND is_active = $2 AND score = $3 AND label = $4", name : "get_all_types", cmd : ":one", columns : all_cols, params : [{ number : 1, column : param_int4 }, { number : 2, column : param_bool }, { number : 3, column : param_float8 }, { number : 4, column : param_text }], comments : ["Get all types by params"], filename : "all_types.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_list, q_get], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb", global_options : b"" }
}
