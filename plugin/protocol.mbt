///|
/// I/O framing utilities for sqlc WASM plugin protocol.
///
/// MoonBit `--target wasm` does not support reference types (Bytes, String)
/// across FFI boundary. Instead, MoonBit exposes pure computation functions.
/// All raw I/O (WASI fd_read/fd_write, iovec construction, LE framing) is
/// handled by the WAT shim wrapper (shim/wasi_shim.wat) injected during the
/// post-merge build step (P0-025).
///
/// Protocol flow (shim → MoonBit):
///   1. Shim reads 4-byte LE frame header from stdin
///   2. Shim reads N-byte body from stdin
///   3. Shim allocates MoonBit GC Bytes, copies body in
///   4. Shim calls MoonBit's `process_message(data: Bytes) -> Bytes`
///   5. Shim reads response Bytes, writes framed response to stdout

// === 4-byte LE framing (pure MoonBit, used by shim-wrapper and tests) ===

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
pub fn decode_u32_le(b: Bytes) -> Int {
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

test "decode_u32_le: partial data" {
  // If only 0-3 bytes provided, decode_u32_le still reads 4 bytes
  // (access out of bounds — function assumes valid input)
  let bs = Bytes::make(4, 0)
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
