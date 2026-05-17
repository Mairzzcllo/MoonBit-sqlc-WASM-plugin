///
/// WASM I/O layer — sqlc plugin protocol over WASI.
/// Platform ABI via inline WAT FFI. Not a public API.
///
/// Reservation: iovec at [1024,1035], scratch at [1036,65535].
/// MoonBit .data starts at 10000+, TLSF allocator at ~13136+.
/// Reserved region has no overlap.

const IOV_BASE   : Int = 1024
const IOV_BUF    : Int = IOV_BASE
const IOV_LEN    : Int = IOV_BASE + 4
const ROF_LEN    : Int = 1032
const SCRATCH    : Int = 1036

// === Inline WAT helpers ====================================================

/// Offset from Bytes object pointer to its data payload.
/// MoonBit Bytes: [refcount:4][array_header:4][data...]
#borrow(b)
fn bytes_data_ptr(b : Bytes) -> Int =
  "(func (param $0 i32) (result i32) (i32.add (local.get $0) (i32.const 8)))"

fn store_i32(addr : Int, val : Int) -> Unit =
  "(func (param $0 i32) (param $1 i32) (i32.store (local.get $0) (local.get $1)))"

fn load_i32(addr : Int) -> Int =
  "(func (param $0 i32) (result i32) (i32.load (local.get $0)))"

// === WASI FFI ==============================================================

fn fd_read(fd : Int, iovs : Int, iovs_len : Int, ret : Int) -> Int =
  "wasi_snapshot_preview1" "fd_read"

fn fd_write(fd : Int, iovs : Int, iovs_len : Int, ret : Int) -> Int =
  "wasi_snapshot_preview1" "fd_write"

// === Protocol helpers ======================================================

/// Read 4-byte LE frame header from stdin. Returns body length.
/// On EOF or read error, returns 0.
fn read_frame_header() -> Int {
  let mut remaining = 4
  let mut offset = 0
  while remaining > 0 {
    store_i32(IOV_BUF, SCRATCH + offset)
    store_i32(IOV_LEN, remaining)
    let err = fd_read(0, IOV_BASE, 1, ROF_LEN)
    if err != 0 { return 0 }
    let nread = load_i32(ROF_LEN)
    if nread <= 0 { return 0 }
    remaining = remaining - nread
    offset = offset + nread
  }
  load_i32(SCRATCH)
}

/// Read exactly `len` bytes from stdin into a new GC-managed Bytes.
/// Loops fd_read since WASI pipes may return fewer bytes than requested.
fn read_body(len : Int) -> Bytes {
  let buf = Bytes::new(len)
  let ptr = bytes_data_ptr(buf)
  let mut remaining = len
  let mut offset = 0
  while remaining > 0 {
    store_i32(IOV_BUF, ptr + offset)
    store_i32(IOV_LEN, remaining)
    let err = fd_read(0, IOV_BASE, 1, ROF_LEN)
    if err != 0 { break }
    let nread = load_i32(ROF_LEN)
    if nread <= 0 { break }
    remaining = remaining - nread
    offset = offset + nread
  }
  buf
}

/// Write framed response: 4-byte LE header followed by data.
/// Loops fd_write since WASI pipes may write fewer bytes than requested.
fn write_frame(data : Bytes) -> Unit {
  let len = data.length()
  // Debug: dump first 4 bytes of response to stderr
  let p = bytes_data_ptr(data)
  let m = if len >= 4 { load_i32(p) } else { 0 }
  store_i32(SCRATCH, m)
  store_i32(IOV_BUF, SCRATCH)
  store_i32(IOV_LEN, 4)
  let _ = fd_write(2, IOV_BASE, 1, ROF_LEN)
  
  // Write 4-byte LE frame header
  store_i32(SCRATCH, len)
  store_i32(IOV_BUF, SCRATCH)
  store_i32(IOV_LEN, 4)
  let mut remaining = 4
  let mut hdr_off = 0
  while remaining > 0 {
    store_i32(IOV_BUF, SCRATCH + hdr_off)
    store_i32(IOV_LEN, remaining)
    let err = fd_write(1, IOV_BASE, 1, ROF_LEN)
    if err != 0 { return () }
    let nwritten = load_i32(ROF_LEN)
    if nwritten <= 0 { return () }
    remaining = remaining - nwritten
    hdr_off = hdr_off + nwritten
  }
  // Write data body
  let ptr = bytes_data_ptr(data)
  remaining = len
  let mut off = 0
  while remaining > 0 {
    store_i32(IOV_BUF, ptr + off)
    store_i32(IOV_LEN, remaining)
    let err = fd_write(1, IOV_BASE, 1, ROF_LEN)
    if err != 0 { return () }
    let nwritten = load_i32(ROF_LEN)
    if nwritten <= 0 { return () }
    remaining = remaining - nwritten
    off = off + nwritten
  }
  ()
}

/// Main protocol loop: read frame → process → write frame.
fn run_io_loop() -> Unit {
  while true {
    let frame_len = read_frame_header()
    if frame_len == 0 { break }
    let body = read_body(frame_len)
    let resp = process_message(body)
    write_frame(resp)
  }
}
