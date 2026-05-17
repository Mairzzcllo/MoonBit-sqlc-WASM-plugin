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
;; IMPLEMENTATION NOTE (P0-025):
;; After build merge, this shim is injected INTO the MoonBit module's
;; WAT, giving it access to all MoonBit internal functions. The merge script
;; (scripts/merge-shim.ps1) resolves mangled names for:
;;   $moonbit_init         — MoonBit entry point (replaced by actual mangled _start)
;;   $process_message      — MoonBit's process_message (resolved from moonc output)
;;   $moonbit.bytes_make_raw — MoonBit runtime Bytes allocator
;;   $moonbit.array_length — MoonBit array length accessor
;;
;; These placeholders are replaced by the merge script via regex substitution
;; against the actual mangled names in the MoonBit WAT output.

(module
  ;; Import WASI fd_read/fd_write from host
  (import "wasi_snapshot_preview1" "fd_read"
    (func $wasi_fd_read (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write"
    (func $wasi_fd_write (param i32 i32 i32 i32) (result i32)))

  ;; Memory is shared implicitly after text-level merge — the MoonBit module
  ;; declares memory; shim functions access it directly within the same module.

  ;; --- Utility: bytes_data_ptr -----------------------------------------------
  ;; Given a MoonBit Bytes GC object pointer, return the data payload pointer.
  ;; Bytes GC layout: [refcount:4][array_header:4][data...]
  (func $bytes_data_ptr (param $b i32) (result i32)
    (i32.add (local.get $b) (i32.const 8))
  )

  ;; --- Utility: bytes_length -------------------------------------------------
  ;; Read the length from a MoonBit Bytes object's array header (offset +4).
  ;; Header format: bits [27:0] = length, bits [29:28] = elem_shift, bits [31:30] = kind
  (func $bytes_length (param $b i32) (result i32)
    (i32.and
      (i32.load offset=4 (local.get $b))
      (i32.const 0x0FFFFFFF))
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
;; === _start entry point ====================================================
;; Replaces MoonBit's _start. Handles the full protocol loop:
;;   read frame → process → write frame → repeat
;;
;; In the merged module, this function:
;;   1. Calls MoonBit's main/TLSF init
;;   2. Enters the read-process-write loop
;;
;; NOTE: MoonBit core initialization (GC/TLSF) is performed by MoonBit's
;; original _start. During text-level merge, this export OVERRIDES the
;; MoonBit _start, so the shim MUST call MoonBit's init explicitly.
;;
;; The mangled function names below are resolved by the merge script
;; (scripts/merge-shim.ps1) from the MoonBit compiler output.
(func (export "_start")
  (local $frame_len i32)
  (local $input_bytes i32)
  (local $input_data_ptr i32)
  (local $output_bytes i32)
  (local $output_data_ptr i32)
  (local $output_len i32)

  ;; Call MoonBit runtime initialization (TLSF, globals).
  ;; In the merged module, this calls the MoonBit _start target.
  ;; The name $moonbit_init is a placeholder; merge-shim.ps1 replaces
  ;; it with the actual mangled name (e.g., $_M0FP017____moonbit__main).
  call $moonbit_init

  ;; Main protocol loop: read frame → process → write frame
  (block $done
    (loop $loop
      ;; Step 1: Read 4-byte LE frame header from stdin (fd 0)
      ;; Uses the scratch buffer at [1036, 1040] for the 4-byte header.
      (call $iovec_read
        (i32.const 0)            ;; fd = stdin
        (i32.const 1036)         ;; buf = scratch[0..4]
        (i32.const 4))           ;; len = 4 bytes
      drop                        ;; ignore errno

      ;; Step 2: Decode frame length from header
      (local.set $frame_len
        (i32.load (i32.const 1036)))

      ;; If frame_len == 0, exit (EOF sentinel)
      (if
        (i32.eqz (local.get $frame_len))
        (then (br $done)))

      ;; Step 3: Read N-byte body into scratch buffer
      (call $iovec_read
        (i32.const 0)
        (i32.const 1036)         ;; reuse scratch from offset 0
        (local.get $frame_len))
      drop

      ;; Step 4: Allocate MoonBit GC Bytes object for input
      ;; MoonBit Bytes layout: [refcount:4][array_header:4][data...]
      ;; We call the MoonBit runtime function to allocate:
      ;;   $moonbit.bytes_make_raw(N) -> Bytes ptr
      (local.set $input_bytes
        (call $moonbit.bytes_make_raw
          (local.get $frame_len)))

      ;; Step 5: Copy scratch buffer data into Bytes data area
      ;; Bytes data starts at input_bytes + 8
      (local.set $input_data_ptr
        (call $bytes_data_ptr
          (local.get $input_bytes)))

      ;; Memory copy from scratch to Bytes data
      (call $memcpy
        (local.get $input_data_ptr)    ;; dst = Bytes data area
        (i32.const 1036)               ;; src = scratch buffer
        (local.get $frame_len))        ;; len

      ;; Step 6: Set array header length for Bytes object
      ;; Header: bits [27:0] = length, bits[29:28] = elem_shift(0 for bytes), bits[31:30] = kind(0)
      (i32.store offset=4
        (local.get $input_bytes)
        (local.get $frame_len))

      ;; Step 7: Call MoonBit's process_message(input_bytes) -> response Bytes ptr
      (local.set $output_bytes
        (call $process_message
          (local.get $input_bytes)))

      ;; Step 8: Extract response data pointer and length
      (local.set $output_data_ptr
        (call $bytes_data_ptr
          (local.get $output_bytes)))
      (local.set $output_len
        (call $bytes_length
          (local.get $output_bytes)))

      ;; Step 9: Write 4-byte LE frame header to stdout (fd 1)
      (i32.store (i32.const 1036) (local.get $output_len))
      (call $iovec_write
        (i32.const 1)            ;; fd = stdout
        (i32.const 1036)         ;; buf = scratch[0..4]
        (i32.const 4))           ;; len = 4
      drop

      ;; Step 10: Write response body to stdout
      (call $iovec_write
        (i32.const 1)
        (local.get $output_data_ptr)
        (local.get $output_len))
      drop

      ;; Repeat
      (br $loop)))

  ;; Process completed normally
  (return)
)

;; === Memory copy utility ===================================================
;; Copies `len` bytes from `src` to `dst`.
;; Used to move data between scratch buffer and MoonBit GC heap.
(func $memcpy
  (param $dst i32) (param $src i32) (param $len i32)
  (local $i i32)
  (loop $copy_loop
    (if (i32.lt_s (local.get $i) (local.get $len))
      (then
        (i32.store8
          (i32.add (local.get $dst) (local.get $i))
          (i32.load8_u
            (i32.add (local.get $src) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $copy_loop))))
)
)
