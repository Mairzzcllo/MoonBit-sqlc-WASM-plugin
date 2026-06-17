#!/usr/bin/env python3
"""Run plugin.wasm under wasmtime WASI and capture stdout bytes.

Usage:
  python scripts/capture_wasm_stdout.py [stdin.bin] [--wasm PATH]

If stdin.bin omitted, runs sqlc generate with a temp yaml to capture real request,
or use --minimal for an empty stdin probe.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WASM = ROOT / "_build" / "wasm" / "debug" / "build" / "plugin" / "plugin.wasm"


def hex_dump(data: bytes, max_bytes: int = 128) -> str:
    shown = data[:max_bytes]
    lines = []
    for i in range(0, len(shown), 16):
        chunk = shown[i : i + 16]
        hex_part = " ".join(f"{b:02x}" for b in chunk)
        asc_part = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        lines.append(f"{i:04x}  {hex_part:<48}  {asc_part}")
    if len(data) > max_bytes:
        lines.append(f"... ({len(data)} bytes total, showing first {max_bytes})")
    return "\n".join(lines)


def run_wasm(wasm_path: Path, stdin_data: bytes) -> tuple[int, bytes, bytes]:
    import wasmtime

    engine = wasmtime.Engine()
    store = wasmtime.Store(engine)
    linker = wasmtime.Linker(engine)
    linker.define_wasi()

    with open(wasm_path, "rb") as f:
        module = wasmtime.Module(engine, f.read())

    config = wasmtime.WasiConfig()
    with tempfile.NamedTemporaryFile(delete=False) as stdin_tmp:
        stdin_tmp.write(stdin_data)
        stdin_path = stdin_tmp.name
    stdout_path = tempfile.mktemp(suffix=".stdout")
    stderr_path = tempfile.mktemp(suffix=".stderr")
    open(stdout_path, "wb").close()
    open(stderr_path, "wb").close()
    config.stdin_file = stdin_path
    config.stdout_file = stdout_path
    config.stderr_file = stderr_path
    store.set_wasi(config)

    instance = linker.instantiate(store, module)
    start = instance.exports(store).get("_start")
    if start is None:
        raise RuntimeError("module has no _start export")

    trap = None
    try:
        start(store)
    except wasmtime.ExitTrap as e:
        trap = e
    except Exception as e:
        print(f"TRAP/ERROR: {type(e).__name__}: {e}", file=sys.stderr)
        raise

    stdout = Path(stdout_path).read_bytes()
    stderr = Path(stderr_path).read_bytes()
    code = trap.code if trap else 0
    return code, stdout, stderr


def capture_sqlc_stdin(wasm_path: Path) -> bytes | None:
    """Run sqlc with a wrapper that dumps stdin — fallback: return None."""
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture plugin.wasm stdout under WASI")
    parser.add_argument("stdin_file", nargs="?", help="Raw GenerateRequest bytes")
    parser.add_argument("--wasm", type=Path, default=DEFAULT_WASM)
    parser.add_argument("--minimal", action="store_true", help="Use 82-byte minimal response probe input (empty stdin)")
    parser.add_argument("--sqlc-stdin", action="store_true", help="Capture stdin from sqlc via debug plugin swap")
    args = parser.parse_args()

    if not args.wasm.exists():
        print(f"WASM not found: {args.wasm}", file=sys.stderr)
        return 1

    if args.stdin_file:
        stdin_data = Path(args.stdin_file).read_bytes()
    elif args.minimal:
        stdin_data = b""
    else:
        # Try to get stdin from sqlc by running generate with echo plugin swap
        stdin_data = b""

    print(f"WASM: {args.wasm} ({args.wasm.stat().st_size} bytes)")
    print(f"stdin: {len(stdin_data)} bytes")

    try:
        code, stdout, stderr = run_wasm(args.wasm, stdin_data)
    except Exception as e:
        print(f"FAILED to run wasm: {e}", file=sys.stderr)
        return 2

    print(f"exit: {code}")
    print(f"stdout: {len(stdout)} bytes")
    if stdout:
        print(hex_dump(stdout))
    else:
        print("(empty stdout)")
    if stderr:
        print(f"stderr: {len(stderr)} bytes", file=sys.stderr)
        print(stderr.decode("utf-8", errors="replace"), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
