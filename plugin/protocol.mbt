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
/// encode_u32_le/decode_u32_le remain available for protobuf varint fields
/// and are no longer used for I/O framing.
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

// === 4-byte LE framing (pure MoonBit, used by wasi_io.mbt I/O loop and tests) ===

/// Encode `v` as 4-byte little-endian byte sequence.
pub fn encode_u32_le(v: Int) -> Bytes {
  Bytes::from_array([
    (v & 0xFF).to_byte(),
    ((v >> 8) & 0xFF).to_byte(),
    ((v >> 16) & 0xFF).to_byte(),
    ((v >> 24) & 0xFF).to_byte(),
  ])
}

/// Decode the first 4 bytes of `b` as a little-endian integer.
/// Returns 0 if `b` is shorter than 4 bytes.
pub fn decode_u32_le(b: Bytes) -> Int {
  if b.length() < 4 { return 0 }
  b[0].to_int() | (b[1].to_int() << 8) | (b[2].to_int() << 16) | (b[3].to_int() << 24)
}

// === Pure data processing entry point (called by shim wrapper) ===

/// Process a raw protobuf GenerateRequest and return raw GenerateResponse bytes.
/// This is the ONLY entry point the shim needs. No I/O, no FFI — pure transform.
pub fn process_message(data: Bytes) -> Bytes {
  let req = decode_request(data)
  let resp = process_request(req)
  encode_response(resp)
}

// === Tests ===

test "encode_u32_le/decode: roundtrip 0" {
  let bs = encode_u32_le(0)
  inspect(decode_u32_le(bs), content="0")
}

test "encode_u32_le/decode: roundtrip 42" {
  let bs = encode_u32_le(42)
  inspect(decode_u32_le(bs), content="42")
}

test "encode_u32_le/decode: roundtrip 65535" {
  let bs = encode_u32_le(65535)
  inspect(decode_u32_le(bs), content="65535")
}

test "encode_u32_le: byte layout for 256" {
  let bs = encode_u32_le(256)
  inspect(bs[0].to_int(), content="0")
  inspect(bs[1].to_int(), content="1")
  inspect(bs[2].to_int(), content="0")
  inspect(bs[3].to_int(), content="0")
}

test "decode_u32_le: max uint32 wraps to -1" {
  let bs = Bytes::from_array([0xFF, 0xFF, 0xFF, 0xFF])
  inspect(decode_u32_le(bs), content="-1")
}

test "encode_u32_le/decode: roundtrip 1" {
  let bs = encode_u32_le(1)
  inspect(decode_u32_le(bs), content="1")
}

test "encode_u32_le/decode: roundtrip 255" {
  let bs = encode_u32_le(255)
  inspect(decode_u32_le(bs), content="255")
}

test "encode_u32_le/decode: roundtrip 2147483647" {
  let bs = encode_u32_le(2147483647)
  inspect(decode_u32_le(bs), content="2147483647")
}

test "encode_u32_le: zero-length frame encoding" {
  let bs = encode_u32_le(0)
  // LE representation of 0: [0, 0, 0, 0]
  inspect(bs[0].to_int(), content="0")
  inspect(bs[1].to_int(), content="0")
  inspect(bs[2].to_int(), content="0")
  inspect(bs[3].to_int(), content="0")
  inspect(decode_u32_le(bs), content="0")
}

test "decode_u32_le: empty input returns 0" {
  let bs = Bytes::make(0, 0)
  inspect(decode_u32_le(bs), content="0")
}

test "decode_u32_le: 3-byte input returns 0" {
  let bs = Bytes::make(3, 0)
  inspect(decode_u32_le(bs), content="0")
}

test "decode_u32_le: 1-byte input returns 0" {
  let bs = Bytes::make(1, 0)
  inspect(decode_u32_le(bs), content="0")
}

test "encode_u32_le: large value byte pattern" {
  // 16909060 = 0x01020304
  let bs = encode_u32_le(16909060)
  inspect(bs[0].to_int(), content="4")
  inspect(bs[1].to_int(), content="3")
  inspect(bs[2].to_int(), content="2")
  inspect(bs[3].to_int(), content="1")
}

test "decode_u32_le: negative bytes decode as large unsigned" {
  // byte array of value -1 in two's complement 32-bit LE: [0xFF, 0xFF, 0xFF, 0xFF]
  let bs = Bytes::from_array([0xFF, 0xFF, 0xFF, 0xFF])
  inspect(decode_u32_le(bs), content="-1")
}

test "encode_u32_le: max positive value" {
  let bs = encode_u32_le(2147483647)
  // MSB = 0x7F in LE format
  inspect(bs[3].to_int(), content="127")
  inspect(decode_u32_le(bs), content="2147483647")
}

test "decode_u32_le: 4-byte input with value 0" {
  let bs = Bytes::from_array([0, 0, 0, 0])
  inspect(decode_u32_le(bs), content="0")
}
