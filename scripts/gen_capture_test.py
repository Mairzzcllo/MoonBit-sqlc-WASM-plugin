#!/usr/bin/env python3
"""Generate plugin/capture_decode_test.mbt from sqlc_stdin.bin for one-shot decode debugging."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = ROOT / "scripts" / "harness-fixtures" / "sqlc_stdin.bin"
out = ROOT / "plugin" / "capture_decode_test.mbt"

data = src.read_bytes()
items = ", ".join(f"({b}).to_byte()" for b in data)
content = f'''/// Auto-generated from sqlc_stdin.bin — do not commit (local debug only).
test "capture: decode real sqlc stdin fixture" {{
  let data = Bytes::from_array([{items}])
  let result = try {{
    let req = decode_request(data)
    let _ = req.queries.length()
    "ok"
  }} catch {{
    _ => "fail"
  }}
  inspect(result, content="ok")
}}
'''
out.write_text(content, encoding="utf-8")
print(f"Wrote {out} ({len(data)} bytes)")
