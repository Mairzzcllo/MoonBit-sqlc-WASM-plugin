<p align="center">
  <a href="quickstart.md"><b>English</b></a>
  ·
  <a href="quickstart.zh.md">中文</a>
  ·
  <a href="quickstart.ja.md">日本語</a>
</p>

# Quick Start Guide

> Generate type-safe MoonBit database code from SQL.

**Documentation:** [README](../README.md) · [Runtime API](runtime-api.md) · [Examples](../examples/README.md) · [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) · [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| [MoonBit](https://www.moonbitlang.com/download/) | ≥ 0.1.20260522 | Build, test, mooncakes |
| [sqlc](https://sqlc.dev) | ≥ v1.27.0 | Tested with v1.31.1 |

PostgreSQL is only used by sqlc to validate `schema.sql` / `query.sql`. Generated code does not connect to a database.

---

## Choose Your Path

| Path | Audience | What you need |
|------|----------|---------------|
| **A — mooncakes.io** | Use generated code in your app | `moon add` only (no plugin repo clone) |
| **B — Plugin repo** | Build WASM plugin, run examples | Clone this repo + sqlc |

---

## Path A — Install Runtime from [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)

Generated code imports `Mairzzcllo/moonbit_sqlc_plugin/runtime`. **The WASM plugin is not on mooncakes** — build it locally (Path B) or download from [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases).

| Item | Value |
|------|-------|
| Package | `Mairzzcllo/moonbit_sqlc_plugin` |
| Version | **0.1.4** |
| Import | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| Target | `wasm-gc` (not `native`) |

### Existing project

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
```

`moon.mod.json` after `moon add`:

```json
{
  "deps": {
    "Mairzzcllo/moonbit_sqlc_plugin": "0.1.4"
  }
}
```

`moon.pkg` (package holding generated code):

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

Copy `types.mbt` + `queries.mbt` from `sqlc generate`, then:

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

> `moon add` pulls from mooncakes.io and **does not require login**.

### New project from scratch

```bash
mkdir myapp && cd myapp
```

`moon.mod.json`:

```json
{
  "name": "your_org/myapp",
  "version": "0.1.0",
  "preferred-target": "wasm-gc",
  "supported-targets": "+wasm+wasm-gc"
}
```

`moon.pkg`:

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime" @runtime,
}
```

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
# copy types.mbt + queries.mbt here
moon check --target wasm-gc
```

Smoke test (from **this plugin repo** root):

```bash
bash scripts/setup-mooncakes.sh --version 0.1.4
# Windows: .\scripts\setup-mooncakes.ps1 -Version 0.1.4
```

---

## Path B — Build Plugin & Generate Code

### 1. Clone and build WASM

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon build --target wasm --release
```

| Mode | Path |
|------|------|
| release (recommended) | `_build/wasm/release/build/plugin/plugin.wasm` |
| debug | `_build/wasm/debug/build/plugin/plugin.wasm` |

One-liner example:

```bash
bash scripts/run-example.sh --release
# Windows: .\scripts\run-example.ps1 -Release
```

### 2. Configure sqlc.yaml

sqlc v2 format:

```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./_build/wasm/release/build/plugin/plugin.wasm
      sha256: ""   # leave empty; sync locally after build
sql:
  - engine: postgresql
    schema: schema.sql
    queries: query.sql
    codegen:
      - out: gen
        plugin: moonbit
        options:
          package_name: myapp
```

> Do not commit platform-specific `sha256` hashes. After building:

```powershell
# Windows
.\scripts\sync-sqlc-sha256.ps1 `
  -WasmPath _build\wasm\release\build\plugin\plugin.wasm `
  -YamlPath examples\users\sqlc.yaml
```

### 3. Write SQL

`schema.sql`:

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

`query.sql`:

```sql
-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: ListUsers :many
SELECT * FROM users ORDER BY created_at DESC;

-- name: CreateUser :one
INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

### 4. Generate

```bash
sqlc generate
```

Output: `types.mbt` (structs, enums, decode) + `queries.mbt` (query functions).

### 5. Link runtime (Path A)

Follow **Path A** above to `moon add` runtime from mooncakes.io.

---

## Use Generated Code

```moonbit
import "Mairzzcllo/moonbit_sqlc_plugin/runtime"

fn example(db: DB) {
  match query_get_user(db, 42L) {
    Ok(user) => println(user.name)
    Err(NoRows) => println("not found")
    Err(e) => println("error: \{e}")
  }
}
```

Construct `DB` in your driver adapter; use `MockDB` for tests (see [Runtime API — MockDB](runtime-api.md#mockdb)).

---

## MockDB for Testing

Basic preset:

```moonbit
test "query with mock" {
  let row = Row::new(fn(i) {
    if i == 0 { "1" } else if i == 1 { "Alice" } else { "" }
  })
  let mock = MockDB::new(
    Ok(1L), Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(row),
  )
  let db = mock.build()
  let _ = query_get_user(db, 1L)
}
```

Builder with exact SQL matching and **strict mode** (unregistered SQL → `Err`):

```moonbit
test "strict mock rejects unknown SQL" {
  let db = MockDBBuilder::new()
    .strict(true)
    .register_query_row(
      "SELECT * FROM users WHERE id = $1",
      Ok(row),
    )
    .build()
  // Unregistered SQL returns Err when strict=true
}
```

---

## Transactions

Generated functions for `:one` / `:many` / `:exec` / `:execrows` also have `Transaction` overloads. `:copyfrom`, `:batch`, and `:execlastid` are DB-only.

```moonbit
fn transfer(db: DB) -> Result[Unit, DBError] {
  let tx = db.begin()?
  let _ = tx.exec("UPDATE accounts SET balance = balance - $1 WHERE id = $2", [...])?
  let _ = tx.exec("UPDATE accounts SET balance = balance + $1 WHERE id = $2", [...])?
  tx.commit()
}
```

---

## Plugin Options

| Option | Default | Description |
|--------|---------|-------------|
| `package_name` | `"main"` | Generated package name |
| `emit_sql_as_comment` | `true` | Embed SQL above functions |
| `emit_json_tags` | `false` | Emit `@json.tag(...)` |
| `emit_empty_slices` | `false` | Return `[]` for empty `:many` |
| `emit_exact_table_names` | `false` | Singularize table names |
| `strict_types` | `true` | Fail on unknown PG types (use `override_<type>=` to customize) |

Unknown query commands (e.g. `:typo`) and malformed plugin options also fail at codegen time with stderr.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `moonbit_simd.h` missing | Use `--target wasm-gc`, not `native` |
| `moon add` not found | Run `moon update` first |
| WASM path wrong | Use `_build/wasm/...`, not `target/` |
| sha256 mismatch | Do not commit local hashes; run `sync-sqlc-sha256.ps1` |
| Unknown PG type at generate | Add `override_<pgtype>=<MoonBitType>` or use supported types |

---

## What's Next

- [Runtime API Reference](runtime-api.md) · [中文](runtime-api.zh.md) · [日本語](runtime-api.ja.md)
- [examples/users/](../examples/users/) — complete working example
- [Examples README](../examples/README.md) · [中文](../examples/README.zh.md) · [日本語](../examples/README.ja.md)
- [README](../README.md) · [中文](../README.zh.md) · [日本語](../README.ja.md)
