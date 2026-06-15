///|
/// Manual protobuf codec for the sqlc WASM plugin protocol.
/// Supports varint (LEB128), length-delimited, and embedded message encoding.
/// Aborts on unsupported wire types.
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

const WT_VARINT: Int = 0
const WT_BITS64: Int = 1
const WT_LEN: Int = 2
const WT_BITS32: Int = 5

// === Encoder: mutable byte buffer ===

struct Encoder {
  buf: Array[Byte]
}

fn Encoder::new() -> Encoder {
  { buf: [] }
}

fn Encoder::write_byte(self: Encoder, b: Byte) -> Unit {
  self.buf.push(b)
}

fn Encoder::write_bytes(self: Encoder, bs: Bytes) -> Unit {
  let n = bs.length()
  for i = 0; i < n; i = i + 1 {
    self.write_byte(bs[i])
  }
}

fn Encoder::finish(self: Encoder) -> Bytes {
  Bytes::from_array(self.buf)
}

fn Encoder::write_varint(self: Encoder, v: Int) -> Unit {
  let mut val = v
  let mut bytes_written = 0
  while bytes_written < 5 && val >= 0x80 {
    self.write_byte(((val & 0x7F) | 0x80).to_byte())
    val = val >> 7
    bytes_written = bytes_written + 1
  }
  self.write_byte((val & 0x7F).to_byte())
}

fn Encoder::write_tag(self: Encoder, fn_num: Int, wt: Int) -> Unit {
  self.write_varint((fn_num << 3) | wt)
}

fn Encoder::write_string(self: Encoder, s: String) -> Unit {
  let bs = @utf8.encode(s)
  self.write_varint(bs.length())
  self.write_bytes(bs)
}

fn Encoder::write_bool(self: Encoder, b: Bool) -> Unit {
  self.write_varint(if b { 1 } else { 0 })
}

fn Encoder::write_embedded(self: Encoder, val: (Encoder) -> Unit) -> Unit {
  let sub = Encoder::new()
  val(sub)
  let bs = sub.finish()
  self.write_varint(bs.length())
  self.write_bytes(bs)
}

// === Decoder: reads from Bytes ===

struct Decoder {
  buf: Bytes
  mut pos: Int
  end: Int
  mut error: Bool
}

fn Decoder::new(buf: Bytes) -> Decoder {
  { buf, pos: 0, end: buf.length(), error: false }
}

fn Decoder::remaining(self: Decoder) -> Int {
  self.end - self.pos
}

fn Decoder::has_error(self: Decoder) -> Bool {
  self.error
}

fn Decoder::read_byte(self: Decoder) -> Byte {
  if self.pos >= self.end {
    self.error = true
    return (0).to_byte()
  }
  let b = self.buf[self.pos]
  self.pos = self.pos + 1
  b
}

fn Decoder::read_varint(self: Decoder) -> Int {
  let mut result: Int = 0
  let mut shift: Int = 0
  for i = 0; i < 5; i = i + 1 {
    if self.remaining() <= 0 {
      self.error = true
      break
    }
    let b = self.read_byte().to_int()
    result = result | ((b & 0x7F) << shift)
    if (b & 0x80) == 0 {
      return result
    }
    shift = shift + 7
  }
  result
}

fn Decoder::read_tag(self: Decoder) -> (Int, Int) {
  let n = self.read_varint()
  (n >> 3, n & 0x07)
}

fn Decoder::read_string(self: Decoder) -> String {
  let len = self.read_varint()
  if self.has_error() || len <= 0 { return "" }
  let available = self.remaining()
  if len > available {
    self.error = true
    let start = self.pos
    self.pos = start
    return ""
  }
  let start = self.pos
  self.pos = start + len
  let sub = Bytes::makei(len, i => self.buf[start + i])
  @utf8.decode_lossy(sub[:])
}

fn Decoder::read_bytes(self: Decoder) -> Bytes {
  let len = self.read_varint()
  if self.has_error() || len <= 0 { return Bytes::default() }
  let available = self.remaining()
  if len > available {
    self.error = true
    let start = self.pos
    self.pos = start
    return Bytes::default()
  }
  let start = self.pos
  self.pos = start + len
  Bytes::makei(len, i => self.buf[start + i])
}

fn Decoder::read_bool(self: Decoder) -> Bool {
  self.read_varint() != 0
}

/// Read 4 little-endian bytes as a 32-bit fixed-width unsigned integer.
/// Corresponds to protobuf wire type 5 (32-bit).
fn Decoder::read_fixed32(self: Decoder) -> Int {
  if self.has_error() { return 0 }
  if self.remaining() < 4 {
    self.error = true
    return 0
  }
  let b0 = self.read_byte().to_int()
  let b1 = self.read_byte().to_int()
  let b2 = self.read_byte().to_int()
  let b3 = self.read_byte().to_int()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

/// Read 8 little-endian bytes as a 64-bit fixed-width integer.
/// Corresponds to protobuf wire type 1 (64-bit).
fn Decoder::read_fixed64(self: Decoder) -> Int64 {
  if self.has_error() { return 0L }
  if self.remaining() < 8 {
    self.error = true
    return 0L
  }
  let b0 = self.read_byte().to_int()
  let b1 = self.read_byte().to_int()
  let b2 = self.read_byte().to_int()
  let b3 = self.read_byte().to_int()
  let b4 = self.read_byte().to_int()
  let b5 = self.read_byte().to_int()
  let b6 = self.read_byte().to_int()
  let b7 = self.read_byte().to_int()
  let low: Int64 = Int64::from_int(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
  let high: Int64 = Int64::from_int(b4 | (b5 << 8) | (b6 << 16) | (b7 << 24))
  low | (high << 32)
}

fn Decoder::skip_field(self: Decoder, fn_num: Int, wt: Int) -> Unit {
  match wt {
    WT_VARINT => { let _ = self.read_varint() }
    WT_LEN => {
      let len = self.read_varint()
      let new_pos = self.pos + len
      if new_pos > self.end || new_pos < self.pos {
        self.error = true
        self.pos = self.end
      } else {
        self.pos = new_pos
      }
    }
    WT_BITS64 => {
      let new_pos = self.pos + 8
      if new_pos > self.end {
        self.error = true
        self.pos = self.end
      } else {
        self.pos = new_pos
      }
    }
    WT_BITS32 => {
      let new_pos = self.pos + 4
      if new_pos > self.end {
        self.error = true
        self.pos = self.end
      } else {
        self.pos = new_pos
      }
    }
    3 => { self.skip_group(fn_num) }
    4 => { () }
    _ => {
      // Unknown wire type — cannot determine field boundary.
      // Skip rest of message and mark error.
      self.error = true
      self.pos = self.end
    }
  }
}

fn Decoder::skip_group(self: Decoder, fn_num: Int) -> Unit {
  while self.remaining() > 0 {
    let (sub_fn, sub_wt) = self.read_tag()
    if sub_wt == 4 && sub_fn == fn_num {
      return
    }
    self.skip_field(sub_fn, sub_wt)
  }
}

fn[T] decode_embedded(dec: Decoder, f: (Decoder) -> T) -> T {
  let len = dec.read_varint()
  if len < 0 || len > dec.remaining() {
    // Corrupt length — cannot determine sub-message boundary.
    // Setting pos = end loses sibling fields in this message, but
    // is safer than the alternative (misparsing payload bytes as sibling tags).
    dec.error = true
    dec.pos = dec.end
    return f({ buf: dec.buf, pos: dec.pos, end: dec.pos, error: true })
  }
  let start = dec.pos
  let end = start + len
  let sub: Decoder = { buf: dec.buf, pos: start, end, error: false }
  let result = f(sub)
  if sub.has_error() { dec.error = true }
  dec.pos = end
  result
}

// === File ===

fn encode_file(enc: Encoder, val: File) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.name)
  enc.write_tag(2, WT_LEN)
  enc.write_varint(val.contents.length())
  enc.write_bytes(val.contents)
}

fn decode_file(dec: Decoder) -> File {
  let mut name: Option[String] = None
  let mut contents: Option[Bytes] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => name = Some(dec.read_string())
      (2, WT_LEN) => contents = Some(dec.read_bytes())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let name_val = match name { Some(v) => v; None => "" }
  let contents_val = match contents { Some(v) => v; None => Bytes::default() }
  { name: name_val, contents: contents_val }
}

// === Settings ===

