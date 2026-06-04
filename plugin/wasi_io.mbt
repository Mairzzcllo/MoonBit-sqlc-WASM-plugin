///
/// WASM I/O layer — sqlc plugin protocol over WASI.
/// Platform ABI via inline WAT FFI. Not a public API.
///
/// iovec reserved at [1024,1035] (12 bytes). I/O buffers use dynamically
/// allocated GC-managed Bytes to avoid overlap with MoonBit .data segment
/// (10000+) and TLSF allocator metadata (13136+).
//
// P0-038 / P0-045 resolutions:
//   #13 — Entry point: wasm2wat confirms _start→__moonbit__main→run_io_loop. Resolved.
//   #14 — No byte-copy loop: data moves via WASI fd_read/fd_write iovec, not byte loop. Resolved.
//   #29 — read_all uses dynamically-allocated GC Bytes buffer (P0-068). Resolved.
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
const INITIAL_BUF_SIZE : Int = 65536

// === Inline WAT helpers ====================================================

/// Offset from Bytes object pointer to its data payload.
/// MoonBit Bytes: [refcount:4][array_header:4][data...]
#borrow(b)
fn bytes_data_ptr(b : Bytes) -> Int =
  "(func (param $0 i32) (result i32) (i32.add (local.get $0) (i32.const 8)))"

/// Verify that the hardcoded +8 offset in `bytes_data_ptr` still matches
/// the actual MoonBit Bytes memory layout. Runs once at first I/O call.
fn check_bytes_data_ptr() -> Unit {
  let b = Bytes::make(4, 0xDE)
  let ptr = bytes_data_ptr(b)
  let mut i = 0
  while i < 4 {
    let val = load_u8(ptr + i)
    if val != 0xDE {
      // P0-067: Bytes object layout changed — offset +8 no longer points to data payload
      panic()
    }
    i = i + 1
  }
}

fn store_i32(addr : Int, val : Int) -> Unit =
  "(func (param $0 i32) (param $1 i32) (i32.store (local.get $0) (local.get $1)))"

fn load_i32(addr : Int) -> Int =
  "(func (param $0 i32) (result i32) (i32.load (local.get $0)))"

fn load_u8(addr : Int) -> Int =
  "(func (param $0 i32) (result i32) (i32.load8_u (local.get $0)))"

/// Copy `len` bytes from `src` to `dst` (like memcpy).
fn memory_copy(dst : Int, src : Int, len : Int) -> Unit =
  "(func (param $0 i32) (param $1 i32) (param $2 i32) (memory.copy (local.get $0) (local.get $1) (local.get $2)))"

// === WASI FFI ==============================================================

fn fd_read(fd : Int, iovs : Int, iovs_len : Int, ret : Int) -> Int =
  "wasi_snapshot_preview1" "fd_read"

fn fd_write(fd : Int, iovs : Int, iovs_len : Int, ret : Int) -> Int =
  "wasi_snapshot_preview1" "fd_write"

// === Protocol helpers ======================================================

/// Read all available data from `fd` until EOF.
/// Accumulates into a dynamically-allocated GC-managed Bytes buffer,
/// expanding as needed. Returns the buffer containing all read data.
fn read_all(fd : Int) -> Bytes {
  let mut buf = Bytes::new(INITIAL_BUF_SIZE)
  let mut buf_ptr = bytes_data_ptr(buf)
  let mut capacity = INITIAL_BUF_SIZE
  let mut total = 0
  while true {
    let remaining = capacity - total
    if remaining < 4096 {
      // Grow buffer: allocate larger, copy existing data over
      let new_cap = capacity + 65536
      let new_buf = Bytes::new(new_cap)
      let new_ptr = bytes_data_ptr(new_buf)
      memory_copy(new_ptr, buf_ptr, total)
      buf = new_buf
      buf_ptr = new_ptr
      capacity = new_cap
    }
    store_i32(IOV_BUF, buf_ptr + total)
    store_i32(IOV_LEN, capacity - total)
    let err = fd_read(fd, IOV_BASE, 1, ROF_LEN)
    if err != 0 { break }
    let nread = load_i32(ROF_LEN)
    if nread <= 0 { break }
    total = total + nread
  }
  if total == 0 { return Bytes::make(0, 0) }
  if total < capacity {
    let final_buf = Bytes::new(total)
    memory_copy(bytes_data_ptr(final_buf), buf_ptr, total)
    final_buf
  } else {
    buf
  }
}

/// Write raw response bytes to stdout (no framing).
/// Loops fd_write since WASI pipes may write fewer bytes than requested.
fn write_all(fd : Int, data : Bytes) -> Unit {
  let len = data.length()
  let ptr = bytes_data_ptr(data)
  // Keep data alive throughout the write loop — the compiler may drop
  // the GC reference after bytes_data_ptr returns the raw pointer.
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
  // Touch data to keep the GC reference alive
  let _ = data.length()
}

