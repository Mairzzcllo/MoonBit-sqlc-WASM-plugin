<p align="center">
  <img src="https://img.shields.io/badge/MoonBit-0.1.20260522-db6e2a?style=for-the-badge" alt="MoonBit"/>
  <img src="https://img.shields.io/badge/sqlc-v1_WASM_plugin-00b4d8?style=for-the-badge" alt="sqlc"/>
  <img src="https://img.shields.io/badge/mooncakes-0.1.5-orange?style=for-the-badge" alt="mooncakes"/>
  <img src="https://img.shields.io/badge/license-Apache--2.0-brightgreen?style=for-the-badge" alt="License"/>
</p>

<p align="center">
  <a href="README.md"><b>English</b></a>
  路
  <a href="README.zh.md">涓枃</a>
  路
  <a href="README.ja.md">鏃ユ湰瑾?/a>
</p>

# MoonBit sqlc WASM Plugin

## Description

**MoonBit sqlc WASM Plugin** is a [sqlc](https://sqlc.dev) WASM code generator for [MoonBit](https://www.moonbitlang.com/). It reads `schema.sql` and `query.sql`, validates SQL and types at compile time, and emits type-safe MoonBit source (`types.mbt` + `queries.mbt`).

Generated functions take `DB` or `Transaction` directly 鈥?no ORM, no reflection. The runtime is published on [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin); the WASM plugin is built locally or downloaded from [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases).

**Current scope:** PostgreSQL 路 sqlc v1.27+ (tested v1.31.1) 路 MoonBit WASM (WASI preview1)

# Key Features

## Type-Safe Codegen

- `Result[T, DBError]` for all query and decode paths
- Compile-time SQL/type validation via sqlc
- AST 鈫?Pretty Printer pipeline (no string concatenation)

## Minimal Runtime

- `DB`, `Transaction`, `Row`, `RowIter`, `Value`, `MockDB`
- Published as `Mairzzcllo/moonbit_sqlc_plugin/runtime` on mooncakes **0.1.5**
- Target `wasm-gc` 鈥?no native driver required in generated code

## Plugin-Host Separation

- WASM plugin handles codegen only
- WASI stdin/stdout protobuf I/O (inline WAT FFI, no external shim)
- Dual-file output: `types.mbt` + `queries.mbt`

# Quick Start

Two paths 鈥?pick the one that matches your role:

| Path | Audience | What you need |
|------|----------|---------------|
| **A 鈥?mooncakes.io** | Use generated `types.mbt` / `queries.mbt` in your app | MoonBit + `moon add` (no plugin repo clone) |
| **B 鈥?Plugin repo** | Build WASM plugin, run examples, contribute | MoonBit + sqlc + this repository |

---

## A. App Developers 鈥?[mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)

Generated code imports `Mairzzcllo/moonbit_sqlc_plugin/runtime`. Install it from the MoonBit package registry 鈥?**the WASM plugin itself is not on mooncakes**.

| Item | Value |
|------|-------|
| Package | `Mairzzcllo/moonbit_sqlc_plugin` |
| Version | **0.1.5** |
| Import path | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| Docs | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| Target | `wasm-gc` (do not use `native`) |

### Add runtime to an existing project

In your MoonBit project root (`moon.mod.json` already exists):

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.5
moon check --target wasm-gc
```

`moon add` writes into `moon.mod.json`:

```json
{
  "deps": {
    "Mairzzcllo/moonbit_sqlc_plugin": "0.1.5"
  }
}
```

Add to the package `moon.pkg` that holds generated code:

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

Generated files already contain:

```moonbit
import "Mairzzcllo/moonbit_sqlc_plugin/runtime"
```

Copy `types.mbt` + `queries.mbt` from `sqlc generate`, then verify:

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

> `moon add` pulls from [mooncakes.io](https://mooncakes.io/) and **does not require login**. Only `moon publish` needs credentials.

### Minimal new project (from scratch)

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

Then:

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.5
# copy types.mbt + queries.mbt here
moon check --target wasm-gc
```

### Upgrade / remove

```bash
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.5   # upgrade
moon remove Mairzzcllo/moonbit_sqlc_plugin       # remove
```

Smoke test (run from **this plugin repo** root):

```powershell
.\scripts\setup-mooncakes.ps1 -Version 0.1.5
```

```bash
bash scripts/setup-mooncakes.sh --version 0.1.5
```

---

## B. Plugin Developers 鈥?Build WASM & Generate Code

### Requirements

| Tool | Version | Notes |
|------|---------|-------|
| [MoonBit](https://www.moonbitlang.com/download/) | 鈮?0.1.20260522 | Build, test, mooncakes |
| [sqlc](https://docs.sqlc.dev/en/latest/overview/install.html) | 鈮?v1.27.0 | Invokes WASM plugin |

PostgreSQL is only used by sqlc to validate schema/query files. Generated code does not connect to a database.

## Clone Repository

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon check
moon test
```

## Build WASM Plugin

```bash
moon build --target wasm --release
```

| Mode | Path |
|------|------|
| release (recommended) | `_build/wasm/release/build/plugin/plugin.wasm` |
| debug | `_build/wasm/debug/build/plugin/plugin.wasm` |

## Run Example

### Linux / macOS

```bash
chmod +x scripts/run-example.sh scripts/setup-mooncakes.sh
bash scripts/run-example.sh
bash scripts/run-example.sh --full --release --skip-build
```

### Windows (PowerShell)

```powershell
.\scripts\run-example.ps1
.\scripts\run-example.ps1 -Full -Release -SkipBuild
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
```

Output: `examples/users/types.mbt` and `examples/users/queries.mbt`.

## Configure sqlc.yaml and Generate

```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./_build/wasm/release/build/plugin/plugin.wasm
      sha256: ""
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

```bash
sqlc generate
```

> **Note:** Do not commit platform-specific `sha256` hashes. Use `scripts/sync-sqlc-sha256.ps1` after building locally.

After `sqlc generate`, link runtime via **Path A** (`moon add` from mooncakes.io).

# Usage Example

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

Construct `DB` in your driver adapter layer; use `MockDB` from `runtime/mock.mbt` in tests.

# Plugin Options

| Option | Default | Description |
|--------|---------|-------------|
| `package_name` | `"main"` | Generated package name |
| `emit_sql_as_comment` | `true` | Embed SQL above each function |
| `emit_json_tags` | `false` | Emit `@json.tag(...)` |
| `emit_empty_slices` | `false` | Return `[]` for empty `:many` results |
| `emit_exact_table_names` | `false` | Singularize table names (`users` 鈫?`User`) |
| `emit_methods_with_db_argument` | `false` | sqlc compat; always emits standalone `query_*` fns |

See [docs/quickstart.md](docs/quickstart.md) and [docs/runtime-api.md](docs/runtime-api.md).

# Troubleshooting

| Symptom | Fix |
|---------|-----|
| `moonbit_simd.h` missing | Use `--target wasm-gc`, not `native` |
| `moon add` package not found | Run `moon update` first to refresh registry index |
| Generated code missing `DB` / `Row` | Add `runtime` import in `moon.pkg` |
| WASM path not found | Use `_build/wasm/...`, not `target/` |
| sha256 mismatch | Do not commit local hashes; run `scripts/sync-sqlc-sha256.ps1` |
| Windows garbled output | `$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8` |
| sqlc cannot find plugin | Build WASM first; verify `file://` path matches build mode |

# Project Structure

```
plugin/           # WASM plugin (codegen + WASI I/O)
runtime/          # Generated-code runtime (published on mooncakes)
examples/users/   # Reproducible example
tests/            # golden + integration tests
docs/             # API reference and quickstart
scripts/          # run-example / setup-mooncakes / sync-sqlc-sha256
```

# Tests

```bash
moon check
moon test          # 925 inline tests
moon build --target wasm --release
```

```powershell
tests/integration/wasm/validate_plugin.ps1 -TestSqlc -Release -SkipBuild
tests/integration/e2e/run_e2e.ps1 -SkipBuild -Release
```

# Architecture

```
sqlc (protobuf) 鈫?wasi_io 鈫?codec 鈫?adapter 鈫?ir
  鈫?type_codegen / query_codegen 鈫?ast 鈫?emitter 鈫?types.mbt + queries.mbt
```

I/O uses inline WAT FFI for WASI `fd_read` / `fd_write` (no external shim). Protocol based on [sqlc-gen-greeter](https://github.com/sqlc-dev/sqlc-gen-greeter) (MIT).

# Docs and Links

| Resource | Link |
|----------|------|
| Quickstart | [docs/quickstart.md](docs/quickstart.md) 路 [涓枃](docs/quickstart.zh.md) 路 [鏃ユ湰瑾瀅(docs/quickstart.ja.md) |
| Runtime API | [docs/runtime-api.md](docs/runtime-api.md) 路 [涓枃](docs/runtime-api.zh.md) 路 [鏃ユ湰瑾瀅(docs/runtime-api.ja.md) |
| Examples | [examples/README.md](examples/README.md) 路 [涓枃](examples/README.zh.md) 路 [鏃ユ湰瑾瀅(examples/README.ja.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |

# LICENSE

This project is licensed under the **Apache License 2.0** 鈥?see [LICENSE](LICENSE).

> Third-party notices are in [NOTICE](NOTICE). WASM I/O protocol reference: [sqlc-gen-greeter](https://github.com/sqlc-dev/sqlc-gen-greeter) (MIT).