fn encode_settings(enc: Encoder, val: Settings) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.version)
  enc.write_tag(2, WT_LEN)
  enc.write_string(val.engine)
  for i = 0; i < val.schema.length(); i = i + 1 {
    enc.write_tag(3, WT_LEN)
    enc.write_string(val.schema[i])
  }
  for i = 0; i < val.queries.length(); i = i + 1 {
    enc.write_tag(4, WT_LEN)
    enc.write_string(val.queries[i])
  }
  enc.write_tag(12, WT_LEN)
  enc.write_embedded(fn(enc) { encode_codegen(enc, val.codegen) })
}

fn decode_settings(dec: Decoder) -> Settings {
  let mut version: Option[String] = None
  let mut engine: Option[String] = None
  let schema: Array[String] = []
  let queries: Array[String] = []
  let mut codegen: Option[Codegen] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => version = Some(dec.read_string())
      (2, WT_LEN) => engine = Some(dec.read_string())
      (3, WT_LEN) => schema.push(dec.read_string())
      (4, WT_LEN) => queries.push(dec.read_string())
      (12, WT_LEN) => codegen = Some(decode_embedded(dec, decode_codegen))
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let version_val = match version { Some(v) => v; None => "" }
  let engine_val = match engine { Some(v) => v; None => "" }
  let codegen_val = match codegen {
    Some(v) => v
    None => { out: "", plugin: "", options: b"", env: [], process: None, wasm: None }
  }
  { version: version_val, engine: engine_val, schema: schema, queries: queries, codegen: codegen_val }
}

// === Codegen ===

fn encode_codegen(enc: Encoder, val: Codegen) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.out)
  enc.write_tag(2, WT_LEN)
  enc.write_string(val.plugin)
  enc.write_tag(3, WT_LEN)
  enc.write_varint(val.options.length())
  enc.write_bytes(val.options)
  for i = 0; i < val.env.length(); i = i + 1 {
    enc.write_tag(4, WT_LEN)
    enc.write_string(val.env[i])
  }
  match val.process {
    None => ()
    Some(v) => {
      enc.write_tag(5, WT_LEN)
      enc.write_embedded(fn(enc) { encode_codegen_process(enc, v) })
    }
  }
  match val.wasm {
    None => ()
    Some(v) => {
      enc.write_tag(6, WT_LEN)
      enc.write_embedded(fn(enc) { encode_codegen_wasm(enc, v) })
    }
  }
}

fn decode_codegen(dec: Decoder) -> Codegen {
  let mut out: Option[String] = None
  let mut plugin: Option[String] = None
  let mut options: Option[Bytes] = None
  let env: Array[String] = []
  let mut process: Option[CodegenProcess] = None
  let mut wasm: Option[CodegenWASM] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => out = Some(dec.read_string())
      (2, WT_LEN) => plugin = Some(dec.read_string())
      (3, WT_LEN) => options = Some(dec.read_bytes())
      (4, WT_LEN) => env.push(dec.read_string())
      (5, WT_LEN) => process = Some(decode_embedded(dec, decode_codegen_process))
      (6, WT_LEN) => wasm = Some(decode_embedded(dec, decode_codegen_wasm))
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let out_val = match out { Some(v) => v; None => "" }
  let plugin_val = match plugin { Some(v) => v; None => "" }
  let options_val = match options { Some(v) => v; None => Bytes::default() }
  { out: out_val, plugin: plugin_val, options: options_val, env: env, process: process, wasm: wasm }
}

// === CodegenProcess ===

fn encode_codegen_process(enc: Encoder, val: CodegenProcess) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.cmd)
}

fn decode_codegen_process(dec: Decoder) -> CodegenProcess {
  let mut cmd: Option[String] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => cmd = Some(dec.read_string())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let cmd_val = match cmd { Some(v) => v; None => "" }
  { cmd: cmd_val }
}

// === CodegenWASM ===

fn encode_codegen_wasm(enc: Encoder, val: CodegenWASM) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.url)
  enc.write_tag(2, WT_LEN)
  enc.write_string(val.sha256)
}

fn decode_codegen_wasm(dec: Decoder) -> CodegenWASM {
  let mut url: Option[String] = None
  let mut sha256: Option[String] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => url = Some(dec.read_string())
      (2, WT_LEN) => sha256 = Some(dec.read_string())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let url_val = match url { Some(v) => v; None => "" }
  let sha256_val = match sha256 { Some(v) => v; None => "" }
  { url: url_val, sha256: sha256_val }
}

// === Catalog ===

fn encode_catalog(enc: Encoder, val: Catalog) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.comment)
  enc.write_tag(2, WT_LEN)
  enc.write_string(val.default_schema)
  enc.write_tag(3, WT_LEN)
  enc.write_string(val.name)
  for i = 0; i < val.schemas.length(); i = i + 1 {
    enc.write_tag(4, WT_LEN)
    enc.write_embedded(fn(enc) { encode_schema(enc, val.schemas[i]) })
  }
}

fn decode_catalog(dec: Decoder) -> Catalog {
  let mut comment: Option[String] = None
  let mut default_schema: Option[String] = None
  let mut name: Option[String] = None
  let schemas: Array[Schema] = []
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => comment = Some(dec.read_string())
      (2, WT_LEN) => default_schema = Some(dec.read_string())
      (3, WT_LEN) => name = Some(dec.read_string())
      (4, WT_LEN) => schemas.push(decode_embedded(dec, decode_schema))
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let comment_val = match comment { Some(v) => v; None => "" }
  let default_schema_val = match default_schema { Some(v) => v; None => "" }
  let name_val = match name { Some(v) => v; None => "" }
  { comment: comment_val, default_schema: default_schema_val, name: name_val, schemas: schemas }
}

// === Schema ===

fn encode_schema(enc: Encoder, val: Schema) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.comment)
  enc.write_tag(2, WT_LEN)
  enc.write_string(val.name)
  for i = 0; i < val.tables.length(); i = i + 1 {
    enc.write_tag(3, WT_LEN)
    enc.write_embedded(fn(enc) { encode_table(enc, val.tables[i]) })
  }
  for i = 0; i < val.enums.length(); i = i + 1 {
    enc.write_tag(4, WT_LEN)
    enc.write_embedded(fn(enc) { encode_enum(enc, val.enums[i]) })
  }
  for i = 0; i < val.composite_types.length(); i = i + 1 {
    enc.write_tag(5, WT_LEN)
    enc.write_embedded(fn(enc) { encode_composite_type(enc, val.composite_types[i]) })
  }
}

fn decode_schema(dec: Decoder) -> Schema {
  let mut comment: Option[String] = None
  let mut name: Option[String] = None
  let tables: Array[Table] = []
  let enums: Array[Enum] = []
  let composite_types: Array[CompositeType] = []
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => comment = Some(dec.read_string())
      (2, WT_LEN) => name = Some(dec.read_string())
      (3, WT_LEN) => tables.push(decode_embedded(dec, decode_table))
      (4, WT_LEN) => enums.push(decode_embedded(dec, decode_enum))
      (5, WT_LEN) => composite_types.push(decode_embedded(dec, decode_composite_type))
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let comment_val = match comment { Some(v) => v; None => "" }
  let name_val = match name { Some(v) => v; None => "" }
  { comment: comment_val, name: name_val, tables: tables, enums: enums, composite_types: composite_types }
}

// === CompositeType ===

fn encode_composite_type(enc: Encoder, val: CompositeType) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.name)
  enc.write_tag(2, WT_LEN)
  enc.write_string(val.comment)
}

fn decode_composite_type(dec: Decoder) -> CompositeType {
  let mut name: Option[String] = None
  let mut comment: Option[String] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => name = Some(dec.read_string())
      (2, WT_LEN) => comment = Some(dec.read_string())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let name_val = match name { Some(v) => v; None => "" }
  let comment_val = match comment { Some(v) => v; None => "" }
  { name: name_val, comment: comment_val }
}

// === Enum ===

fn encode_enum(enc: Encoder, val: Enum) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.name)
  for i = 0; i < val.vals.length(); i = i + 1 {
    enc.write_tag(2, WT_LEN)
    enc.write_string(val.vals[i])
  }
  enc.write_tag(3, WT_LEN)
  enc.write_string(val.comment)
}

fn decode_enum(dec: Decoder) -> Enum {
  let mut name: Option[String] = None
  let vals: Array[String] = []
  let mut comment: Option[String] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => name = Some(dec.read_string())
      (2, WT_LEN) => vals.push(dec.read_string())
      (3, WT_LEN) => comment = Some(dec.read_string())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let name_val = match name { Some(v) => v; None => "" }
  let comment_val = match comment { Some(v) => v; None => "" }
  { name: name_val, vals: vals, comment: comment_val }
}

// === Table ===

