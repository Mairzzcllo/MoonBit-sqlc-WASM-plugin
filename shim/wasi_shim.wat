;; WAT shim ABI bridge — MoonBit sqlc WASM plugin
;;
;; Architecture (reverse direction from initial design):
;;   MoonBit --target wasm CANNOT pass reference types (Bytes, String) across
;;   FFI boundary (error 4042: Invalid stub type). Instead, the shim CALLS
;;   MoonBit through direct WAT-level function calls in the post-merged module.
;;
;; Flow:
;;   1. Shim replaces _start as the entry point (via build script, P0-025)
;;   2. Shim reads 4-byte LE frame header + N-byte body from stdin (WASI fd_read)
;;   3. Shim calls moonbit.bytes_make_raw(N) to allocate MoonBit GC Bytes
;;   4. Shim copies body data into Bytes data area (ptr + 8)
;;   5. Shim calls MoonBit's process_message(bytes_ptr) → gets response Bytes ptr
;;   6. Shim reads response data (ptr + 8) and length (from array header at ptr+4)
;;   7. Shim writes framed response to stdout (WASI fd_write)
;;
;; Reserved memory layout:
;;   [1024, 1027] — iovec.buf_ptr  (i32)
;;   [1028, 1031] — iovec.buf_len  (i32)
;;   [1032, 1035] — rof_len         (i32, bytes read/written)
;;   [1036, ...]  — scratch buffer  (up to ~64KB for incoming message body)
;;
;; MoonBit .data initial segment starts at 10000, TLSF allocator at ~13136.
;; Region [1024, 1035] and scratch at [1036, 65535] are safely non-overlapping.
;;
;; IMPLEMENTATION NOTE:
;; After build merge (P0-025), this shim is injected INTO the MoonBit module's
;; WAT, giving it access to all MoonBit internal functions. The merge script
;; resolves mangled names like $moonbit.bytes_make_raw, $moonbit.array_length,
;; and $moonbit_6process_message.

(module
  ;; Import WASI fd_read/fd_write from host
  (import "wasi_snapshot_preview1" "fd_read"
    (func $wasi_fd_read (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write"
    (func $wasi_fd_write (param i32 i32 i32 i32) (result i32)))

  ;; Import memory from the MoonBit module (wired during module merge).
  (import "moonbit_sqlc" "memory" (memory $mem 1))

  ;; --- Utility: bytes_data_ptr -----------------------------------------------
  ;; Given a MoonBit Bytes GC object pointer, return the data payload pointer.
  ;; Bytes GC layout: [refcount:4][array_header:4][data...]
  (func $bytes_data_ptr (param $b i32) (result i32)
    i32.add (local.get $b) (i32.const 8)
  )

  ;; --- Utility: bytes_length -------------------------------------------------
  ;; Read the length from a MoonBit Bytes object's array header (offset +4).
  ;; Header format: bits [27:0] = length, bits [29:28] = elem_shift, bits [31:30] = kind
  (func $bytes_length (param $b i32) (result i32)
    i32.and
      (i32.load offset=4 (local.get $b))
      (i32.const 0x0FFFFFFF)
  )

  ;; --- Utility: iovec_write --------------------------------------------------
  ;; Setup iovec in reserved memory: store buf_ptr at 1024, buf_len at 1028,
  ;; zero rof_len at 1032, call WASI fd_write. Returns errno.
  (func $iovec_write (param $fd i32) (param $buf_ptr i32) (param $buf_len i32) (result i32)
    (i32.store (i32.const 1024) (local.get $buf_ptr))
    (i32.store (i32.const 1028) (local.get $buf_len))
    (i32.store (i32.const 1032) (i32.const 0))
    (call $wasi_fd_write
      (local.get $fd) (i32.const 1024) (i32.const 1) (i32.const 1032))
  )

  ;; --- Utility: iovec_read ---------------------------------------------------
  ;; Setup iovec in reserved memory, call WASI fd_read. Returns errno.
  (func $iovec_read (param $fd i32) (param $buf_ptr i32) (param $buf_len i32) (result i32)
    (i32.store (i32.const 1024) (local.get $buf_ptr))
    (i32.store (i32.const 1028) (local.get $buf_len))
    (i32.store (i32.const 1032) (i32.const 0))
    (call $wasi_fd_read
      (local.get $fd) (i32.const 1024) (i32.const 1) (i32.const 1032))
  )

  ;; === Entry point wrapper ===================================================
  ;; Replaces MoonBit's _start. Handles the full protocol loop:
  ;;   read frame → process → write frame → repeat
  ;;
  ;; In the merged module, this function replaces the _start export.
  ;; MoonBit's initialization (TLSF, global constructors) must be called first.
  ;;
  ;; FIXME (P0-025): Resolve MoonBit's init function name and process_message
  ;;   mangled name from the compiled WAT.
  ;; (func (export "_start")
  ;;   ...
  ;; )
)