/// Verify that reserved iovec memory [1024,1035] is not corrupted by GC allocations.
///
/// Writes sentinel values to the iovec region, triggers GC allocation,
/// then verifies sentinels are intact (GC allocator did not overwrite
/// the reserved iovec region).
///
/// Called at startup in run_io_loop().
fn verify_reserved_memory() -> Unit {
  // Phase 1: Write sentinel values to reserved iovec region
  store_i32(IOV_BUF, 0xDEADBEEF)
  store_i32(IOV_LEN, 0xCAFEBABE)
  store_i32(ROF_LEN, 0xFEEDFACE)

  // Phase 2: Trigger GC allocation and verify sentinels are intact
  // (allocator didn't overwrite iovec region)
  let _ = Bytes::new(256)

  if load_i32(IOV_BUF) != 0xDEADBEEF {
    // P0-067: IOV_BUF sentinel corruption — GC allocator overwrote reserved iovec region at offset 1024
    panic()
  }
  if load_i32(IOV_LEN) != 0xCAFEBABE {
    // P0-067: IOV_LEN sentinel corruption — GC allocator overwrote reserved iovec region at offset 1028
    panic()
  }
  if load_i32(ROF_LEN) != 0xFEEDFACE {
    // P0-067: ROF_LEN sentinel corruption — GC allocator overwrote reserved iovec region at offset 1032
    panic()
  }
}

/// Main protocol loop: read raw stdin → process → write raw stdout.
/// sqlc WASM plugin uses unframed protobuf (no 4-byte LE header).
fn run_io_loop() -> Unit {
  check_bytes_data_ptr()
  verify_reserved_memory()
  let body = read_all(0)
  if body.length() == 0 { return () }
  let resp = process_message(body)
  write_all(1, resp)
}

// === Tests: P0-067 — iovec reserved memory region isolation verification ===
// NOTE: verify_reserved_memory() and check_bytes_data_ptr() use inline WAT FFI
// that targets the WASM MVP linear memory model. The moonrun test runner uses
// wasm-gc which has a different object model (GC refs instead of linear memory
// pointers), so these functions cannot be directly invoked in tests.
//
// Runtime verification of the sentinel pattern and boundary checks occurs
// at startup in the actual wasmtime deployment (run_io_loop → check_bytes_data_ptr
// → verify_reserved_memory).
//
// Test coverage here focuses on compile-time validation (constants, type checking)
// and basic non-WAT-dependent behavior that works across all targets.

/// Verify all reserved memory constants have correct values.
/// iovec at [1024,1035] (12 bytes: 3 i32 fields).
test "P0-067: reserved memory constants are correct" {
  inspect(IOV_BASE, content="1024")
  inspect(IOV_BUF, content="1024")
  inspect(IOV_LEN, content="1028")
  inspect(ROF_LEN, content="1032")
  inspect(INITIAL_BUF_SIZE, content="65536")
}

/// Verify correct offsets between reserved memory regions.
/// IOV_BUF, IOV_LEN, ROF_LEN must all be within [1024, 1035].
test "P0-067: reserved memory layout is contiguous and non-overlapping" {
  // iovec region: 1024..1035 (12 bytes: 2 i32 fields + 1 i32 rof_len)
  inspect(IOV_BUF, content="1024")
  inspect(IOV_LEN, content="1028")
  inspect(ROF_LEN, content="1032")
  // iovec occupies exactly 12 bytes [1024, 1035]
  inspect(IOV_LEN - IOV_BUF, content="4")   // 4 bytes per i32
  inspect(ROF_LEN - IOV_LEN, content="4")   // 4 bytes per i32
}

/// Bytes::new creates correctly-sized buffers (non-WAT, pure verification).
/// This validates that the allocation path used in verify_reserved_memory
/// works at the MoonBit level independent of the inline WAT layer.
test "P0-067: Bytes::new allocation works correctly" {
  let b0 = Bytes::new(0)
  inspect(b0.length(), content="0")
  let b1 = Bytes::new(1)
  inspect(b1.length(), content="1")
  let b256 = Bytes::new(256)
  inspect(b256.length(), content="256")
  let b1024 = Bytes::new(1024)
  inspect(b1024.length(), content="1024")
}

/// Multiple interleaved allocations do not corrupt state.
test "P0-067: multiple Bytes::new calls are safe" {
  let b1 = Bytes::new(128)
  inspect(b1.length(), content="128")
  let b2 = Bytes::new(512)
  inspect(b2.length(), content="512")
  let b3 = Bytes::new(1024)
  inspect(b3.length(), content="1024")
  // Verify earlier allocations are still valid
  inspect(b1.length(), content="128")
  inspect(b2.length(), content="512")
}

/// Bytes::make with sentinel pattern works correctly.
/// This is the same pattern used by check_bytes_data_ptr.
test "P0-067: Bytes::make with sentinel pattern works" {
  let b = Bytes::make(4, 0xDE)
  inspect(b.length(), content="4")
  // b[0], b[1], b[2], b[3] should all be 0xDE
  // (Access via Bytes indexing is target-independent)
  inspect(b[0].to_int(), content="222")  // 0xDE = 222
  inspect(b[1].to_int(), content="222")
  inspect(b[2].to_int(), content="222")
  inspect(b[3].to_int(), content="222")
}

/// Bytes::make with different sentinel values to verify no crossover.
test "P0-067: Bytes::make sentinel isolation" {
  let b1 = Bytes::make(4, 0xAB)
  let b2 = Bytes::make(4, 0xCD)
  // Each buffer should contain only its own sentinel
  inspect(b1[0].to_int(), content="171")  // 0xAB
  inspect(b1[3].to_int(), content="171")
  inspect(b2[0].to_int(), content="205")  // 0xCD
  inspect(b2[3].to_int(), content="205")
}

/// INITIAL_BUF_SIZE equals exactly one wasm page (64 KB).
test "P0-068: INITIAL_BUF_SIZE is exactly one wasm page" {
  inspect(INITIAL_BUF_SIZE, content="65536")
  inspect(INITIAL_BUF_SIZE == 65536, content="true")
}