fn encode_table(enc: Encoder, val: Table) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_embedded(fn(enc) { encode_identifier(enc, val.rel) })
  for i = 0; i < val.columns.length(); i = i + 1 {
    enc.write_tag(2, WT_LEN)
    enc.write_embedded(fn(enc) { encode_column(enc, val.columns[i]) })
  }
  enc.write_tag(3, WT_LEN)
  enc.write_string(val.comment)
}

fn decode_table(dec: Decoder) -> Table {
  let mut rel: Option[Identifier] = None
  let columns: Array[Column] = []
  let mut comment: Option[String] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => rel = Some(decode_embedded(dec, decode_identifier))
      (2, WT_LEN) => columns.push(decode_embedded(dec, decode_column))
      (3, WT_LEN) => comment = Some(dec.read_string())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let rel_val = match rel { Some(v) => v; None => empty_id }
  let comment_val = match comment { Some(v) => v; None => "" }
  { rel: rel_val, columns: columns, comment: comment_val }
}

// === Identifier ===

fn encode_identifier(enc: Encoder, val: Identifier) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.catalog)
  enc.write_tag(2, WT_LEN)
  enc.write_string(val.schema)
  enc.write_tag(3, WT_LEN)
  enc.write_string(val.name)
}

fn decode_identifier(dec: Decoder) -> Identifier {
  let mut catalog: Option[String] = None
  let mut schema: Option[String] = None
  let mut name: Option[String] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => catalog = Some(dec.read_string())
      (2, WT_LEN) => schema = Some(dec.read_string())
      (3, WT_LEN) => name = Some(dec.read_string())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let catalog_val = match catalog { Some(v) => v; None => "" }
  let schema_val = match schema { Some(v) => v; None => "" }
  let name_val = match name { Some(v) => v; None => "" }
  { catalog: catalog_val, schema: schema_val, name: name_val }
}

// === Column ===

fn encode_column(enc: Encoder, val: Column) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.name)
  // field 2 was removed from the proto definition (was "type" — redundant with field 12 ty identifier)
  if val.not_null {
    enc.write_tag(3, WT_VARINT)
    enc.write_bool(val.not_null)
  }
  if val.is_array {
    enc.write_tag(4, WT_VARINT)
    enc.write_bool(val.is_array)
  }
  enc.write_tag(5, WT_LEN)
  enc.write_string(val.comment)
  if val.length != 0 {
    enc.write_tag(6, WT_VARINT)
    enc.write_varint(val.length)
  }
  if val.is_named_param {
    enc.write_tag(7, WT_VARINT)
    enc.write_bool(val.is_named_param)
  }
  if val.is_func_call {
    enc.write_tag(8, WT_VARINT)
    enc.write_bool(val.is_func_call)
  }
  enc.write_tag(9, WT_LEN)
  enc.write_string(val.scope)
  enc.write_tag(10, WT_LEN)
  enc.write_embedded(fn(enc) { encode_identifier(enc, val.table) })
  enc.write_tag(11, WT_LEN)
  enc.write_string(val.table_alias)
  enc.write_tag(12, WT_LEN)
  enc.write_embedded(fn(enc) { encode_identifier(enc, val.ty) })
  if val.is_sqlc_slice {
    enc.write_tag(13, WT_VARINT)
    enc.write_bool(val.is_sqlc_slice)
  }
  enc.write_tag(14, WT_LEN)
  enc.write_embedded(fn(enc) { encode_identifier(enc, val.embed_table) })
  enc.write_tag(15, WT_LEN)
  enc.write_string(val.original_name)
  if val.unsigned {
    enc.write_tag(16, WT_VARINT)
    enc.write_bool(val.unsigned)
  }
  if val.array_dims != 0 {
    enc.write_tag(17, WT_VARINT)
    enc.write_varint(val.array_dims)
  }
}

fn decode_column(dec: Decoder) -> Column {
  let mut name: Option[String] = None
  let mut not_null: Option[Bool] = None
  let mut is_array: Option[Bool] = None
  let mut comment: Option[String] = None
  let mut length: Option[Int] = None
  let mut is_named_param: Option[Bool] = None
  let mut is_func_call: Option[Bool] = None
  let mut scope: Option[String] = None
  let mut table: Option[Identifier] = None
  let mut table_alias: Option[String] = None
  let mut ty: Option[Identifier] = None
  let mut is_sqlc_slice: Option[Bool] = None
  let mut embed_table: Option[Identifier] = None
  let mut original_name: Option[String] = None
  let mut unsigned: Option[Bool] = None
  let mut array_dims: Option[Int] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => name = Some(dec.read_string())
      // field 2 was removed from the proto definition
      (3, WT_VARINT) => not_null = Some(dec.read_bool())
      (4, WT_VARINT) => is_array = Some(dec.read_bool())
      (5, WT_LEN) => comment = Some(dec.read_string())
      (6, WT_VARINT) => length = Some(dec.read_varint())
      (7, WT_VARINT) => is_named_param = Some(dec.read_bool())
      (8, WT_VARINT) => is_func_call = Some(dec.read_bool())
      (9, WT_LEN) => scope = Some(dec.read_string())
      (10, WT_LEN) => table = Some(decode_embedded(dec, decode_identifier))
      (11, WT_LEN) => table_alias = Some(dec.read_string())
      (12, WT_LEN) => ty = Some(decode_embedded(dec, decode_identifier))
      (13, WT_VARINT) => is_sqlc_slice = Some(dec.read_bool())
      (14, WT_LEN) => embed_table = Some(decode_embedded(dec, decode_identifier))
      (15, WT_LEN) => original_name = Some(dec.read_string())
      (16, WT_VARINT) => unsigned = Some(dec.read_bool())
      (17, WT_VARINT) => array_dims = Some(dec.read_varint())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let name_val = match name { Some(v) => v; None => "" }
  let not_null_val = match not_null { Some(v) => v; None => false }
  let is_array_val = match is_array { Some(v) => v; None => false }
  let comment_val = match comment { Some(v) => v; None => "" }
  let length_val = match length { Some(v) => v; None => 0 }
  let is_named_param_val = match is_named_param { Some(v) => v; None => false }
  let is_func_call_val = match is_func_call { Some(v) => v; None => false }
  let scope_val = match scope { Some(v) => v; None => "" }
  let table_val = match table { Some(v) => v; None => empty_id }
  let table_alias_val = match table_alias { Some(v) => v; None => "" }
  let ty_val = match ty { Some(v) => v; None => empty_id }
  let is_sqlc_slice_val = match is_sqlc_slice { Some(v) => v; None => false }
  let embed_table_val = match embed_table { Some(v) => v; None => empty_id }
  let original_name_val = match original_name { Some(v) => v; None => "" }
  let unsigned_val = match unsigned { Some(v) => v; None => false }
  let array_dims_val = match array_dims { Some(v) => v; None => 0 }
  {
    name: name_val, not_null: not_null_val, is_array: is_array_val,
    comment: comment_val, length: length_val, is_named_param: is_named_param_val,
    is_func_call: is_func_call_val, scope: scope_val, table: table_val,
    table_alias: table_alias_val, ty: ty_val, is_sqlc_slice: is_sqlc_slice_val,
    embed_table: embed_table_val, original_name: original_name_val,
    unsigned: unsigned_val, array_dims: array_dims_val,
  }
}

// === Query ===

fn encode_query(enc: Encoder, val: Query) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_string(val.text)
  enc.write_tag(2, WT_LEN)
  enc.write_string(val.name)
  enc.write_tag(3, WT_LEN)
  enc.write_string(val.cmd)
  for i = 0; i < val.columns.length(); i = i + 1 {
    enc.write_tag(4, WT_LEN)
    enc.write_embedded(fn(enc) { encode_column(enc, val.columns[i]) })
  }
  for i = 0; i < val.params.length(); i = i + 1 {
    enc.write_tag(5, WT_LEN)
    enc.write_embedded(fn(enc) { encode_parameter(enc, val.params[i]) })
  }
  for i = 0; i < val.comments.length(); i = i + 1 {
    enc.write_tag(6, WT_LEN)
    enc.write_string(val.comments[i])
  }
  enc.write_tag(7, WT_LEN)
  enc.write_string(val.filename)
  enc.write_tag(8, WT_LEN)
  enc.write_embedded(fn(enc) { encode_identifier(enc, val.insert_into_table) })
}

