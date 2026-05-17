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
  inspect(resp.files.length(), content="1")
  inspect(resp.files[0].name, content="lib.mbt")
}

test "wasm: process_message output matches golden" {
  let req = make_users_request()
  let encoded = encode_request(req)
  let response_bytes = process_message(encoded)
  let resp = decode_response(response_bytes)
  let source = @utf8.decode(resp.files[0].contents)
  inspect(source, content=GOLDEN_USERS)
}

test "wasm: process_message deterministic output" {
  let req = make_users_request()
  let encoded = encode_request(req)
  let r1 = process_message(encoded)
  let r2 = process_message(encoded)
  let resp1 = decode_response(r1)
  let resp2 = decode_response(r2)
  let src1 = @utf8.decode(resp1.files[0].contents)
  let src2 = @utf8.decode(resp2.files[0].contents)
  inspect(src1, content=src2)
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

test "wasm: process_message empty request" {
  let response_bytes = process_message(b"")
  let resp = decode_response(response_bytes)
  inspect(resp.files.length(), content="1")
  inspect(resp.files[0].name, content="lib.mbt")
}
