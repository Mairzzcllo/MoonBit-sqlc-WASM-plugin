# MoonBit sqlc WASM Plugin

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260522-db6e2a?style=flat-square)](https://www.moonbitlang.com/)
[![sqlc](https://img.shields.io/badge/sqlc-v1_WASM_plugin-00b4d8?style=flat-square)](https://sqlc.dev)
[![mooncakes](https://img.shields.io/badge/mooncakes-0.1.4-orange?style=flat-square)](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)
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

**快速导航：** [构建 WASM 插件](#4-构建-wasm-插件) · [mooncakes.io Runtime](#mooncakesio--安装与使用-runtime) · [sqlc 配置](#7-配置-sqlcyaml-并生成代码) · [Runtime API](docs/runtime-api.md)

---

## 环境要求

| 工具 | 版本 | 说明 |
|------|------|------|
| [MoonBit](https://www.moonbitlang.com/download/) | ≥ 0.1.20260522 | 构建插件、测试、mooncakes |
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

---

## mooncakes.io — 安装与使用 Runtime

生成代码（`types.mbt` / `queries.mbt`）需要链接 **runtime** 包。runtime 已发布至 [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)；**WASM 插件本身不在 mooncakes 上**，需本地构建或从 [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases) 下载。

### 包信息

| 项目 | 值 |
|------|-----|
| 包名 | `Mairzzcllo/moonbit_sqlc_plugin` |
| 当前版本 | **`0.1.4`** |
| 文档 | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| 消费者 import | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| 推荐编译目标 | `wasm-gc`（勿用 `native`，见下方故障排除） |

### 架构说明

```
┌─────────────────────────────────────────────────────────────┐
│  sqlc generate                                              │
│    └─ 加载 plugin.wasm（本地 _build/ 或 Release 下载）         │
│         └─ 输出 types.mbt + queries.mbt                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ import runtime
┌─────────────────────────────────────────────────────────────┐
│  你的 MoonBit 业务项目                                        │
│    moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4           │
│    moon.pkg → import runtime（DB / Row / MockDB …）          │
└─────────────────────────────────────────────────────────────┘
```

### 首次使用 mooncakes（可选）

`moon add` 从 registry 拉包通常**不需要**登录；发布包到 mooncakes 才需要账号。

<details>
<summary><strong>Windows — 注册 / 登录</strong></summary>

```powershell
moon register          # 首次发布包时
moon login             # 已有账号时
# 凭证保存在 %USERPROFILE%\.moon\credentials.json
```

</details>

<details>
<summary><strong>Linux / macOS — 注册 / 登录</strong></summary>

```bash
moon register
moon login
# 凭证保存在 ~/.moon/credentials.json
```

</details>

### 在业务项目中添加 runtime

在**已有** `moon.mod.json` 的项目根目录执行：

<details>
<summary><strong>Windows（PowerShell）</strong></summary>

```powershell
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
moon test --target wasm-gc
```

</details>

<details>
<summary><strong>Linux / macOS（Bash）</strong></summary>

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
moon test --target wasm-gc
```

</details>

`moon add` 会在 `moon.mod.json` 的 `deps` 中写入依赖，例如：

```json
{
  "name": "your_org/your_app",
  "version": "0.1.0",
  "preferred-target": "wasm-gc",
  "supported-targets": "+wasm+wasm-gc",
  "deps": {
    "Mairzzcllo/moonbit_sqlc_plugin": "0.1.4"
  }
}
```

在生成代码所在包的 `moon.pkg` 中 import runtime（参考 [`examples/users/moon.pkg.example`](examples/users/moon.pkg.example)）：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

生成代码文件顶部也会包含：

```moonbit
import "Mairzzcllo/moonbit_sqlc_plugin/runtime"
```

### 从零创建消费者项目（最小示例）

<details>
<summary><strong>Windows</strong></summary>

```powershell
mkdir myapp; cd myapp
@'
{
  "name": "your_org/myapp",
  "version": "0.1.0",
  "preferred-target": "wasm-gc",
  "supported-targets": "+wasm+wasm-gc"
}
'@ | Set-Content moon.mod.json -Encoding utf8

@'
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime" @runtime,
}
'@ | Set-Content moon.pkg -Encoding utf8

moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
```

</details>

<details>
<summary><strong>Linux / macOS</strong></summary>

```bash
mkdir myapp && cd myapp
cat > moon.mod.json <<'EOF'
{
  "name": "your_org/myapp",
  "version": "0.1.0",
  "preferred-target": "wasm-gc",
  "supported-targets": "+wasm+wasm-gc"
}
EOF

cat > moon.pkg <<'EOF'
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime" @runtime,
}
EOF

moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
```

</details>

将 `sqlc generate` 产出的 `types.mbt`、`queries.mbt` 复制到该项目后，再次 `moon check --target wasm-gc` 即可验证编译通过。

### 在本仓库验证 mooncakes 安装

在**本插件仓库**根目录运行冒烟脚本（会 `moon update`、构建 wasm-gc、创建临时消费者项目并 `moon add`）：

<details>
<summary><strong>Windows</strong></summary>

```powershell
.\scripts\setup-mooncakes.ps1
# 指定版本：
.\scripts\setup-mooncakes.ps1 -Version 0.1.4
```

</details>

<details>
<summary><strong>Linux / macOS</strong></summary>

```bash
bash scripts/setup-mooncakes.sh
bash scripts/setup-mooncakes.sh --version 0.1.4
```

</details>

### 升级 / 移除 runtime

```bash
# 升级到最新已发布版本（先查 mooncakes 文档页确认版本号）
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4

# 移除依赖
moon remove Mairzzcllo/moonbit_sqlc_plugin
```

### mooncakes 常见问题

| 现象 | 处理 |
|------|------|
| `moonbit_simd.h` 缺失 / native 编译失败 | 使用 `--target wasm-gc`，不要用 `native` |
| `moon add` 找不到包 | 先 `moon update` 刷新 registry 索引 |
| 生成代码找不到 `DB` / `Row` | 检查 `moon.pkg` 是否 import `runtime` |
| 版本不匹配 | 生成代码与 runtime 主版本应对齐；升级时同时 `moon add` 新版本 |

---

### 7. 配置 sqlc.yaml 并生成代码

两平台配置相同。`file://` 路径按 OS 使用正斜杠或绝对路径：

```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./_build/wasm/release/build/plugin/plugin.wasm
      sha256: ""   # 留空即可；run-example / CI 会在 build 后自动 sync
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

详见上方 [mooncakes.io — 安装与使用 Runtime](#mooncakesio--安装与使用-runtime)。native 后端编译失败，但本项目仅需 **wasm / wasm-gc**：

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

### sqlc 报 invalid checksum / sha256 不匹配

WASM 的 sha256 随 OS / 工具链变化。**不要**把本机 hash 提交进 git。构建后由脚本自动写入：

```powershell
# Windows（run-example 已内置；也可手动）
.\scripts\sync-sqlc-sha256.ps1 `
  -WasmPath _build\wasm\debug\build\plugin\plugin.wasm `
  -YamlPath examples\users\sqlc.yaml

# 可选：持久化到 yaml 以加速本地 sqlc 启动
.\scripts\update-wasm-sha256.ps1
```

```bash
# Linux（CI 与 validate_plugin.ps1 -TestSqlc 会自动 sync）
pwsh scripts/sync-sqlc-sha256.ps1 \
  -WasmPath _build/wasm/debug/build/plugin/plugin.wasm \
  -YamlPath examples/users/sqlc.yaml
```

---

## 项目结构

```
.
├── plugin/           # WASM 插件（codegen + WASI I/O）
├── runtime/          # 生成代码运行时（mooncakes 已发布）
├── examples/users/   # 可复现示例（schema + query + sqlc.yaml）
├── tests/            # golden + integration 测试
├── docs/             # API 与快速开始
├── scripts/          # run-example / setup-mooncakes / sync-sqlc-sha256
├── sqlc.yaml         # 根目录 generate 配置
└── moon.mod.json
```

---

## 测试

```bash
moon check
moon test          # 914 个 inline test
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