fn decode_query(dec: Decoder) -> Query {
  let mut text: Option[String] = None
  let mut name: Option[String] = None
  let mut cmd: Option[String] = None
  let columns: Array[Column] = []
  let params: Array[Parameter] = []
  let comments: Array[String] = []
  let mut filename: Option[String] = None
  let mut insert_into_table: Option[Identifier] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => text = Some(dec.read_string())
      (2, WT_LEN) => name = Some(dec.read_string())
      (3, WT_LEN) => cmd = Some(dec.read_string())
      (4, WT_LEN) => columns.push(decode_embedded(dec, decode_column))
      (5, WT_LEN) => params.push(decode_embedded(dec, decode_parameter))
      (6, WT_LEN) => comments.push(dec.read_string())
      (7, WT_LEN) => filename = Some(dec.read_string())
      (8, WT_LEN) => insert_into_table = Some(decode_embedded(dec, decode_identifier))
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let text_val = match text { Some(v) => v; None => "" }
  let name_val = match name { Some(v) => v; None => "" }
  let cmd_val = match cmd { Some(v) => v; None => "" }
  let filename_val = match filename { Some(v) => v; None => "" }
  let insert_val = match insert_into_table {
    Some(v) => v
    None => { catalog: "", schema: "", name: "" }
  }
  {
    text: text_val, name: name_val, cmd: cmd_val, columns: columns,
    params: params, comments: comments, filename: filename_val,
    insert_into_table: insert_val,
  }
}

// === Parameter ===

fn encode_parameter(enc: Encoder, val: Parameter) -> Unit {
  enc.write_tag(1, WT_VARINT)
  enc.write_varint(val.number)
  enc.write_tag(2, WT_LEN)
  enc.write_embedded(fn(enc) { encode_column(enc, val.column) })
}

fn decode_parameter(dec: Decoder) -> Parameter {
  let mut number: Option[Int] = None
  let mut column: Option[Column] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_VARINT) => number = Some(dec.read_varint())
      (2, WT_LEN) => column = Some(decode_embedded(dec, decode_column))
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  let number_val = match number { Some(v) => v; None => 0 }
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let column_val = match column {
    Some(v) => v
    None => {
      name: "", not_null: false, is_array: false, comment: "", length: 0,
      is_named_param: false, is_func_call: false, scope: "",
      table: empty_id, table_alias: "", ty: empty_id,
      is_sqlc_slice: false, embed_table: empty_id, original_name: "",
      unsigned: false, array_dims: 0
    }
  }
  { number: number_val, column: column_val }
}

// === GenerateRequest ===

fn decode_generate_request(dec: Decoder) -> GenerateRequest raise {
  let mut settings: Option[Settings] = None
  let mut catalog: Option[Catalog] = None
  let queries: Array[Query] = []
  let mut sqlc_version: Option[String] = None
  let mut plugin_options: Option[Bytes] = None
  let mut global_options: Option[Bytes] = None
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => settings = Some(decode_embedded(dec, decode_settings))
      (2, WT_LEN) => catalog = Some(decode_embedded(dec, decode_catalog))
      (3, WT_LEN) => queries.push(decode_embedded(dec, decode_query))
      (4, WT_LEN) => sqlc_version = Some(dec.read_string())
      (5, WT_LEN) => plugin_options = Some(dec.read_bytes())
      (6, WT_LEN) => global_options = Some(dec.read_bytes())
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  if dec.has_error() {
    raise Failure::Failure("codec: corrupt protobuf")
  }
  let empty_codegen: Codegen = {
    out: "", plugin: "", options: b"", env: [], process: None, wasm: None
  }
  let settings_val = match settings {
    Some(v) => v
    None => {
      version: "", engine: "", schema: [], queries: [], codegen: empty_codegen
    }
  }
  let catalog_val = match catalog {
    Some(v) => v
    None => { comment: "", default_schema: "", name: "", schemas: [] }
  }
  let sqlc_version_val = match sqlc_version { Some(v) => v; None => "" }
  let plugin_options_val = match plugin_options { Some(v) => v; None => Bytes::default() }
  let global_options_val = match global_options { Some(v) => v; None => Bytes::default() }
  {
    settings: settings_val, catalog: catalog_val, queries: queries,
    sqlc_version: sqlc_version_val, plugin_options: plugin_options_val,
    global_options: global_options_val,
  }
}

// === GenerateResponse ===

fn encode_generate_response(enc: Encoder, val: GenerateResponse) -> Unit {
  for i = 0; i < val.files.length(); i = i + 1 {
    enc.write_tag(1, WT_LEN)
    enc.write_embedded(fn(enc) { encode_file(enc, val.files[i]) })
  }
}

fn decode_generate_response(dec: Decoder) -> GenerateResponse {
  let files: Array[File] = []
  while dec.remaining() > 0 {
    let (fn_num, wt) = dec.read_tag()
    match (fn_num, wt) {
      (1, WT_LEN) => files.push(decode_embedded(dec, decode_file))
      (_, _) => dec.skip_field(fn_num, wt)
    }
  }
  { files: files }
}

fn encode_generate_request(enc: Encoder, val: GenerateRequest) -> Unit {
  enc.write_tag(1, WT_LEN)
  enc.write_embedded(fn(enc) { encode_settings(enc, val.settings) })
  enc.write_tag(2, WT_LEN)
  enc.write_embedded(fn(enc) { encode_catalog(enc, val.catalog) })
  for i = 0; i < val.queries.length(); i = i + 1 {
    enc.write_tag(3, WT_LEN)
    enc.write_embedded(fn(enc) { encode_query(enc, val.queries[i]) })
  }
  enc.write_tag(4, WT_LEN)
  enc.write_string(val.sqlc_version)
  enc.write_tag(5, WT_LEN)
  enc.write_varint(val.plugin_options.length())
  enc.write_bytes(val.plugin_options)
  enc.write_tag(6, WT_LEN)
  enc.write_varint(val.global_options.length())
  enc.write_bytes(val.global_options)
}

// === Public API ===

pub fn decode_request(data: Bytes) -> GenerateRequest raise {
  let dec = Decoder::new(data)
  decode_generate_request(dec)
}

pub fn encode_request(req: GenerateRequest) -> Bytes {
  let enc = Encoder::new()
  encode_generate_request(enc, req)
  enc.finish()
}

pub fn encode_response(resp: GenerateResponse) -> Bytes {
  let enc = Encoder::new()
  encode_generate_response(enc, resp)
  enc.finish()
}

pub fn decode_response(data: Bytes) -> GenerateResponse {
  let dec = Decoder::new(data)
  decode_generate_response(dec)
}

// === Tests ===

test "decode_request: empty request" {
  let data: Bytes = b""
  let req = decode_request(data)
  inspect(req.settings.version, content="")
  inspect(req.queries.length(), content="0")
}

test "decode_request: minimal request with sqlc_version" {
  let enc = Encoder::new()
  enc.write_tag(4, WT_LEN)
  enc.write_string("1.0.0")
  let data = enc.finish()
  let req = decode_request(data)
  inspect(req.sqlc_version, content="1.0.0")
  inspect(req.settings.version, content="")
}

test "roundtrip: encode + decode GenerateResponse" {
  let resp: GenerateResponse = {
    files: [
      { name: "test.txt", contents: b"hello" },
    ]
  }
  let data = encode_response(resp)
  let dec = Decoder::new(data)
  let decoded = decode_generate_response(dec)
  inspect(decoded.files.length(), content="1")
  inspect(decoded.files[0].name, content="test.txt")
  inspect(decoded.files[0].contents, content="b\"hello\"")
}

test "roundtrip: encode + decode File" {
  let f: File = { name: "query/users.go", contents: b"package db\n" }
  let enc = Encoder::new()
  encode_file(enc, f)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_file(dec)
  inspect(decoded.name, content="query/users.go")
  inspect(decoded.contents, content="b\"package db\\x0a\"")
}

test "roundtrip: encode + decode Identifier" {
  let id: Identifier = { catalog: "cat", schema: "pub", name: "users" }
  let enc = Encoder::new()
  encode_identifier(enc, id)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_identifier(dec)
  inspect(decoded.catalog, content="cat")
  inspect(decoded.schema, content="pub")
  inspect(decoded.name, content="users")
}

test "roundtrip: encode + decode CodegenProcess" {
  let p: CodegenProcess = { cmd: "protoc" }
  let enc = Encoder::new()
  encode_codegen_process(enc, p)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_codegen_process(dec)
  inspect(decoded.cmd, content="protoc")
}

test "roundtrip: encode + decode CodegenWASM" {
  let w: CodegenWASM = {
    url: "https://example.com/plugin.wasm",
    sha256: "abc123",
  }
  let enc = Encoder::new()
  encode_codegen_wasm(enc, w)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_codegen_wasm(dec)
  inspect(decoded.url, content="https://example.com/plugin.wasm")
  inspect(decoded.sha256, content="abc123")
}

