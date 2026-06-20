///|
/// WASM integration tests — P0-026.
/// Validates the full pipeline end-to-end via the process_message entry point,
/// which is exactly what the WAT shim calls in the merged WASM module.
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

test "wasm: process_message roundtrip produces valid response" {
  let req = make_users_request()
  let encoded = encode_request(req)
  let response_bytes = process_message(encoded)
  let resp = decode_response(response_bytes)
  inspect(resp.files.length(), content="2")
  inspect(resp.files[0].name, content="types.mbt")
  inspect(resp.files[1].name, content="queries.mbt")
}

test "wasm: process_message output matches golden" {
  let req = make_users_request()
  let encoded = encode_request(req)
  let response_bytes = process_message(encoded)
  let resp = decode_response(response_bytes)
  let types_source = @utf8.decode(resp.files[0].contents)
  let queries_source = @utf8.decode(resp.files[1].contents)
  // types.mbt contains struct definitions and decode functions
  inspect(types_source.contains("pub struct User"), content="true")
  inspect(types_source.contains("pub fn User::decode"), content="true")
  inspect(types_source.contains("pub fn ListUsersRow::decode"), content="true")
  inspect(types_source.contains("pub fn GetUserRow::decode"), content="true")
  inspect(types_source.contains("pub enum UserRole"), content="true")
  // types.mbt does NOT contain query function declarations
  inspect(types_source.contains("pub fn query_"), content="false")
  // queries.mbt contains query functions
  inspect(queries_source.contains("pub fn query_list_users"), content="true")
  inspect(queries_source.contains("pub fn query_get_user"), content="true")
  inspect(queries_source.contains("pub fn query_delete_user"), content="true")
  // queries.mbt has the runtime import
  inspect(queries_source.contains("import \"Mairzzcllo/moonbit_sqlc_plugin/runtime\""), content="true")
}

test "wasm: process_message deterministic output" {
  let req = make_users_request()
  let encoded = encode_request(req)
  let r1 = process_message(encoded)
  let r2 = process_message(encoded)
  let resp1 = decode_response(r1)
  let resp2 = decode_response(r2)
  let combined1 = @utf8.decode(resp1.files[0].contents) + @utf8.decode(resp1.files[1].contents)
  let combined2 = @utf8.decode(resp2.files[0].contents) + @utf8.decode(resp2.files[1].contents)
  inspect(combined1, content=combined2)
}

test "wasm: process_message empty request" {
  let response_bytes = process_message(b"")
  let resp = decode_response(response_bytes)
  inspect(resp.files.length(), content="2")
  inspect(resp.files[0].name, content="types.mbt")
  inspect(resp.files[1].name, content="queries.mbt")
}

test "wasm: encode_request roundtrip with decode_request" {
  let req = make_users_request()
  let encoded = encode_request(req)
  let decoded = decode_request(encoded)
  inspect(decoded.settings.version, content=req.settings.version)
  inspect(decoded.settings.engine, content=req.settings.engine)
  inspect(decoded.queries.length(), content="3")
  inspect(decoded.queries[0].name, content="list_users")
  inspect(decoded.queries[1].name, content="get_user")
  inspect(decoded.queries[2].name, content="delete_user")
}

/// P0-061: process_message returns empty response on error instead of crashing.
/// When process_request raises an error (e.g., path traversal in out_name),
/// process_message catches it and returns an empty GenerateResponse.
test "P0-061: process_message error handling returns empty response" {
  let base = make_users_request()
  // Create a request with a path traversal out_name to trigger a raise from validate_output_path
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
  let encoded = encode_request(req)
  let response_bytes = process_message(encoded)
  // Should get an empty response (no files) instead of crashing
  let resp = decode_response(response_bytes)
  inspect(resp.files.length(), content="0")
}

/// P0-061: process_message with empty buffer returns valid response.
/// An empty protobuf buffer decodes to a default GenerateRequest,
/// which processes normally and produces output files.
test "P0-061: process_message empty buffer produces response" {
  let response_bytes = process_message(b"")
  let resp = decode_response(response_bytes)
  // Empty request produces both types.mbt and queries.mbt
  inspect(resp.files.length(), content="2")
}
