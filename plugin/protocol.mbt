///|
/// sqlc WASM plugin protocol — unframed raw protobuf over stdin/stdout.
///
/// Native WASI I/O via inline WAT FFI (wasi_io.mbt). WASI fd_read/fd_write
/// handle stdin/stdout I/O directly without 4-byte LE framing.
///
/// Protocol flow:
///   1. run_io_loop reads all bytes from stdin via fd_read until EOF
///   2. run_io_loop calls `process_message(data: Bytes) -> Bytes`
///   3. run_io_loop writes raw response bytes to stdout via fd_write
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

// === Pure data processing entry point (called by shim wrapper) ===

/// Process a raw protobuf GenerateRequest and return raw GenerateResponse bytes.
/// This is the ONLY entry point the shim needs. No I/O, no FFI — pure transform.
///
/// On application-level errors (path validation failure, config errors) and codec-level
/// corruption (corrupt protobuf), returns an empty GenerateResponse instead of crashing
/// the WASM process. Codec errors propagate via `raise` from `decode_request` and are
/// caught here; `abort()` must not be used on decode paths (WASM trap bypasses catch).
pub fn process_message(data: Bytes) -> Bytes {
  try {
    let req = decode_request(data)
    let resp = process_request(req)
    encode_response(resp)
  } catch {
    _ => {
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

