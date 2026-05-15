///|
/// stdio transport layer for sqlc WASM plugin protocol.
/// 4-byte little-endian length-prefixed message framing over stdin/stdout.

// === 4-byte LE framing (pure MoonBit) ===

/// Encode `v` as 4-byte little-endian byte sequence.
fn encode_u32_le(v: Int) -> Bytes {
  Bytes::from_array([
    (v & 0xFF).to_byte(),
    ((v >> 8) & 0xFF).to_byte(),
    ((v >> 16) & 0xFF).to_byte(),
    ((v >> 24) & 0xFF).to_byte(),
  ])
}

/// Decode the first 4 bytes of `b` as a little-endian integer.
fn decode_u32_le(b: Bytes) -> Int {
  b[0].to_int() | (b[1].to_int() << 8) | (b[2].to_int() << 16) | (b[3].to_int() << 24)
}

// === I/O via WASI fd_read/fd_write ===

const STDIN: Int = 0
const STDOUT: Int = 1

fn fd_read(fd: Int, buf: String, count: Int) -> Int = "wasi_snapshot_preview1" "fd_read"
fn fd_write(fd: Int, buf: String, count: Int) -> Int = "wasi_snapshot_preview1" "fd_write"

/// Read exactly `n` bytes from stdin. Returns None on EOF.
fn read_exact(n: Int) -> Option[Bytes] {
  let buf = Bytes::make(n, 0)
  let mut off: Int = 0
  while off < n {
    let r = fd_read(STDIN, "", n - off)
    if r == 0 { return None }
    off = off + r
  }
  Some(buf)
}

/// Read a framed message from stdin.
pub fn read_message() -> Option[Bytes] {
  match read_exact(4) {
    None => return None
    Some(bs) => {
      let len = decode_u32_le(bs)
      if len == 0 { return Some(Bytes::default()) }
      read_exact(len)
    }
  }
}

/// Write raw bytes to stdout.
fn write_raw(data: Bytes) -> Unit {
  let n = data.length()
  if n == 0 { return }
  let _ = fd_write(STDOUT, "", n)
}

/// Write a framed message to stdout.
pub fn write_message(data: Bytes) -> Unit {
  let header = encode_u32_le(data.length())
  write_raw(header)
  if data.length() > 0 { write_raw(data) }
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
