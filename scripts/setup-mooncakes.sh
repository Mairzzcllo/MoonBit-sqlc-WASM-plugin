#!/usr/bin/env bash
# setup-mooncakes.sh — Linux/macOS: verify mooncakes runtime install (wasm-gc only)
#
# Usage (from repo root):
#   bash scripts/setup-mooncakes.sh
#   bash scripts/setup-mooncakes.sh --version 0.1.3

set -euo pipefail

VERSION="0.1.3"
PACKAGE="Mairzzcllo/moonbit_sqlc_plugin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: bash scripts/setup-mooncakes.sh [--version X.Y.Z]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SMOKE="${TMPDIR:-/tmp}/moonbit_sqlc_mooncakes_smoke_$$"

step() { printf '\n==> %s\n' "$1"; }

command -v moon >/dev/null 2>&1 || { echo "moon not found. Install: https://www.moonbitlang.com/download/" >&2; exit 1; }

echo "MoonBit sqlc — mooncakes setup (Linux/macOS)"
echo "Package: ${PACKAGE}@${VERSION}"

step "MoonBit toolchain"
moon --version

CRED="${HOME}/.moon/credentials.json"
if [[ -f "$CRED" ]]; then
  echo "mooncakes credentials: OK ($CRED)"
else
  echo "mooncakes credentials: not found (optional for moon add)"
  echo "  Run: moon login   or   moon register"
fi

step "Registry index"
( cd "$ROOT" && moon update )

step "Plugin repo (wasm-gc)"
( cd "$ROOT" && moon check --target wasm-gc )
( cd "$ROOT" && moon test --target wasm-gc )

step "Consumer smoke test (moon add + check)"
rm -rf "$SMOKE"
mkdir -p "$SMOKE"

cat > "$SMOKE/moon.mod.json" <<EOF
{
  "name": "Mairzzcllo/sqlc_consumer_smoke",
  "version": "0.0.1",
  "preferred-target": "wasm-gc",
  "supported-targets": "+wasm+wasm-gc",
  "deps": {
    "${PACKAGE}": "${VERSION}"
  }
}
EOF

cat > "$SMOKE/moon.pkg" <<EOF
import {
  "${PACKAGE}/runtime" @runtime,
}
EOF

cat > "$SMOKE/smoke.mbt" <<'EOF'
///|
test "runtime import smoke" {
  let db = @runtime.MockDB::default_ok().build()
  let _ = db
}
EOF

( cd "$SMOKE" && moon update && moon check --target wasm-gc && moon test --target wasm-gc )
rm -rf "$SMOKE"

step "Native backend skip (expected on wasm-only setup)"
if ( cd "$ROOT" && moon check --target native >/dev/null 2>&1 ); then
  echo "native check unexpectedly passed"
else
  echo "native check skipped as expected (wasm-only project)"
fi

printf '\n[OK] mooncakes runtime %s@%s works (wasm-gc).\n' "$PACKAGE" "$VERSION"
echo "Use in your app:"
echo "  moon add ${PACKAGE}@${VERSION}"
echo "  moon check --target wasm-gc"
