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
  { settings : settings, catalog : catalog, queries : [q_list, q_get, q_del], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb\nemit_sql_as_comment=false", global_options : b"" }
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

/// Build a GenerateRequest covering array type columns (int[] and nullable text[]).
/// Tests that is_array=true columns produce Array[T] types in generated code.
pub fn make_array_types_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let tbl_rel : Identifier = { catalog : "", schema : "public", name : "array_test" }
  let int4_ty : Identifier = { catalog : "", schema : "", name : "int4" }
  let int4_array_ty : Identifier = { catalog : "", schema : "", name : "_int4" }
  let text_array_ty : Identifier = { catalog : "", schema : "", name : "_text" }
  let col_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_int_arr : Column = { name : "scores", not_null : true, is_array : true, comment : "integer array", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_array_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "scores", unsigned : false, array_dims : 1 }
  let col_text_arr : Column = { name : "labels", not_null : false, is_array : true, comment : "nullable text array", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_array_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "labels", unsigned : false, array_dims : 1 }
  let tbl : Table = { rel : tbl_rel, columns : [col_id, col_int_arr, col_text_arr], comment : "array test table" }
  let schema : Schema = { comment : "", name : "public", tables : [tbl], enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  let q_list : Query = { text : "SELECT id, scores, labels FROM array_test", name : "list_array_test", cmd : ":many", columns : [col_id, col_int_arr, col_text_arr], params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["List array columns"], filename : "array_test.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_list], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb", global_options : b"" }
}

/// Build a GenerateRequest with an enum type column in a table and query.
/// Tests enum type codegen path through the full pipeline.
pub fn make_enum_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let tbl_rel : Identifier = { catalog : "", schema : "public", name : "people" }
  let int4_ty : Identifier = { catalog : "", schema : "", name : "int4" }
  let text_ty : Identifier = { catalog : "", schema : "", name : "text" }
  let role_ty : Identifier = { catalog : "", schema : "public", name : "user_role" }
  let col_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_name : Column = { name : "name", not_null : true, is_array : false, comment : "person name", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "name", unsigned : false, array_dims : 0 }
  let col_role : Column = { name : "role", not_null : false, is_array : false, comment : "user role", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : role_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "role", unsigned : false, array_dims : 0 }
  let tbl : Table = { rel : tbl_rel, columns : [col_id, col_name, col_role], comment : "people table" }
  let role_enum : Enum = { name : "user_role", vals : ["admin", "editor", "viewer"], comment : "user role enum" }
  let schema : Schema = { comment : "", name : "public", tables : [tbl], enums : [role_enum], composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  let q_list : Query = { text : "SELECT id, name, role FROM people", name : "list_people", cmd : ":many", columns : [col_id, col_name, col_role], params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["List people with roles"], filename : "people.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_list], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb", global_options : b"" }
}

/// Build a GenerateRequest exercising :execrows, :copyfrom, :batch, and :execlastid commands.
/// Tests the command dispatch path through the full pipeline.
pub fn make_commands_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let tbl_rel : Identifier = { catalog : "", schema : "public", name : "commands_test" }
  let int4_ty : Identifier = { catalog : "", schema : "", name : "int4" }
  let text_ty : Identifier = { catalog : "", schema : "", name : "text" }
  let col_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_name : Column = { name : "name", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "name", unsigned : false, array_dims : 0 }
  let tbl : Table = { rel : tbl_rel, columns : [col_id, col_name], comment : "commands test table" }
  let schema : Schema = { comment : "", name : "public", tables : [tbl], enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  let param_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let param_name : Column = { name : "name", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "name", unsigned : false, array_dims : 0 }
  let q_execrows : Query = { text : "UPDATE commands_test SET name = $2 WHERE id = $1", name : "update_command", cmd : ":execrows", columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 }), params : [{ number : 1, column : param_id }, { number : 2, column : param_name }], comments : ["Update by ID"], filename : "commands.sql", insert_into_table : empty_id }
  let q_copyfrom : Query = { text : "COPY commands_test FROM stdin", name : "copy_command", cmd : ":copyfrom", columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 }), params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["Copy data from stdin"], filename : "commands.sql", insert_into_table : empty_id }
  let q_batch : Query = { text : "INSERT INTO commands_test (id, name) VALUES ($1, $2)", name : "batch_command", cmd : ":batch", columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 }), params : [{ number : 1, column : param_id }, { number : 2, column : param_name }], comments : ["Batch insert"], filename : "commands.sql", insert_into_table : empty_id }
  let q_execlastid : Query = { text : "INSERT INTO commands_test (name) VALUES ($1)", name : "insert_command", cmd : ":execlastid", columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 }), params : [{ number : 1, column : param_name }], comments : ["Insert with last ID"], filename : "commands.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_execrows, q_copyfrom, q_batch, q_execlastid], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb", global_options : b"" }
}