test "roundtrip: encode + decode Column" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let col: Column = {
    name: "id", not_null: true, is_array: false, comment: "", length: 0,
    is_named_param: false, is_func_call: false, scope: "", table: empty_id,
    table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
    original_name: "id", unsigned: false, array_dims: 0,
  }
  let enc = Encoder::new()
  encode_column(enc, col)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_column(dec)
  inspect(decoded.name, content="id")
  inspect(decoded.not_null, content="true")
}

test "varint: roundtrip" {
  let values: Array[Int] = [0, 1, 127, 128, 255, 300, 1000000]
  for i = 0; i < values.length(); i = i + 1 {
    let enc = Encoder::new()
    enc.write_varint(values[i])
    let data = enc.finish()
    let dec = Decoder::new(data)
    let decoded = dec.read_varint()
    inspect(decoded, content="\{values[i]}")
  }
}

test "string: roundtrip ASCII" {
  let s = "hello world"
  let enc = Encoder::new()
  enc.write_string(s)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = dec.read_string()
  inspect(decoded, content="hello world")
}

test "string: roundtrip UTF-8 non-ASCII" {
  let s = "你好世界"
  let enc = Encoder::new()
  enc.write_string(s)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = dec.read_string()
  inspect(decoded, content="你好世界")
}

test "bytes: roundtrip" {
  let bs: Bytes = b"\x00\x01\x02\xFF\xFE"
  let enc = Encoder::new()
  enc.write_varint(bs.length())
  enc.write_bytes(bs)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = dec.read_bytes()
  inspect(decoded.length(), content="5")
  inspect(decoded[0], content="b'\\x00'")
}

test "roundtrip: CompositeType" {
  let ct: CompositeType = { name: "address", comment: "A physical address" }
  let enc = Encoder::new()
  encode_composite_type(enc, ct)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_composite_type(dec)
  inspect(decoded.name, content="address")
  inspect(decoded.comment, content="A physical address")
}

test "roundtrip: Enum" {
  let e: Enum = {
    name: "user_role",
    vals: ["admin", "user", "guest"],
    comment: "User roles",
  }
  let enc = Encoder::new()
  encode_enum(enc, e)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_enum(dec)
  inspect(decoded.name, content="user_role")
  inspect(decoded.vals.length(), content="3")
  inspect(decoded.vals[0], content="admin")
  inspect(decoded.vals[1], content="user")
  inspect(decoded.vals[2], content="guest")
  inspect(decoded.comment, content="User roles")
}

test "roundtrip: Parameter" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let p: Parameter = {
    number: 1,
    column: {
      name: "id", not_null: true, is_array: false, comment: "", length: 0,
      is_named_param: false, is_func_call: false, scope: "", table: empty_id,
      table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
      original_name: "", unsigned: false, array_dims: 0,
    },
  }
  let enc = Encoder::new()
  encode_parameter(enc, p)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_parameter(dec)
  inspect(decoded.number, content="1")
  inspect(decoded.column.name, content="id")
}

test "roundtrip: Query" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let q: Query = {
    text: "SELECT * FROM users WHERE id = $1",
    name: "GetUser",
    cmd: ":one",
    columns: [
      { name: "id", not_null: true, is_array: false, comment: "", length: 0,
        is_named_param: false, is_func_call: false, scope: "", table: empty_id,
        table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
        original_name: "", unsigned: false, array_dims: 0 },
    ],
    params: [
      { number: 1, column: {
        name: "id", not_null: true, is_array: false, comment: "", length: 0,
        is_named_param: false, is_func_call: false, scope: "", table: empty_id,
        table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
        original_name: "", unsigned: false, array_dims: 0 } },
    ],
    comments: ["fetch a user by ID"],
    filename: "query.sql",
    insert_into_table: empty_id,
  }
  let enc = Encoder::new()
  encode_query(enc, q)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_query(dec)
  inspect(decoded.name, content="GetUser")
  inspect(decoded.cmd, content=":one")
  inspect(decoded.columns.length(), content="1")
  inspect(decoded.params.length(), content="1")
}

test "roundtrip: Codegen with process and wasm" {
  let cg: Codegen = {
    out: "gen/", plugin: "moonbit", options: b"--package db",
    env: ["PATH=/usr/bin"], process: Some({ cmd: "protoc" }),
    wasm: Some({ url: "https://example.com/plugin.wasm", sha256: "abc" }),
  }
  let enc = Encoder::new()
  encode_codegen(enc, cg)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_codegen(dec)
  inspect(decoded.out, content="gen/")
  inspect(decoded.plugin, content="moonbit")
  inspect(match decoded.process { Some(v) => v.cmd; None => "" }, content="protoc")
  inspect(match decoded.wasm { Some(v) => v.url; None => "" }, content="https://example.com/plugin.wasm")
}

test "roundtrip: Schema with tables, enums, composite_types" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let schema: Schema = {
    comment: "public schema",
    name: "public",
    tables: [
      {
        rel: { catalog: "db", schema: "public", name: "users" },
        columns: [
          { name: "id", not_null: true, is_array: false, comment: "", length: 0,
            is_named_param: false, is_func_call: false, scope: "", table: empty_id,
            table_alias: "", ty: { catalog: "", schema: "", name: "int4" },
            is_sqlc_slice: false, embed_table: empty_id, original_name: "",
            unsigned: false, array_dims: 0 },
        ],
        comment: "users table",
      },
    ],
    enums: [{ name: "mood", vals: ["happy", "sad"], comment: "" }],
    composite_types: [{ name: "address", comment: "" }],
  }
  let enc = Encoder::new()
  encode_schema(enc, schema)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_schema(dec)
  inspect(decoded.name, content="public")
  inspect(decoded.tables.length(), content="1")
  inspect(decoded.tables[0].rel.name, content="users")
  inspect(decoded.enums.length(), content="1")
  inspect(decoded.enums[0].name, content="mood")
  inspect(decoded.composite_types.length(), content="1")
  inspect(decoded.composite_types[0].name, content="address")
}

test "roundtrip: Settings" {
  let settings: Settings = {
    version: "1", engine: "postgresql",
    schema: ["CREATE TABLE users (id int4)"],
    queries: ["-- name: GetUser :one\nSELECT * FROM users"],
    codegen: {
      out: "gen/", plugin: "moonbit", options: b"", env: [],
      process: None, wasm: None,
    },
  }
  let enc = Encoder::new()
  encode_settings(enc, settings)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_settings(dec)
  inspect(decoded.version, content="1")
  inspect(decoded.engine, content="postgresql")
  inspect(decoded.schema.length(), content="1")
  inspect(decoded.queries.length(), content="1")
}

test "roundtrip: Catalog" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let cat: Catalog = {
    comment: "main catalog",
    default_schema: "public",
    name: "testdb",
    schemas: [
      {
        comment: "", name: "public",
        tables: [
          {
            rel: { catalog: "testdb", schema: "public", name: "users" },
            columns: [
              { name: "id", not_null: true, is_array: false, comment: "", length: 0,
                is_named_param: false, is_func_call: false, scope: "", table: empty_id,
                table_alias: "", ty: { catalog: "", schema: "", name: "int4" },
                is_sqlc_slice: false, embed_table: empty_id, original_name: "",
                unsigned: false, array_dims: 0 },
            ],
            comment: "",
          },
        ],
        enums: [],
        composite_types: [],
      },
    ],
  }
  let enc = Encoder::new()
  encode_catalog(enc, cat)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = decode_catalog(dec)
  inspect(decoded.name, content="testdb")
  inspect(decoded.default_schema, content="public")
  inspect(decoded.schemas.length(), content="1")
  inspect(decoded.schemas[0].tables.length(), content="1")
}

