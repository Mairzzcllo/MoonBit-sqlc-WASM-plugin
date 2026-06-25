<p align="center">
  <a href="quickstart.md">English</a>
  ·
  <a href="quickstart.zh.md"><b>中文</b></a>
  ·
  <a href="quickstart.ja.md">日本語</a>
</p>

# 快速开始

> 从 SQL 生成类型安全的 MoonBit 数据库代码。

**文档导航：** [README](../README.zh.md) · [Runtime API](runtime-api.zh.md) · [示例](../examples/README.zh.md) · [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) · [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## 环境要求

| 工具 | 版本 | 说明 |
|------|------|------|
| [MoonBit](https://www.moonbitlang.com/download/) | ≥ 0.1.20260522 | 构建、测试、mooncakes |
| [sqlc](https://sqlc.dev) | ≥ v1.27.0 | 实测 v1.31.1 |

PostgreSQL 仅用于 sqlc 校验 `schema.sql` / `query.sql`；生成代码不连接数据库。

---

## 选择路径

| 路径 | 适用对象 | 需要什么 |
|------|----------|----------|
| **A — mooncakes.io** | 在业务项目中使用生成代码 | 仅 `moon add`（无需克隆插件仓库） |
| **B — 插件仓库** | 构建 WASM、跑示例 | 克隆本仓库 + sqlc |

---

## 路径 A — 从 [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) 安装 Runtime

生成代码 import `Mairzzcllo/moonbit_sqlc_plugin/runtime`。**WASM 插件不在 mooncakes 上** — 本地构建（路径 B）或从 [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases) 下载。

| 项目 | 值 |
|------|-----|
| 包名 | `Mairzzcllo/moonbit_sqlc_plugin` |
| 版本 | **0.1.4** |
| Import | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| 目标 | `wasm-gc`（勿用 `native`） |

### 已有项目

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
```

`moon add` 后的 `moon.mod.json`：

```json
{
  "deps": {
    "Mairzzcllo/moonbit_sqlc_plugin": "0.1.4"
  }
}
```

存放生成代码的包的 `moon.pkg`：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

复制 `sqlc generate` 产出的 `types.mbt` + `queries.mbt` 后：

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

> `moon add` 从 mooncakes.io 拉包，**无需登录**。

### 从零创建项目

```bash
mkdir myapp && cd myapp
```

`moon.mod.json`：

```json
{
  "name": "your_org/myapp",
  "version": "0.1.0",
  "preferred-target": "wasm-gc",
  "supported-targets": "+wasm+wasm-gc"
}
```

`moon.pkg`：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime" @runtime,
}
```

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
# 复制 types.mbt + queries.mbt
moon check --target wasm-gc
```

冒烟测试（在**本插件仓库**根目录）：

```bash
bash scripts/setup-mooncakes.sh --version 0.1.4
# Windows: .\scripts\setup-mooncakes.ps1 -Version 0.1.4
```

---

## 路径 B — 构建插件并生成代码

### 1. 克隆并构建 WASM

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon build --target wasm --release
```

| 模式 | 路径 |
|------|------|
| release（推荐） | `_build/wasm/release/build/plugin/plugin.wasm` |
| debug | `_build/wasm/debug/build/plugin/plugin.wasm` |

一键示例：

```bash
bash scripts/run-example.sh --release
# Windows: .\scripts\run-example.ps1 -Release
```

### 2. 配置 sqlc.yaml

sqlc v2 格式：

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

> 勿提交 platform-specific `sha256`。构建后：

```powershell
.\scripts\sync-sqlc-sha256.ps1 `
  -WasmPath _build\wasm\release\build\plugin\plugin.wasm `
  -YamlPath examples\users\sqlc.yaml
```

### 3. 编写 SQL

`schema.sql`：

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

`query.sql`：

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

### 4. 生成

```bash
sqlc generate
```

输出：`types.mbt`（类型与 decode）+ `queries.mbt`（查询函数）。

### 5. 链接 runtime（路径 A）

按上方**路径 A** 从 mooncakes.io `moon add` runtime。

---

## 使用生成代码

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

在驱动适配层构造 `DB`；测试用 `MockDB`（见 [Runtime API — MockDB](runtime-api.zh.md#mockdb)）。

---

## MockDB 测试

基础预设：

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

精确 SQL 匹配与 **strict 模式**（未注册 SQL → `Err`）：

```moonbit
test "strict mock rejects unknown SQL" {
  let db = MockDBBuilder::new()
    .strict(true)
    .register_query_row(
      "SELECT * FROM users WHERE id = $1",
      Ok(row),
    )
    .build()
}
```

---

## 事务

`:one` / `:many` / `:exec` / `:execrows` 生成函数均有 `Transaction` 重载。`:copyfrom`、`:batch`、`:execlastid` 仅支持 `DB`。

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

| 选项 | 默认 | 说明 |
|------|------|------|
| `package_name` | `"main"` | 生成代码包名 |
| `emit_sql_as_comment` | `true` | 函数上方嵌入 SQL |
| `emit_json_tags` | `false` | 生成 `@json.tag(...)` |
| `emit_empty_slices` | `false` | `:many` 空结果返回 `[]` |
| `emit_exact_table_names` | `false` | 表名单数化 |
| `strict_types` | `true` | 未知 PG 类型 fail（可用 `override_<type>=`） |

未知 query cmd（如 `:typo`）和错误 plugin option 也会在 codegen 时 fail 并输出 stderr。

---

## 故障排除

| 现象 | 处理 |
|------|------|
| `moonbit_simd.h` 缺失 | 使用 `--target wasm-gc`，勿用 `native` |
| `moon add` 找不到包 | 先 `moon update` |
| WASM 路径错误 | 使用 `_build/wasm/...`，不是 `target/` |
| sha256 不匹配 | 勿提交本机 hash；运行 `sync-sqlc-sha256.ps1` |
| 生成时未知 PG 类型 | 添加 `override_<pgtype>=<MoonBitType>` 或使用已知类型 |

---

## 下一步

- [Runtime API](runtime-api.zh.md) — 完整类型文档
- [examples/users/](../examples/users/) — 完整示例
- [examples/README.zh.md](../examples/README.zh.md) — 示例说明
- [README.zh.md](../README.zh.md) — 项目概览