/// Build a GenerateRequest with multiple tables (users + posts) and a join query.
/// Tests multi-table scenarios through the full pipeline.
pub fn make_multi_table_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let int4_ty : Identifier = { catalog : "", schema : "", name : "int4" }
  let text_ty : Identifier = { catalog : "", schema : "", name : "text" }
  let users_tbl_rel : Identifier = { catalog : "", schema : "public", name : "users" }
  let posts_tbl_rel : Identifier = { catalog : "", schema : "public", name : "posts" }
  let col_u_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : users_tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_u_name : Column = { name : "name", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : users_tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "name", unsigned : false, array_dims : 0 }
  let col_p_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : posts_tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_p_title : Column = { name : "title", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : posts_tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "title", unsigned : false, array_dims : 0 }
  let col_p_author : Column = { name : "author_id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : posts_tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "author_id", unsigned : false, array_dims : 0 }
  let tbl_users : Table = { rel : users_tbl_rel, columns : [col_u_id, col_u_name], comment : "users table" }
  let tbl_posts : Table = { rel : posts_tbl_rel, columns : [col_p_id, col_p_title, col_p_author], comment : "posts table" }
  let schema : Schema = { comment : "", name : "public", tables : [tbl_users, tbl_posts], enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  // Users list query
  let q_users : Query = { text : "SELECT id, name FROM users", name : "list_users", cmd : ":many", columns : [col_u_id, col_u_name], params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["List all users"], filename : "users.sql", insert_into_table : empty_id }
  // Posts list query
  let q_posts : Query = { text : "SELECT id, title, author_id FROM posts", name : "list_posts", cmd : ":many", columns : [col_p_id, col_p_title, col_p_author], params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["List all posts"], filename : "posts.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_users, q_posts], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb", global_options : b"" }
}

/// Build a GenerateRequest with parameter-only queries (no table columns in result).
/// Tests the parameterized query codegen path.
pub fn make_parameterized_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let int4_ty : Identifier = { catalog : "", schema : "", name : "int4" }
  let text_ty : Identifier = { catalog : "", schema : "", name : "text" }
  let float8_ty : Identifier = { catalog : "", schema : "", name : "float8" }
  let schema : Schema = { comment : "", name : "public", tables : Array::make(0, { rel : empty_id, columns : Array::make(0, { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 }), comment : "" }), enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  // SELECT $1::int4 — parameter IS the result column
  let col_val : Column = { name : "value", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "value", unsigned : false, array_dims : 0 }
  let param_val : Column = { name : "value", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "value", unsigned : false, array_dims : 0 }
  let q_select_one : Query = { text : "SELECT $1::int4 AS value", name : "select_one", cmd : ":one", columns : [col_val], params : [{ number : 1, column : param_val }], comments : ["Select parameter as value"], filename : "param.sql", insert_into_table : empty_id }
  // SELECT $1::float8 + $2::float8 AS sum — multiple params producing a computed column
  let col_sum : Column = { name : "sum", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : float8_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "sum", unsigned : false, array_dims : 0 }
  let param_a : Column = { name : "a", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : float8_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "a", unsigned : false, array_dims : 0 }
  let param_b : Column = { name : "b", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : float8_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "b", unsigned : false, array_dims : 0 }
  let q_select_sum : Query = { text : "SELECT $1::float8 + $2::float8 AS sum", name : "select_sum", cmd : ":many", columns : [col_sum], params : [{ number : 1, column : param_a }, { number : 2, column : param_b }], comments : ["Select sum of two parameters"], filename : "param.sql", insert_into_table : empty_id }
  // SELECT $1::text AS greeting — text parameter as result
  let col_greeting : Column = { name : "greeting", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "greeting", unsigned : false, array_dims : 0 }
  let param_greeting : Column = { name : "greeting", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "greeting", unsigned : false, array_dims : 0 }
  let q_select_greeting : Query = { text : "SELECT $1::text AS greeting", name : "select_greeting", cmd : ":one", columns : [col_greeting], params : [{ number : 1, column : param_greeting }], comments : ["Select greeting from parameter"], filename : "param.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_select_one, q_select_sum, q_select_greeting], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb", global_options : b"" }
}

/// Build a GenerateRequest for P0-065 keyword escape golden tests.
/// Contains a column named "type" (MoonBit keyword) which must be escaped to "ty" in output.
pub fn make_keyword_test_request() -> GenerateRequest {
  let empty_id : Identifier = { catalog : "", schema : "", name : "" }
  let cg : Codegen = { out : "", plugin : "", options : b"", env : Array::make(0, ""), process : None, wasm : None }
  let settings : Settings = { version : "v1", engine : "postgresql", schema : Array::make(0, ""), queries : Array::make(0, ""), codegen : cg }
  let tbl_rel : Identifier = { catalog : "", schema : "public", name : "keyword_test" }
  let int4_ty : Identifier = { catalog : "", schema : "", name : "int4" }
  let text_ty : Identifier = { catalog : "", schema : "", name : "text" }
  let col_id : Column = { name : "id", not_null : true, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : int4_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "id", unsigned : false, array_dims : 0 }
  let col_type : Column = { name : "type", not_null : true, is_array : false, comment : "column named after MoonBit keyword", length : 0, is_named_param : false, is_func_call : false, scope : "", table : tbl_rel, table_alias : "", ty : text_ty, is_sqlc_slice : false, embed_table : empty_id, original_name : "type", unsigned : false, array_dims : 0 }
  let tbl : Table = { rel : tbl_rel, columns : [col_id, col_type], comment : "table with keyword column" }
  let schema : Schema = { comment : "", name : "public", tables : [tbl], enums : Array::make(0, { name : "", vals : Array::make(0, ""), comment : "" }), composite_types : Array::make(0, { name : "", comment : "" }) }
  let catalog : Catalog = { comment : "", default_schema : "public", name : "testdb", schemas : [schema] }
  let q_list : Query = { text : "SELECT id, type FROM keyword_test", name : "list_keyword_test", cmd : ":many", columns : [col_id, col_type], params : Array::make(0, { number : 0, column : { name : "", not_null : false, is_array : false, comment : "", length : 0, is_named_param : false, is_func_call : false, scope : "", table : empty_id, table_alias : "", ty : empty_id, is_sqlc_slice : false, embed_table : empty_id, original_name : "", unsigned : false, array_dims : 0 } }), comments : ["List keyword column rows"], filename : "keyword_test.sql", insert_into_table : empty_id }
  { settings : settings, catalog : catalog, queries : [q_list], sqlc_version : "1.0.0", plugin_options : b"package_name=testdb", global_options : b"" }
}

// === P1-043: New generator inline tests ===

test "P1-043: make_array_types_request has array columns" {
  let req = make_array_types_request()
  inspect(req.catalog.schemas.length(), content="1")
  let tbl = req.catalog.schemas[0].tables[0]
  inspect(tbl.columns.length(), content="3")
  inspect(tbl.columns[0].name, content="id")
  inspect(tbl.columns[0].is_array, content="false")
  inspect(tbl.columns[1].name, content="scores")
  inspect(tbl.columns[1].is_array, content="true")
  inspect(tbl.columns[2].name, content="labels")
  inspect(tbl.columns[2].is_array, content="true")
  inspect(tbl.columns[2].not_null, content="false")
  inspect(req.queries.length(), content="1")
  inspect(req.queries[0].cmd, content=":many")
}

test "P1-043: make_enum_request has enum type" {
  let req = make_enum_request()
  inspect(req.catalog.schemas[0].enums.length(), content="1")
  inspect(req.catalog.schemas[0].enums[0].name, content="user_role")
  inspect(req.catalog.schemas[0].enums[0].vals.length(), content="3")
  inspect(req.catalog.schemas[0].enums[0].vals[0], content="admin")
  let tbl = req.catalog.schemas[0].tables[0]
  inspect(tbl.columns.length(), content="3")
  inspect(tbl.columns[2].name, content="role")
  inspect(tbl.columns[2].ty.name, content="user_role")
  inspect(req.queries.length(), content="1")
}

test "P1-043: make_commands_request has all command types" {
  let req = make_commands_request()
  inspect(req.queries.length(), content="4")
  inspect(req.queries[0].cmd, content=":execrows")
  inspect(req.queries[0].name, content="update_command")
  inspect(req.queries[1].cmd, content=":copyfrom")
  inspect(req.queries[1].name, content="copy_command")
  inspect(req.queries[2].cmd, content=":batch")
  inspect(req.queries[2].name, content="batch_command")
  inspect(req.queries[3].cmd, content=":execlastid")
  inspect(req.queries[3].name, content="insert_command")
}

test "P1-043: make_multi_table_request has two tables" {
  let req = make_multi_table_request()
  let schema = req.catalog.schemas[0]
  inspect(schema.tables.length(), content="2")
  inspect(schema.tables[0].rel.name, content="users")
  inspect(schema.tables[0].columns.length(), content="2")
  inspect(schema.tables[1].rel.name, content="posts")
  inspect(schema.tables[1].columns.length(), content="3")
  inspect(req.queries.length(), content="2")
  inspect(req.queries[0].name, content="list_users")
  inspect(req.queries[1].name, content="list_posts")
}

test "P1-043: make_parameterized_request has only param queries" {
  let req = make_parameterized_request()
  inspect(req.queries.length(), content="3")
  inspect(req.queries[0].name, content="select_one")
  inspect(req.queries[0].cmd, content=":one")
  inspect(req.queries[0].params.length(), content="1")
  inspect(req.queries[1].name, content="select_sum")
  inspect(req.queries[1].cmd, content=":many")
  inspect(req.queries[1].params.length(), content="2")
  inspect(req.queries[2].name, content="select_greeting")
  inspect(req.queries[2].params.length(), content="1")
  // No tables in catalog for parameter-only queries
  inspect(req.catalog.schemas[0].tables.length(), content="0")
}