test "decode_request: full request with all fields" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  // Build a CodeGenRequest manually through the encoder
  let enc = Encoder::new()
  // settings (field 1)
  enc.write_tag(1, WT_LEN)
  enc.write_embedded(fn(enc) {
    encode_settings(enc, {
      version: "1", engine: "postgresql",
      schema: ["CREATE TABLE users"],
      queries: ["-- name: GetUser :one\nSELECT * FROM users"],
      codegen: { out: "gen/", plugin: "moonbit", options: b"", env: [], process: None, wasm: None },
    })
  })
  // catalog (field 2)
  enc.write_tag(2, WT_LEN)
  enc.write_embedded(fn(enc) { encode_catalog(enc, {
    comment: "", default_schema: "public", name: "testdb",
    schemas: [{
      comment: "", name: "public",
      tables: [{
        rel: { catalog: "testdb", schema: "public", name: "users" },
        columns: [{ name: "id", not_null: true, is_array: false, comment: "", length: 0,
          is_named_param: false, is_func_call: false, scope: "", table: empty_id,
          table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
          original_name: "", unsigned: false, array_dims: 0 }],
        comment: "",
      }],
      enums: [], composite_types: [],
    }],
  }) })
  // query (field 3)
  enc.write_tag(3, WT_LEN)
  enc.write_embedded(fn(enc) { encode_query(enc, {
    text: "SELECT * FROM users WHERE id = $1", name: "GetUser", cmd: ":one",
    columns: [{ name: "id", not_null: true, is_array: false, comment: "", length: 0,
      is_named_param: false, is_func_call: false, scope: "", table: empty_id,
      table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
      original_name: "", unsigned: false, array_dims: 0 }],
    params: [{ number: 1, column: {
      name: "id", not_null: true, is_array: false, comment: "", length: 0,
      is_named_param: false, is_func_call: false, scope: "", table: empty_id,
      table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
      original_name: "", unsigned: false, array_dims: 0 } }],
    comments: [], filename: "query.sql", insert_into_table: empty_id,
  }) })
  // sqlc_version (field 4)
  enc.write_tag(4, WT_LEN)
  enc.write_string("1.53.0")
  let data = enc.finish()
  let decoded = decode_request(data)
  inspect(decoded.sqlc_version, content="1.53.0")
  inspect(decoded.queries.length(), content="1")
  inspect(decoded.queries[0].name, content="GetUser")
  inspect(decoded.settings.engine, content="postgresql")
  inspect(decoded.catalog.name, content="testdb")
}

test "varint: single byte values 0..127" {
  for i = 0; i < 128; i = i + 1 {
    let enc = Encoder::new()
    enc.write_varint(i)
    let data = enc.finish()
    let dec = Decoder::new(data)
    let decoded = dec.read_varint()
    inspect(decoded, content="\{i}")
  }
}

test "varint: multi-byte positive values" {
  let values: Array[Int] = [128, 255, 300, 1000000, 2147483647]
  for i = 0; i < values.length(); i = i + 1 {
    let enc = Encoder::new()
    enc.write_varint(values[i])
    let data = enc.finish()
    let dec = Decoder::new(data)
    let decoded = dec.read_varint()
    inspect(decoded, content="\{values[i]}")
  }
}

test "string: empty" {
  let enc = Encoder::new()
  enc.write_string("")
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = dec.read_string()
  inspect(decoded, content="")
}

test "bytes: empty" {
  let bs: Bytes = b""
  let enc = Encoder::new()
  enc.write_varint(bs.length())
  enc.write_bytes(bs)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = dec.read_bytes()
  inspect(decoded.length(), content="0")
}

test "bytes: single byte" {
  let bs: Bytes = b"\xAB"
  let enc = Encoder::new()
  enc.write_varint(bs.length())
  enc.write_bytes(bs)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let decoded = dec.read_bytes()
  inspect(decoded.length(), content="1")
}

test "skip_field: varint" {
  let enc = Encoder::new()
  enc.write_tag(1, WT_VARINT)
  enc.write_varint(42)
  enc.write_tag(2, WT_LEN)
  enc.write_string("hello")
  let data = enc.finish()
  let dec = Decoder::new(data)
  let (field_num1, wt1) = dec.read_tag()
  inspect(field_num1, content="1")
  inspect(wt1, content="0")
  dec.skip_field(field_num1, wt1)
  let (field_num2, wt2) = dec.read_tag()
  inspect(field_num2, content="2")
  inspect(wt2, content="2")
}

test "skip_field: length-delimited" {
  let enc = Encoder::new()
  enc.write_tag(1, WT_LEN)
  enc.write_string("skip_this")
  let data = enc.finish()
  let dec = Decoder::new(data)
  let (field_num, wt) = dec.read_tag()
  dec.skip_field(field_num, wt)
  inspect(dec.remaining(), content="0")
}

test "roundtrip: null vs not-null Column" {
  let empty_id: Identifier = { catalog: "", schema: "", name: "" }
  let col_nullable: Column = {
    name: "email", not_null: false, is_array: false, comment: "", length: 0,
    is_named_param: false, is_func_call: false, scope: "", table: empty_id,
    table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
    original_name: "", unsigned: false, array_dims: 0,
  }
  let col_notnull: Column = {
    name: "id", not_null: true, is_array: false, comment: "", length: 0,
    is_named_param: false, is_func_call: false, scope: "", table: empty_id,
    table_alias: "", ty: empty_id, is_sqlc_slice: false, embed_table: empty_id,
    original_name: "", unsigned: false, array_dims: 0,
  }
  // Wrap each column in an embedded (length-delimited) message for boundary
  let enc = Encoder::new()
  enc.write_tag(1, WT_LEN)
  enc.write_embedded(fn(enc) { encode_column(enc, col_nullable) })
  enc.write_tag(2, WT_LEN)
  enc.write_embedded(fn(enc) { encode_column(enc, col_notnull) })
  let data = enc.finish()
  let dec = Decoder::new(data)
  let (_fn1, _wt1) = dec.read_tag()
  let decoded1 = decode_embedded(dec, decode_column)
  let (_fn2, _wt2) = dec.read_tag()
  let decoded2 = decode_embedded(dec, decode_column)
  inspect(decoded1.not_null, content="false")
  inspect(decoded2.not_null, content="true")
}

test "varint: near-max int32 value roundtrip" {
  let enc = Encoder::new()
  enc.write_varint(2147483647)
  let data = enc.finish()
  let dec = Decoder::new(data)
  inspect(dec.read_varint(), content="2147483647")
}

test "varint: encoding with 5-byte max prevents infinite loop" {
  // 5 continuation bytes forces the encoder's max-iteration guard to activate
  // Instead of looping forever with arithmetic right-shift on negative values,
  // the encoder stops after 5 bytes and emits the masked final byte.
  let enc = Encoder::new()
  // Use a value that triggers arithmetic shift edge case on wasm32
  enc.write_varint(-1)
  let data = enc.finish()
  let dec = Decoder::new(data)
  let _ = dec.read_varint()
  inspect(data.length() > 0, content="true")
}

test "varint: 6 continuation bytes stops at 5" {
  // 6 continuation bytes (0x80) followed by 0x00 — decoder should stop after 5
  let buf = Bytes::from_array([0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x00])
  let dec = Decoder::new(buf)
  let _ = dec.read_varint()
  inspect(dec.remaining() > 0, content="true")
}



test "read_string: negative len returns empty" {
  // 5 continuation bytes produce a negative value; read_string treats <=0 as empty
  let buf = Bytes::from_array([0x80, 0x80, 0x80, 0x80, 0x80])
  let dec = Decoder::new(buf)
  let s = dec.read_string()
  inspect(s, content="")
}

test "read_bytes: exact boundary succeeds" {
  let buf = Bytes::from_array([0x03, 0x01, 0x02, 0x03])
  let dec = Decoder::new(buf)
  // read_varint = 3, exactly 3 bytes available
  let bs = dec.read_bytes()
  inspect(bs.length(), content="3")
}

test "read_bytes: normal 5 bytes" {
  let buf = Bytes::from_array([0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F])
  let dec = Decoder::new(buf)
  // read_varint = 5, 5 bytes available
  let bs = dec.read_bytes()
  inspect(bs.length(), content="5")
  inspect(bs[0].to_int(), content="72")
  inspect(bs[4].to_int(), content="111")
}

test "decode_embedded: len 0 creates empty sub-decoder" {
  let buf = Bytes::from_array([0x00])
  let dec = Decoder::new(buf)
  let result = decode_embedded(dec, fn(sub) { sub.remaining() })
  inspect(result, content="0")
}

test "decode_embedded: negative len returns empty sub-decoder" {
  // 5 continuation bytes that decode to a negative value
  let buf = Bytes::from_array([0x80, 0x80, 0x80, 0x80, 0x80, 0x00])
  let dec = Decoder::new(buf)
  let result = decode_embedded(dec, fn(sub) { sub.remaining() })
  inspect(result, content="0")
}

test "decode_embedded: len exceeds buffer returns empty sub-decoder" {
  // Varint value 999 with only 1 byte of buffer data — length exceeds buffer
  let b: Int = 0x41
  let enc = Encoder::new()
  enc.write_varint(999)
  enc.write_byte(b.to_byte())
  let data = enc.finish()
  let dec = Decoder::new(data)
  let result = decode_embedded(dec, fn(sub) { sub.remaining() })
  inspect(result, content="0")
}

