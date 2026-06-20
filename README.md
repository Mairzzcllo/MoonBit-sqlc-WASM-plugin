# MoonBit sqlc WASM Plugin

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260512-db6e2a?style=flat-square)](https://www.moonbitlang.com/)
[![sqlc](https://img.shields.io/badge/sqlc-v1_WASM_plugin-00b4d8?style=flat-square)](https://sqlc.dev)
[![mooncakes](https://img.shields.io/badge/mooncakes-0.1.2-orange?style=flat-square)](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)
[![License](https://img.shields.io/badge/license-Apache--2.0-brightgreen?style=flat-square)](LICENSE)

> 从 SQL 生成类型安全的 MoonBit 数据库代码 —— [sqlc](https://sqlc.dev) 的 WASM 插件。

---

## 项目目标

[sqlc](https://sqlc.dev) 读取 `schema.sql` 与 `query.sql`，在编译期校验 SQL 与类型，并调用 WASM 插件生成 MoonBit 源码。

| 目标 | 说明 |
|------|------|
| **类型安全** | `Result[T, DBError]`，编译期捕获 SQL/类型不匹配 |
| **零 ORM 开销** | 生成函数直接接受 `DB` / `Transaction`，无反射 |
| **最小 runtime** | 仅依赖 `runtime/`（`DB`、`Row`、`RowIter`） |
| **可维护 codegen** | AST → Pretty Printer，禁止字符串拼接 |

**当前范围：** PostgreSQL · sqlc v1.27+ · MoonBit WASM (WASI preview1)

---

## 环境要求

| 工具 | 版本 | 说明 |
|------|------|------|
| [MoonBit](https://www.moonbitlang.com/download/) | ≥ 0.1.20260512 | 构建插件、测试、mooncakes |
| [sqlc](https://docs.sqlc.dev/en/latest/overview/install.html) | ≥ v1.27.0 | 调用 WASM 插件（实测 v1.31.1） |

PostgreSQL 仅用于 sqlc 校验 schema/query；生成代码本身不连接数据库。

---

## Windows / Linux 配置指南

### 1. 安装 MoonBit

<details>
<summary><strong>Windows（PowerShell）</strong></summary>

```powershell
# 官方安装脚本（见 https://www.moonbitlang.com/download/）
# 安装后验证：
moon --version

# 可选：解决控制台中文乱码
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
```

</details>

<details>
<summary><strong>Linux / macOS（Bash）</strong></summary>

```bash
# 官方安装脚本（见 https://www.moonbitlang.com/download/）
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# 将 ~/.moon/bin 加入 PATH（安装脚本通常会提示）
export PATH="$HOME/.moon/bin:$PATH"
moon --version
```

</details>

### 2. 安装 sqlc

<details>
<summary><strong>Windows</strong></summary>

```powershell
# 方式 A：Go 安装
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest

# 方式 B：下载 release 二进制
# https://github.com/sqlc-dev/sqlc/releases

sqlc version
```

</details>

<details>
<summary><strong>Linux</strong></summary>

```bash
# 方式 A：Go
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest

# 方式 B：下载 release 并加入 PATH
# https://github.com/sqlc-dev/sqlc/releases

sqlc version
```

</details>

### 3. 克隆仓库并验证

<details>
<summary><strong>Windows</strong></summary>

```powershell
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon check
moon test
```

</details>

<details>
<summary><strong>Linux</strong></summary>

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon check
moon test
```

</details>

### 4. 构建 WASM 插件

两平台命令相同。产物在 `_build/`（**不是** `target/`）：

```bash
moon build --target wasm --release
```

| 模式 | 路径 |
|------|------|
| release（推荐） | `_build/wasm/release/build/plugin/plugin.wasm` |
| debug | `_build/wasm/debug/build/plugin/plugin.wasm` |

### 5. 一键运行示例

<details>
<summary><strong>Windows</strong></summary>

```powershell
# 构建 + sqlc generate + 预览输出
.\scripts\run-example.ps1

# 可选参数
.\scripts\run-example.ps1 -Full      # 含 moon check + moon test
.\scripts\run-example.ps1 -Release   # 使用 release WASM
.\scripts\run-example.ps1 -SkipBuild # 跳过构建，复用已有 WASM
```

</details>

<details>
<summary><strong>Linux</strong></summary>

```bash
chmod +x scripts/run-example.sh scripts/setup-mooncakes.sh
bash scripts/run-example.sh

# 可选参数
bash scripts/run-example.sh --full
bash scripts/run-example.sh --release
bash scripts/run-example.sh --skip-build
```

</details>

生成结果位于 `examples/users/types.mbt` 与 `examples/users/queries.mbt`。

### 6. mooncakes.io 安装 Runtime

生成代码需链接 `runtime` 包（已发布至 [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)）。

<details>
<summary><strong>Windows — 业务项目</strong></summary>

```powershell
# 首次（可选）
moon login

# 在含 moon.mod.json 的业务项目根目录
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.2
moon check --target wasm-gc
moon test --target wasm-gc
```

验证脚本（在**本仓库**根目录）：

```powershell
.\scripts\setup-mooncakes.ps1
```

</details>

<details>
<summary><strong>Linux — 业务项目</strong></summary>

```bash
moon login    # 首次（可选）

moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.2
moon check --target wasm-gc
moon test --target wasm-gc
```

验证脚本（在**本仓库**根目录）：

```bash
bash scripts/setup-mooncakes.sh
```

</details>

业务项目 `moon.pkg` 示例（见 [`examples/users/moon.pkg.example`](examples/users/moon.pkg.example)）：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

| 项目 | 值 |
|------|-----|
| 包名 | `Mairzzcllo/moonbit_sqlc_plugin` |
| 当前版本 | `0.1.2` |
| 包页 | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |

> mooncakes 发布的是 **runtime**；**WASM 插件**需本地 `moon build --target wasm` 或 [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases)。

### 7. 配置 sqlc.yaml 并生成代码

两平台配置相同。`file://` 路径按 OS 使用正斜杠或绝对路径：

```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./_build/wasm/release/build/plugin/plugin.wasm
      sha256: ""   # 首次留空，sqlc 会打印 sha256
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

输出：`types.mbt`（类型与 decode）+ `queries.mbt`（查询函数）。

---

## 使用示例

### SQL

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

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

### 生成代码调用

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

`DB` 由你的数据库驱动适配层构造；测试可用 `runtime/mock.mbt` 中的 `MockDB`。

### 常用 plugin options

| 选项 | 默认 | 说明 |
|------|------|------|
| `package_name` | `"main"` | 生成代码包名 |
| `emit_sql_as_comment` | `true` | 函数上方嵌入 SQL |
| `emit_json_tags` | `false` | 生成 `@json.tag(...)` |
| `emit_empty_slices` | `false` | `:many` 空结果返回 `[]` |
| `emit_exact_table_names` | `false` | `false` 时将表名单数化（`users` → `User`）；`true` 保留复数（`Users`） |
| `emit_methods_with_db_argument` | `false` | sqlc 兼容项；MoonBit 0.1 始终生成 `pub fn query_*(db: DB, ...)` 独立函数 |

详见 [docs/quickstart.md](docs/quickstart.md)、[docs/runtime-api.md](docs/runtime-api.md)。

---

## 故障排除

### mooncakes / `moon add` 报 `moonbit_simd.h` 缺失

native 后端编译失败，但本项目仅需 **wasm / wasm-gc**：

```bash
moon check --target wasm-gc
moon test --target wasm-gc
# 勿使用 --target native
```

仍失败时重装 MoonBit 并确认 `~/.moon/include/moonbit.h` 存在。

### Windows 控制台乱码

```powershell
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
```

### WASM 路径找不到

确认使用 `_build/wasm/...`，不是 `target/wasm/...`。

### sqlc 找不到 plugin.wasm

先执行 `moon build --target wasm`（或 `--release`），并确保 `sqlc.yaml` 中 `file://` 路径与构建模式一致。

---

## 项目结构

```
.
├── plugin/           # WASM 插件（codegen + WASI I/O）
├── runtime/          # 生成代码运行时（mooncakes 已发布）
├── examples/users/   # 可复现示例（schema + query + sqlc.yaml）
├── tests/            # golden + integration 测试
├── docs/             # API 与快速开始
├── scripts/          # run-example / setup-mooncakes（Win + Linux）
├── sqlc.yaml         # 根目录 generate 配置
└── moon.mod.json
```

---

## 测试

```bash
moon check
moon test          # 907 个 inline test
```

<details>
<summary>WASM 集成验证</summary>

**Windows：**

```powershell
tests/integration/wasm/validate_plugin.ps1
```

**Linux：** CI 使用相同脚本（需 PowerShell Core `pwsh`）或手动 `moon build --target wasm` + `cd examples/users && sqlc generate`。

</details>

---

## 架构概览

```
sqlc (protobuf) → wasi_io → codec → adapter → ir
  → type_codegen / query_codegen → ast → emitter
  → types.mbt + queries.mbt
```

I/O 通过内联 WAT FFI 调用 WASI `fd_read` / `fd_write`（无外部 shim）。

---

## 文档与链接

| 资源 | 链接 |
|------|------|
| 快速开始 | [docs/quickstart.md](docs/quickstart.md) |
| Runtime API | [docs/runtime-api.md](docs/runtime-api.md) |
| 示例 | [examples/README.md](examples/README.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |

---

## 许可证

Apache-2.0 — 详见 [LICENSE](LICENSE)。第三方归属见 [NOTICE](NOTICE)。

WASM I/O 协议参考 [sqlc-gen-greeter](https://github.com/sqlc-dev/sqlc-gen-greeter)（MIT）。
