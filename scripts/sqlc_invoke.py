#!/usr/bin/env python3
"""Invoke plugin.wasm like sqlc (wasi stdin/stdout) and diff stdout against moonrun expected.

Usage:
  python scripts/sqlc_invoke.py [--wasm PATH] [--stdin PATH] [--expect PATH]

If --stdin omitted, runs echo-self test with minimal_response.bin fixture.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WASM = ROOT / "_build" / "wasm" / "debug" / "build" / "plugin" / "plugin.wasm"


def run_wasm(wasm_path: Path, stdin_data: bytes) -> tuple[int, bytes, bytes]:
    import wasmtime

    engine = wasmtime.Engine()
    store = wasmtime.Store(engine)
    linker = wasmtime.Linker(engine)
    linker.define_wasi()

    module = wasmtime.Module(engine, wasm_path.read_bytes())

    with tempfile.NamedTemporaryFile(delete=False) as stdin_tmp:
        stdin_tmp.write(stdin_data)
        stdin_path = stdin_tmp.name
    stdout_path = tempfile.mktemp(suffix=".stdout")
    stderr_path = tempfile.mktemp(suffix=".stderr")
    Path(stdout_path).touch()
    Path(stderr_path).touch()

    config = wasmtime.WasiConfig()
    config.stdin_file = stdin_path
    config.stdout_file = stdout_path
    config.stderr_file = stderr_path
    store.set_wasi(config)

    instance = linker.instantiate(store, module)
    start = instance.exports(store)["_start"]
    trap = None
    try:
        start(store)
    except wasmtime.ExitTrap as e:
        trap = e

    stdout = Path(stdout_path).read_bytes()
    stderr = Path(stderr_path).read_bytes()
    code = trap.code if trap else 0
    return code, stdout, stderr


def hex_diff(a: bytes, b: bytes, limit: int = 8) -> str:
    n = min(len(a), len(b), limit)
    lines = []
    for i in range(n):
        if a[i] != b[i]:
            lines.append(f"  offset {i}: got {a[i]:02x} expected {b[i]:02x}")
    if len(a) != len(b):
        lines.append(f"  length: got {len(a)} expected {len(b)}")
    return "\n".join(lines) if lines else "  (identical prefix)"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wasm", type=Path, default=DEFAULT_WASM)
    parser.add_argument("--stdin", type=Path)
    parser.add_argument("--expect", type=Path, help="Expected stdout bytes for diff")
    args = parser.parse_args()

    if not args.wasm.exists():
        print(f"WASM missing: {args.wasm}", file=sys.stderr)
        return 1

    stdin_data = args.stdin.read_bytes() if args.stdin else b""
    code, stdout, stderr = run_wasm(args.wasm, stdin_data)
    print(f"exit={code} stdin={len(stdin_data)} stdout={len(stdout)} stderr={len(stderr)}")
    if stdout:
        print(stdout[:64].hex())
    if args.expect:
        expected = args.expect.read_bytes()
        print("diff vs expect:")
        print(hex_diff(stdout, expected))
        return 0 if stdout == expected else 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