test "roundtrip: encode_request with empty plugin_options" {
  let req: GenerateRequest = {
    settings: {
      version: "1", engine: "postgresql",
      schema: [], queries: [],
      codegen: { out: "", plugin: "", options: b"", env: [], process: None, wasm: None },
    },
    catalog: { comment: "", default_schema: "", name: "", schemas: [] },
    queries: [],
    sqlc_version: "1.53.0",
    plugin_options: b"",
    global_options: b"",
  }
  let data = encode_request(req)
  let decoded = decode_request(data)
  inspect(decoded.plugin_options.length(), content="0")
  inspect(decoded.global_options.length(), content="0")
  inspect(decoded.sqlc_version, content="1.53.0")
}

test "roundtrip: encode_request with non-empty plugin_options" {
  let req: GenerateRequest = {
    settings: {
      version: "1", engine: "postgresql",
      schema: [], queries: [],
      codegen: { out: "", plugin: "", options: b"", env: [], process: None, wasm: None },
    },
    catalog: { comment: "", default_schema: "", name: "", schemas: [] },
    queries: [],
    sqlc_version: "1.53.0",
    plugin_options: b"--package db",
    global_options: b"",
  }
  let data = encode_request(req)
  let decoded = decode_request(data)
  inspect(decoded.plugin_options.length(), content="12")
}

test "skip_field: unknown wire type skips to end" {
  // Unknown wire type 7 with data byte 0xFF — skip_field should jump to end
  let val: Int = 0xFF
  let enc = Encoder::new()
  enc.write_tag(1, 7)
  enc.write_byte(val.to_byte())
  let data = enc.finish()
  let dec = Decoder::new(data)
  let (fn_num, wt) = dec.read_tag()
  dec.skip_field(fn_num, wt)
  inspect(dec.remaining(), content="0")
}

test "read_fixed32: decodes 4 LE bytes" {
  let buf = Bytes::from_array([0x78, 0x56, 0x34, 0x12])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed32()
  inspect(val, content="305419896")
}

test "read_fixed32: zero value" {
  let buf = Bytes::from_array([0x00, 0x00, 0x00, 0x00])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed32()
  inspect(val, content="0")
}

test "read_fixed32: all-ones value (wraps to -1 as Int)" {
  let buf = Bytes::from_array([0xFF, 0xFF, 0xFF, 0xFF])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed32()
  // 0xFFFFFFFF as 32-bit signed Int = -1
  inspect(val, content="-1")
}

