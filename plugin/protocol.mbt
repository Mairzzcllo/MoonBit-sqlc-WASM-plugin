///|
/// sqlc WASM plugin protocol — unframed raw protobuf over stdin/stdout.
///
/// Native WASI I/O via inline WAT FFI (wasi_io.mbt). WASI fd_read/fd_write
/// handle stdin/stdout I/O directly without 4-byte LE framing.
///
/// Protocol flow:
///   1. run_io_loop reads all bytes from stdin via fd_read until EOF
///   2. run_io_loop calls `process_message_outcome(data: Bytes)`
///   3. On success run_io_loop writes raw response bytes to stdout via fd_write
///   4. On failure run_io_loop writes the error to stderr and exits non-zero
///      (sqlc surfaces stderr to the user; see sqlc internal/ext/wasm/wasm.go)
///
/// Protocol entry point — pure data transformation.
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

/// Outcome of processing a raw protobuf GenerateRequest.
pub enum MessageOutcome {
  Ok(Bytes)
  Err(String)
}

fn format_process_error(e: Error) -> String {
  match e {
    Failure::Failure(msg) => msg
    _ => "codegen failed"
  }
}

/// Process a raw protobuf GenerateRequest and return success or error message.
/// Used by the WASI I/O loop for sqlc-visible error reporting via stderr.
pub fn process_message_outcome(data: Bytes) -> MessageOutcome {
  if data.length() == 0 {
    return Err("empty GenerateRequest")
  }
  try {
    let req = decode_request(data)
    let resp = process_request(req)
    Ok(encode_response(resp))
  } catch {
    e => Err(format_process_error(e))
  }
}

/// Process a raw protobuf GenerateRequest and return raw GenerateResponse bytes.
/// Moonrun tests use this entry point; errors return an empty GenerateResponse.
/// Production sqlc path uses `process_message_outcome` + stderr instead.
///
/// Codec errors propagate via `raise` from `decode_request` and are caught here.
/// `abort()` must not be used on decode paths (WASM trap bypasses catch).
pub fn process_message(data: Bytes) -> Bytes {
  match process_message_outcome(data) {
    Ok(bytes) => bytes
    Err(_) => {
      let empty_resp: GenerateResponse = { files: [] }
      encode_response(empty_resp)
    }
  }
}

test "P0-070: process_message corrupt protobuf returns empty response" {
  let enc = Encoder::new()
  enc.write_tag(4, WT_LEN)
  enc.write_varint(100)
  enc.write_byte((0x41).to_byte())
  let data = enc.finish()
  let response_bytes = process_message(data)
  let resp = decode_response(response_bytes)
  inspect(resp.files.length(), content="0")
}

test "P0-001: process_message_outcome empty buffer returns Err" {
  match process_message_outcome(b"") {
    Ok(_) => inspect(false, content="true")
    Err(msg) => inspect(msg.contains("empty"), content="true")
  }
}

test "P0-001: process_message_outcome corrupt protobuf returns Err" {
  let enc = Encoder::new()
  enc.write_tag(4, WT_LEN)
  enc.write_varint(100)
  enc.write_byte((0x41).to_byte())
  let data = enc.finish()
  match process_message_outcome(data) {
    Ok(_) => inspect(false, content="true")
    Err(msg) => inspect(msg.length() > 0, content="true")
  }
}

test "P0-001: process_message_outcome path traversal returns Err with message" {
  let base = make_users_request()
  let settings_with_traversal = {
    version: base.settings.version,
    engine: base.settings.engine,
    schema: base.settings.schema,
    queries: base.settings.queries,
    codegen: {
      out: "../etc",
      plugin: base.settings.codegen.plugin,
      options: base.settings.codegen.options,
      env: base.settings.codegen.env,
      process: base.settings.codegen.process,
      wasm: base.settings.codegen.wasm,
    },
  }
  let req: GenerateRequest = {
    settings: settings_with_traversal,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"package_name=test",
    global_options: b"",
  }
  match process_message_outcome(encode_request(req)) {
    Ok(_) => inspect(false, content="true")
    Err(msg) => inspect(msg.contains("traversal"), content="true")
  }
}

test "P0-001: process_message_outcome unsupported engine returns Err" {
  let base = make_users_request()
  let settings = {
    version: base.settings.version,
    engine: "mysql",
    schema: base.settings.schema,
    queries: base.settings.queries,
    codegen: base.settings.codegen,
  }
  let req: GenerateRequest = {
    settings: settings,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"package_name=test",
    global_options: b"",
  }
  match process_message_outcome(encode_request(req)) {
    Ok(_) => inspect(false, content="true")
    Err(msg) => inspect(msg.contains("postgresql"), content="true")
  }
}
