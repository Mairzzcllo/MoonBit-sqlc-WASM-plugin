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
pub fn process_message(data: Bytes) -> Bytes raise {
  let req = decode_request(data)
  let resp = process_request(req)
  encode_response(resp)
}


