<p align="center">
  <a href="README.md"><b>English</b></a>
  路
  <a href="README.zh.md">涓枃</a>
  路
  <a href="README.ja.md">鏃ユ湰瑾?/a>
</p>

# Examples

**Documentation:** [Quick Start](../docs/quickstart.md) 路 [Runtime API](../docs/runtime-api.md) 路 [README](../README.md) 路 [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) 路 [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## users 鈥?PostgreSQL Complete Example

Minimal reproducible example for generating MoonBit code from SQL. Path: `examples/users/`.

### Files

| File | Description |
|------|-------------|
| `schema.sql` | `users` table DDL |
| `query.sql` | sqlc annotated queries (`:one` / `:many` / `:exec`) |
| `sqlc.yaml` | Points to `_build/wasm/.../plugin.wasm` (debug default, release optional) |
| `moon.pkg.example` | Runtime dependency template for your app |
| `types.mbt` | `sqlc generate` output (gitignored, local) |
| `queries.mbt` | `sqlc generate` output (gitignored, local) |

### Query Annotations

| Annotation | Behavior | Example |
|------------|----------|---------|
| `:one` | Single row | `GetUser` |
| `:many` | Multiple rows | `ListUsers` |
| `:exec` | No rows returned | `DeleteUser` |

---

## Reproduce

### One-liner (recommended)

```bash
# From repo root
bash scripts/run-example.sh --release
```

```powershell
# Windows
.\scripts\run-example.ps1 -Release
# Full validation: -Full
# Skip build: -SkipBuild
```

### Manual

```bash
# From repo root
moon build --target wasm --release
cd examples/users
sqlc generate
ls types.mbt queries.mbt
```

> E2E / validate scripts auto-sync `sha256` after build. **Do not commit platform-specific hashes**; commit state should be debug url active + `sha256: ""`.

---

## Integrate into Your App (mooncakes.io)

This directory has **no** `moon.pkg` 鈥?generated files are not part of the plugin monorepo `moon check`. For a standalone MoonBit project:

### 1. Install runtime

In your project root:

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.5
moon check --target wasm-gc
```

| Item | Value |
|------|-------|
| Package | `Mairzzcllo/moonbit_sqlc_plugin` |
| Version | **0.1.5** |
| Docs | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |

### 2. Copy generated code

Copy `types.mbt` and `queries.mbt` into your project package.

### 3. Configure moon.pkg

See [`moon.pkg.example`](users/moon.pkg.example):

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

### 4. Verify compile

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

### 5. Smoke test (optional)

From **plugin repo** root:

```bash
bash scripts/setup-mooncakes.sh --version 0.1.5
```

```powershell
.\scripts\setup-mooncakes.ps1 -Version 0.1.5
```

---

## sqlc.yaml Reference

Commit-state example for `examples/users/sqlc.yaml`:

```yaml
version: "2"
plugins:
  - name: "moonbit"
    wasm:
      url: "file://../../_build/wasm/debug/build/plugin/plugin.wasm"
      sha256: ""
sql:
  - schema: "schema.sql"
    queries: "query.sql"
    engine: "postgresql"
    codegen:
      - out: "."
        plugin: "moonbit"
        options:
          package_name: users
```

- **WASM plugin**: local `_build/` or [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases)
- **Runtime**: install via `moon add` from [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)

---

## Generated Code Example

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

Use `MockDB` / `MockDBBuilder` (including `.strict(true)`) for tests 鈥?see [Runtime API 鈥?MockDB](../docs/runtime-api.md#mockdb).

---

## Related Documentation

| Resource | Link |
|----------|------|
| Quick Start | [quickstart.md](../docs/quickstart.md) 路 [涓枃](../docs/quickstart.zh.md) 路 [鏃ユ湰瑾瀅(../docs/quickstart.ja.md) |
| Runtime API | [runtime-api.md](../docs/runtime-api.md) 路 [涓枃](../docs/runtime-api.zh.md) 路 [鏃ユ湰瑾瀅(../docs/runtime-api.ja.md) |
| README | [README.md](../README.md) 路 [涓枃](../README.zh.md) 路 [鏃ユ湰瑾瀅(../README.ja.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |
