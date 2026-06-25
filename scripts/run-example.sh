#!/usr/bin/env bash
# run-example.sh — One-click build + sqlc generate for examples/users
#
# Usage (from repo root):
#   bash scripts/run-example.sh
#   bash scripts/run-example.sh --release
#   bash scripts/run-example.sh --skip-build
#   bash scripts/run-example.sh --full

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLE="$ROOT/examples/users"
SQLC_YAML="$EXAMPLE/sqlc.yaml"

RELEASE=0
SKIP_BUILD=0
FULL=0

for arg in "$@"; do
  case "$arg" in
    --release) RELEASE=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --full) FULL=1 ;;
    -h|--help)
      echo "Usage: bash scripts/run-example.sh [--release] [--skip-build] [--full]"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

command -v moon >/dev/null 2>&1 || { echo "moon not found. Install: https://www.moonbitlang.com/download/" >&2; exit 1; }
command -v sqlc >/dev/null 2>&1 || { echo "sqlc not found. Install: https://docs.sqlc.dev/en/latest/overview/install.html" >&2; exit 1; }

step() { printf '\n==> %s\n' "$1"; }

echo "MoonBit sqlc WASM Plugin — run example"
echo "Root: $ROOT"

step "Toolchain"
moon --version
sqlc version

if [[ "$FULL" -eq 1 ]]; then
  step "moon check"
  (cd "$ROOT" && moon check)
  step "moon test"
  (cd "$ROOT" && moon test)
fi

if [[ "$RELEASE" -eq 1 ]]; then
  PLUGIN_WASM="$ROOT/_build/wasm/release/build/plugin/plugin.wasm"
  BUILD_CMD=(moon build --target wasm --release)
else
  PLUGIN_WASM="$ROOT/_build/wasm/debug/build/plugin/plugin.wasm"
  BUILD_CMD=(moon build --target wasm)
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  step "${BUILD_CMD[*]}"
  (cd "$ROOT" && "${BUILD_CMD[@]}")
fi

[[ -f "$PLUGIN_WASM" ]] || { echo "plugin.wasm not found: $PLUGIN_WASM" >&2; exit 1; }
echo "plugin.wasm: $PLUGIN_WASM ($(wc -c < "$PLUGIN_WASM") bytes)"

RESTORE_YAML=0
if [[ "$RELEASE" -eq 1 ]] && grep -q 'wasm/debug/build/plugin/plugin.wasm' "$SQLC_YAML"; then
  step "Point sqlc.yaml at release WASM (temporary for this run)"
  sed -i.bak 's|wasm/debug/build/plugin/plugin.wasm|wasm/release/build/plugin/plugin.wasm|' "$SQLC_YAML"
  RESTORE_YAML=1
fi

step "sqlc generate (examples/users)"
(cd "$EXAMPLE" && sqlc generate)

if [[ "$RESTORE_YAML" -eq 1 ]]; then
  mv -f "$SQLC_YAML.bak" "$SQLC_YAML"
fi

TYPES="$EXAMPLE/types.mbt"
QUERIES="$EXAMPLE/queries.mbt"
[[ -f "$TYPES" && -f "$QUERIES" ]] || { echo "Missing types.mbt or queries.mbt" >&2; exit 1; }

step "Generated output"
wc -c "$TYPES" "$QUERIES"
head -n 8 "$TYPES"
echo "  ..."
head -n 8 "$QUERIES"
echo "  ..."

printf '\n[OK] Example ready. Next steps:\n'
echo "  - Inspect: examples/users/types.mbt, examples/users/queries.mbt"
echo "  - Integrate: copy files + see examples/users/moon.pkg.example"
echo "  - Runtime:   moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.6"
