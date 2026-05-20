///
/// WASM I/O layer — sqlc plugin protocol over WASI.
/// Platform ABI via inline WAT FFI. Not a public API.
///
/// Reservation: iovec at [1024,1035], scratch at [1036,65535].
/// MoonBit .data starts at 10000+, TLSF allocator at ~13136+.
/// Reserved region has no overlap.
//
// P0-038 / P0-045 resolutions:
//   #13 — Entry point: wasm2wat confirms _start→__moonbit__main→run_io_loop. Resolved.
//   #14 — No byte-copy loop: data moves via WASI fd_read/fd_write iovec, not byte loop. Resolved.
//   #29 — SCRATCH is used as temp buffer for read_all accumulation. Purpose documented.
//   #31 — read_all uses single Bytes::new(total) → byte copy from scratch. Resolved.
//   P0-045 — Removed 4-byte LE frame header; raw protobuf read/write. Resolved.
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

fn store_u8(addr : Int, val : Int) -> Unit =
  "(func (param $0 i32) (param $1 i32) (i32.store8 (local.get $0) (local.get $1)))"

fn load_u8(addr : Int) -> Int =
  "(func (param $0 i32) (result i32) (i32.load8_u (local.get $0)))"

// === WASI FFI ==============================================================

fn fd_read(fd : Int, iovs : Int, iovs_len : Int, ret : Int) -> Int =
  "wasi_snapshot_preview1" "fd_read"

fn fd_write(fd : Int, iovs : Int, iovs_len : Int, ret : Int) -> Int =
  "wasi_snapshot_preview1" "fd_write"

// === Protocol helpers ======================================================

/// Read all available data from `fd` until EOF.
/// Uses scratch buffer in reserved memory for accumulation,
/// then copies into a new GC-managed Bytes.
fn read_all(fd : Int) -> Bytes {
  let scratch = SCRATCH
  let mut total = 0
  while true {
    store_i32(IOV_BUF, scratch + total)
    store_i32(IOV_LEN, 60000 - total)
    let err = fd_read(fd, IOV_BASE, 1, ROF_LEN)
    if err != 0 { break }
    let nread = load_i32(ROF_LEN)
    if nread <= 0 { break }
    total = total + nread
    if total >= 60000 { break }
  }
  if total == 0 { return Bytes::make(0, 0) }
  let buf = Bytes::new(total)
  let dst = bytes_data_ptr(buf)
  let src = scratch
  let mut i = 0
  while i < total {
    let byte_val = load_u8(src + i)
    store_u8(dst + i, byte_val)
    i = i + 1
  }
  buf
}

/// Write raw response bytes to stdout (no framing).
/// Loops fd_write since WASI pipes may write fewer bytes than requested.
fn write_all(fd : Int, data : Bytes) -> Unit {
  let len = data.length()
  let ptr = bytes_data_ptr(data)
  let mut remaining = len
  let mut off = 0
  while remaining > 0 {
    store_i32(IOV_BUF, ptr + off)
    store_i32(IOV_LEN, remaining)
    let err = fd_write(fd, IOV_BASE, 1, ROF_LEN)
    if err != 0 { return () }
    let nwritten = load_i32(ROF_LEN)
    if nwritten <= 0 { return () }
    remaining = remaining - nwritten
    off = off + nwritten
  }
}

/// Main protocol loop: read raw stdin → process → write raw stdout.
/// sqlc WASM plugin uses unframed protobuf (no 4-byte LE header).
fn run_io_loop() -> Unit {
  let body = read_all(0)
  if body.length() == 0 { return () }
  let resp = process_message(body)
  write_all(1, resp)
}