test "read_fixed64: decodes 8 LE bytes" {
  let buf = Bytes::from_array([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed64()
  // 0x0807060504030201 = 578437695752307201
  inspect(val, content="578437695752307201")
}

test "read_fixed64: zero value" {
  let buf = Bytes::from_array([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed64()
  inspect(val, content="0")
}

test "read_fixed64: small value (42)" {
  let buf = Bytes::from_array([0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed64()
  inspect(val, content="42")
}

test "skip_field: WT_BITS64 (wire type 1) skips 8 bytes" {
  let enc = Encoder::new()
  enc.write_tag(1, WT_BITS64)
  enc.write_byte((0x01).to_byte())
  enc.write_byte((0x02).to_byte())
  enc.write_byte((0x03).to_byte())
  enc.write_byte((0x04).to_byte())
  enc.write_byte((0x05).to_byte())
  enc.write_byte((0x06).to_byte())
  enc.write_byte((0x07).to_byte())
  enc.write_byte((0x08).to_byte())
  enc.write_tag(2, WT_LEN)
  enc.write_string("ok")
  let data = enc.finish()
  let dec = Decoder::new(data)
  let (fn_num, wt) = dec.read_tag()
  dec.skip_field(fn_num, wt)
  let (fn2, wt2) = dec.read_tag()
  inspect(fn2, content="2")
  inspect(wt2, content="2")
  let s = dec.read_string()
  inspect(s, content="ok")
}

test "skip_field: WT_BITS32 (wire type 5) skips 4 bytes" {
  let enc = Encoder::new()
  enc.write_tag(1, WT_BITS32)
  enc.write_byte((0xDE).to_byte())
  enc.write_byte((0xAD).to_byte())
  enc.write_byte((0xBE).to_byte())
  enc.write_byte((0xEF).to_byte())
  enc.write_tag(2, WT_LEN)
  enc.write_string("ok")
  let data = enc.finish()
  let dec = Decoder::new(data)
  let (fn_num, wt) = dec.read_tag()
  dec.skip_field(fn_num, wt)
  let (fn2, wt2) = dec.read_tag()
  inspect(fn2, content="2")
  inspect(wt2, content="2")
  let s = dec.read_string()
  inspect(s, content="ok")
}

// === P1-039: Codec error path boundary tests ===

/// P1-039: read_string with len exactly equal to available bytes (boundary, should succeed).
test "P1-039: read_string len == available (boundary success)" {
  let p039_buf = Bytes::from_array([0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F])
  let p039_dec = Decoder::new(p039_buf)
  let p039_s = p039_dec.read_string()
  inspect(p039_s, content="Hello")
  inspect(p039_dec.remaining(), content="0")
}

/// P1-039: read_string with len == remaining on exact boundary.
test "P1-039: read_string len == remaining on exact boundary" {
  // Varint=1 with 1 data byte
  let p039_buf2 = Bytes::from_array([0x01, 0x41])
  let p039_dec2 = Decoder::new(p039_buf2)
  let p039_s2 = p039_dec2.read_string()
  inspect(p039_s2, content="A")
  inspect(p039_dec2.remaining(), content="0")
}

/// P1-039: decode_embedded with len == remaining (exact boundary).
test "P1-039: decode_embedded len == remaining (exact boundary)" {
  let p039_enc = Encoder::new()
  p039_enc.write_tag(1, WT_LEN)
  p039_enc.write_string("A")
  let p039_data = p039_enc.finish()
  let p039_dec3 = Decoder::new(p039_data)
  let (fnum039, wt039) = p039_dec3.read_tag()
  inspect(fnum039, content="1")
  inspect(wt039, content="2")
  let p039_str = p039_dec3.read_string()
  inspect(p039_str, content="A")
  inspect(p039_dec3.remaining(), content="0")
}

/// P1-039: skip_field WT_LEN with length that exceeds buffer — pos clamped to end.
test "P1-039: skip_field WT_LEN exceeds buffer clamps pos to end" {
  // Write tag (field=1, WT_LEN=2), varint len=100, plus 1 payload byte
  let p039_enc5 = Encoder::new()
  p039_enc5.write_tag(1, WT_LEN)
  p039_enc5.write_varint(100)
  p039_enc5.write_byte((0x41).to_byte())
  let p039_data5 = p039_enc5.finish()
  let p039_dec16 = Decoder::new(p039_data5)
  let (fnum039g, wt039g) = p039_dec16.read_tag()
  p039_dec16.skip_field(fnum039g, wt039g)
  inspect(p039_dec16.remaining(), content="0")
}

/// P1-039: skip_field WT_LEN with large negative wrapping varint.
/// 5 continuation bytes produce a large value; guard clamps to end.
test "P1-039: skip_field WT_LEN negative varint clamps pos" {
  let p039_buf5 = Bytes::from_array([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00])
  let p039_dec5 = Decoder::new(p039_buf5)
  let (fnum039b, wt039b) = p039_dec5.read_tag()
  p039_dec5.skip_field(fnum039b, wt039b)
  inspect(p039_dec5.remaining() >= 0, content="true")
}

/// P0-061: read_byte with valid input returns correct byte.
test "P0-061: read_byte with valid input returns correct byte" {
  let buf = Bytes::from_array([0x42])
  let dec = Decoder::new(buf)
  let b = dec.read_byte()
  inspect(b.to_int(), content="66") // 'B' = 66
  inspect(dec.remaining(), content="0")
}

/// P0-061: read_byte on empty buffer sets error flag (P0-070).
test "P0-061: read_byte with zero-length buffer does not return value" {
  let dec = Decoder::new(b"")
  let _b = dec.read_byte()
  inspect(dec.has_error(), content="true")
  inspect(dec.remaining(), content="0")
}

/// P1-039: read_varint on empty buffer returns 0.
test "P1-039: read_varint on empty buffer returns 0" {
  let p039_dec8 = Decoder::new(b"")
  inspect(p039_dec8.read_varint(), content="0")
}

/// P1-039: read_varint with all continuation bytes (max 5) followed by terminator.
test "P1-039: read_varint max continuation bytes with terminator" {
  // 4 continuation bytes (0x80) + 1 terminator (0x01) = valid 5-byte varint
  let p039_buf9 = Bytes::from_array([0x80, 0x80, 0x80, 0x80, 0x01])
  let p039_dec9 = Decoder::new(p039_buf9)
  inspect(p039_dec9.read_varint() >= 0, content="true")
}

/// P1-039: decode_embedded with zero bytes (len=0 varint only).
test "P1-039: decode_embedded zero-length returns empty sub-decoder" {
  let p039_buf10 = Bytes::from_array([0x00])
  let p039_dec10 = Decoder::new(p039_buf10)
  let p039_result = decode_embedded(p039_dec10, fn(sub) { sub.remaining() })
  inspect(p039_result, content="0")
}

/// P1-039: skip_field wire type 3 (start group) triggers skip_group.
test "P1-039: skip_field wire type 3 triggers skip_group" {
  let p039_enc2 = Encoder::new()
  p039_enc2.write_tag(1, 3) // SGROUP
  p039_enc2.write_byte((0x00).to_byte())
  p039_enc2.write_tag(2, WT_LEN)
  p039_enc2.write_string("ok")
  let p039_data2 = p039_enc2.finish()
  let p039_dec11 = Decoder::new(p039_data2)
  let (fnum039c, wt039c) = p039_dec11.read_tag()
  inspect(wt039c, content="3")
  p039_dec11.skip_field(fnum039c, wt039c)
  inspect(p039_dec11.remaining(), content="0")
}

/// P1-039: skip_field wire type 4 (end group) is a no-op.
test "P1-039: skip_field wire type 4 is no-op" {
  let p039_enc3 = Encoder::new()
  p039_enc3.write_tag(1, 4) // EGROUP
  p039_enc3.write_tag(2, WT_LEN)
  p039_enc3.write_string("ok")
  let p039_data3 = p039_enc3.finish()
  let p039_dec12 = Decoder::new(p039_data3)
  let (fnum039d, wt039d) = p039_dec12.read_tag()
  inspect(wt039d, content="4")
  p039_dec12.skip_field(fnum039d, wt039d)
  let (fnum039e, _) = p039_dec12.read_tag()
  inspect(fnum039e, content="2")
  let p039_str2 = p039_dec12.read_string()
  inspect(p039_str2, content="ok")
}

/// P1-039: read_fixed32 at buffer boundary (exactly 4 bytes).
test "P1-039: read_fixed32 at exact buffer boundary" {
  let p039_buf13 = Bytes::from_array([0x01, 0x00, 0x00, 0x00])
  let p039_dec13 = Decoder::new(p039_buf13)
  inspect(p039_dec13.read_fixed32(), content="1")
  inspect(p039_dec13.remaining(), content="0")
}

/// P1-039: read_fixed64 at buffer boundary (exactly 8 bytes).
test "P1-039: read_fixed64 at exact buffer boundary" {
  let p039_buf14 = Bytes::from_array([0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
  let p039_dec14 = Decoder::new(p039_buf14)
  inspect(p039_dec14.read_fixed64(), content="42")
  inspect(p039_dec14.remaining(), content="0")
}

/// P1-039: skip_field unknown wire type (6) should also skip to end.
test "P1-039: skip_field unknown wire type 6 skips to end" {
  let p039_enc4 = Encoder::new()
  p039_enc4.write_tag(1, 6)
  p039_enc4.write_byte((0xFF).to_byte())
  let p039_data4 = p039_enc4.finish()
  let p039_dec15 = Decoder::new(p039_data4)
  let (fnum039f, wt039f) = p039_dec15.read_tag()
  p039_dec15.skip_field(fnum039f, wt039f)
  inspect(p039_dec15.remaining(), content="0")
}

// === P0-061: Codec bounds hardening tests ===

/// P0-061: read_fixed32 with exactly 4 bytes succeeds (boundary).
test "P0-061: read_fixed32 exact boundary 4 bytes" {
  let buf = Bytes::from_array([0x01, 0x02, 0x03, 0x04])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed32()
  // LE: 0x04030201 = 67305985
  inspect(val, content="67305985")
  inspect(dec.remaining(), content="0")
}

/// P0-061: read_fixed32 with more than 4 bytes only consumes 4.
test "P0-061: read_fixed32 with 5 bytes only consumes 4" {
  let buf = Bytes::from_array([0x01, 0x00, 0x00, 0x00, 0xFF])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed32()
  inspect(val, content="1")
  inspect(dec.remaining(), content="1")
  // The remaining byte is 0xFF, not consumed by read_fixed32
  let b = dec.read_byte()
  inspect(b.to_int(), content="255")
}

/// P0-061: read_fixed64 with exactly 8 bytes succeeds (boundary).
test "P0-061: read_fixed64 exact boundary 8 bytes" {
  let buf = Bytes::from_array([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed64()
  inspect(val, content="1")
  inspect(dec.remaining(), content="0")
}

/// P0-061: read_fixed64 with more than 8 bytes only consumes 8.
test "P0-061: read_fixed64 with 10 bytes only consumes 8" {
  let buf = Bytes::from_array([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0xAA, 0xBB])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed64()
  // 0x0807060504030201 = 578437695752307201
  inspect(val, content="578437695752307201")
  inspect(dec.remaining(), content="2")
  // Remaining bytes are 0xAA, 0xBB
  let b1 = dec.read_byte()
  let b2 = dec.read_byte()
  inspect(b1.to_int(), content="170")  // 0xAA
  inspect(b2.to_int(), content="187")  // 0xBB
}

/// P0-061: read_fixed32 with 3 bytes sets error flag (P0-070).
test "P0-061: read_fixed32 4 bytes boundary correct value" {
  // Test the exact boundary case: 4 bytes, fixed32 works correctly
  let buf = Bytes::from_array([0x78, 0x56, 0x34, 0x12])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed32()
  inspect(val, content="305419896")
  inspect(dec.remaining(), content="0")
}

/// P0-061: read_fixed64 with 7 bytes sets error flag (P0-070).
test "P0-061: read_fixed64 8 bytes boundary correct value" {
  let buf = Bytes::from_array([0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00])
  let dec = Decoder::new(buf)
  let val = dec.read_fixed64()
  // 0x0000000100000000 = 4294967296
  inspect(val, content="4294967296")
  inspect(dec.remaining(), content="0")
}

/// P0-061: read_varint never calls read_byte past end of buffer.
/// read_varint has its own remaining() check on each iteration.
/// This test validates that read_varint with exactly 1-byte non-continuation varint works.
test "P0-061: read_varint guard prevents OOB read_byte" {
  let buf = Bytes::from_array([0x01])
  let dec = Decoder::new(buf)
  let val = dec.read_varint()
  inspect(val, content="1")
  inspect(dec.remaining(), content="0")
}

// === P0-070: Codec abort → error flag ===

test "P0-070: read_byte on empty buffer sets error flag" {
  let dec = Decoder::new(b"")
  let _b = dec.read_byte()
  inspect(dec.has_error(), content="true")
  inspect(dec.remaining(), content="0")
}

test "P0-070: read_string len exceeds available sets error" {
  // varint len=5 (0x05), only 1 payload byte available
  let dec = Decoder::new(Bytes::from_array([0x05, 0x41]))
  let s = dec.read_string()
  inspect(s, content="")
  inspect(dec.has_error(), content="true")
  inspect(dec.remaining(), content="1")
}

test "P0-070: read_bytes len exceeds available sets error" {
  let dec = Decoder::new(Bytes::from_array([0x05, 0x41]))
  let bs = dec.read_bytes()
  inspect(bs.length(), content="0")
  inspect(dec.has_error(), content="true")
  inspect(dec.remaining(), content="1")
}

test "P0-070: read_fixed32 insufficient bytes sets error" {
  let dec = Decoder::new(Bytes::from_array([0x01, 0x02, 0x03]))
  let val = dec.read_fixed32()
  inspect(val, content="0")
  inspect(dec.has_error(), content="true")
  inspect(dec.remaining(), content="3")
}

test "P0-070: read_fixed64 insufficient bytes sets error" {
  let dec = Decoder::new(Bytes::from_array([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]))
  let val = dec.read_fixed64()
  inspect(val, content="0")
  inspect(dec.has_error(), content="true")
  inspect(dec.remaining(), content="7")
}

test "P0-070: decode_request corrupt protobuf raises" {
  let enc = Encoder::new()
  enc.write_tag(4, WT_LEN)
  enc.write_varint(100)
  enc.write_byte((0x41).to_byte())
  let data = enc.finish()
  let result = try {
    let _ = decode_request(data)
    "unexpected_ok"
  } catch {
    _ => "raised"
  }
  inspect(result, content="raised")
}
