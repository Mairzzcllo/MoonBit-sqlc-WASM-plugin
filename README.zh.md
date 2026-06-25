<p align="center">
  <img src="https://img.shields.io/badge/MoonBit-0.1.20260522-db6e2a?style=for-the-badge" alt="MoonBit"/>
  <img src="https://img.shields.io/badge/sqlc-v1_WASM_plugin-00b4d8?style=for-the-badge" alt="sqlc"/>
  <img src="https://img.shields.io/badge/mooncakes-0.1.4-orange?style=for-the-badge" alt="mooncakes"/>
  <img src="https://img.shields.io/badge/license-Apache--2.0-brightgreen?style=for-the-badge" alt="License"/>
</p>

<p align="center">
  <a href="README.md">English</a>
  ·
  <a href="README.zh.md"><b>中文</b></a>
  ·
  <a href="README.ja.md">日本語</a>
</p>

# MoonBit sqlc WASM Plugin

## 简介

**MoonBit sqlc WASM Plugin** 是 [sqlc](https://sqlc.dev) 的 [MoonBit](https://www.moonbitlang.com/) WASM 代码生成插件。它读取 `schema.sql` 与 `query.sql`，在编译期校验 SQL 与类型，并生成类型安全的 MoonBit 源码（`types.mbt` + `queries.mbt`）。

生成函数直接接受 `DB` / `Transaction`，无 ORM、无反射。runtime 已发布至 [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)；WASM 插件需本地构建或从 [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases) 下载。

**当前范围：** PostgreSQL · sqlc v1.27+（实测 v1.31.1）· MoonBit WASM (WASI preview1)

# 核心特性

## 类型安全 Codegen

- 查询与 decode 路径统一使用 `Result[T, DBError]`
- 通过 sqlc 在编译期校验 SQL 与类型
- AST → Pretty Printer 管道（禁止字符串拼接）

## 最小 Runtime

- `DB`、`Transaction`、`Row`、`RowIter`、`Value`、`MockDB`
- mooncakes 包 `Mairzzcllo/moonbit_sqlc_plugin/runtime` **0.1.4**
- 推荐目标 `wasm-gc`，生成代码无需 native 数据库驱动

## 插件与宿主分离

- WASM 插件仅负责 codegen
- WASI stdin/stdout protobuf I/O（内联 WAT FFI，无外部 shim）
- 双文件输出：`types.mbt` + `queries.mbt`

# 快速开始

两条路径 — 按你的角色选择：

| 路径 | 适用对象 | 需要什么 |
|------|----------|----------|
| **A — mooncakes.io** | 在业务项目中使用生成的 `types.mbt` / `queries.mbt` | MoonBit + `moon add`（无需克隆插件仓库） |
| **B — 插件仓库** | 构建 WASM 插件、跑示例、参与开发 | MoonBit + sqlc + 本仓库 |

---

## A. 业务开发者 — [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)

生成代码需 import `Mairzzcllo/moonbit_sqlc_plugin/runtime`，从 MoonBit 包仓库安装即可 — **WASM 插件本身不在 mooncakes 上**。

| 项目 | 值 |
|------|-----|
| 包名 | `Mairzzcllo/moonbit_sqlc_plugin` |
| 版本 | **0.1.4** |
| Import 路径 | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| 文档 | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| 编译目标 | `wasm-gc`（勿用 `native`） |

### 在已有项目中添加 runtime

在 MoonBit 项目根目录（已有 `moon.mod.json`）：

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
```

`moon add` 会写入 `moon.mod.json`：

```json
{
  "deps": {
    "Mairzzcllo/moonbit_sqlc_plugin": "0.1.4"
  }
}
```

在存放生成代码的包的 `moon.pkg` 中：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

生成文件顶部已包含：

```moonbit
import "Mairzzcllo/moonbit_sqlc_plugin/runtime"
```

将 `sqlc generate` 产出的 `types.mbt` + `queries.mbt` 复制到项目后验证：

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

> `moon add` 从 [mooncakes.io](https://mooncakes.io/) 拉包，**无需登录**；仅 `moon publish` 需要账号。

### 从零创建最小项目

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

然后：

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
# 复制 types.mbt + queries.mbt
moon check --target wasm-gc
```

### 升级 / 移除

```bash
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4   # 升级
moon remove Mairzzcllo/moonbit_sqlc_plugin       # 移除
```

冒烟验证（在**本插件仓库**根目录运行）：

```powershell
.\scripts\setup-mooncakes.ps1 -Version 0.1.4
```

```bash
bash scripts/setup-mooncakes.sh --version 0.1.4
```

---

## B. 插件开发者 — 构建 WASM 与生成代码

### 环境要求

| 工具 | 版本 | 说明 |
|------|------|------|
| [MoonBit](https://www.moonbitlang.com/download/) | ≥ 0.1.20260522 | 构建、测试、mooncakes |
| [sqlc](https://docs.sqlc.dev/en/latest/overview/install.html) | ≥ v1.27.0 | 调用 WASM 插件 |

PostgreSQL 仅用于 sqlc 校验 schema/query；生成代码本身不连接数据库。

## 克隆仓库

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon check
moon test
```

## 构建 WASM 插件

```bash
moon build --target wasm --release
```

| 模式 | 路径 |
|------|------|
| release（推荐） | `_build/wasm/release/build/plugin/plugin.wasm` |
| debug | `_build/wasm/debug/build/plugin/plugin.wasm` |

## 运行示例

### Linux / macOS

```bash
chmod +x scripts/run-example.sh scripts/setup-mooncakes.sh
bash scripts/run-example.sh
bash scripts/run-example.sh --full --release --skip-build
```

### Windows（PowerShell）

```powershell
.\scripts\run-example.ps1
.\scripts\run-example.ps1 -Full -Release -SkipBuild
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
```

输出：`examples/users/types.mbt` 与 `examples/users/queries.mbt`。

## 配置 sqlc.yaml 并生成

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

> **注意：** 勿将本机 platform-specific `sha256` 提交进 git。本地构建后使用 `scripts/sync-sqlc-sha256.ps1` 同步。

`sqlc generate` 完成后，按 **路径 A** 通过 mooncakes.io 安装 runtime（`moon add`）。

# 使用示例

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

`DB` 由你的数据库驱动适配层构造；测试可使用 `runtime/mock.mbt` 中的 `MockDB`。

# Plugin Options

| 选项 | 默认 | 说明 |
|------|------|------|
| `package_name` | `"main"` | 生成代码包名 |
| `emit_sql_as_comment` | `true` | 函数上方嵌入 SQL |
| `emit_json_tags` | `false` | 生成 `@json.tag(...)` |
| `emit_empty_slices` | `false` | `:many` 空结果返回 `[]` |
| `emit_exact_table_names` | `false` | `users` → `User`（单数化） |
| `emit_methods_with_db_argument` | `false` | sqlc 兼容项；始终生成独立 `query_*` 函数 |

详见 [docs/quickstart.md](docs/quickstart.md)、[docs/runtime-api.md](docs/runtime-api.md)。

# 故障排除

| 现象 | 处理 |
|------|------|
| `moonbit_simd.h` 缺失 | 使用 `--target wasm-gc`，勿用 `native` |
| `moon add` 找不到包 | 先运行 `moon update` 刷新 registry 索引 |
| 生成代码找不到 `DB` / `Row` | 检查 `moon.pkg` 是否 import `runtime` |
| WASM 路径找不到 | 使用 `_build/wasm/...`，不是 `target/` |
| sha256 不匹配 | 勿提交本机 hash；运行 `scripts/sync-sqlc-sha256.ps1` |
| Windows 控制台乱码 | `$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8` |
| sqlc 找不到 plugin | 先构建 WASM；确认 `file://` 路径与构建模式一致 |

# 项目结构

```
plugin/           # WASM 插件（codegen + WASI I/O）
runtime/          # 生成代码运行时（mooncakes 已发布）
examples/users/   # 可复现示例
tests/            # golden + integration 测试
docs/             # API 与快速开始
scripts/          # run-example / setup-mooncakes / sync-sqlc-sha256
```

# 测试

```bash
moon check
moon test          # 925 个 inline test
moon build --target wasm --release
```

```powershell
tests/integration/wasm/validate_plugin.ps1 -TestSqlc -Release -SkipBuild
tests/integration/e2e/run_e2e.ps1 -SkipBuild -Release
```

# 架构概览

```
sqlc (protobuf) → wasi_io → codec → adapter → ir
  → type_codegen / query_codegen → ast → emitter → types.mbt + queries.mbt
```

I/O 通过内联 WAT FFI 调用 WASI `fd_read` / `fd_write`（无外部 shim）。协议参考 [sqlc-gen-greeter](https://github.com/sqlc-dev/sqlc-gen-greeter)（MIT）。

# 文档与链接

| 资源 | 链接 |
|------|------|
| 快速开始 | [docs/quickstart.zh.md](docs/quickstart.zh.md) · [English](docs/quickstart.md) · [日本語](docs/quickstart.ja.md) |
| Runtime API | [docs/runtime-api.zh.md](docs/runtime-api.zh.md) · [English](docs/runtime-api.md) · [日本語](docs/runtime-api.ja.md) |
| 示例 | [examples/README.zh.md](examples/README.zh.md) · [English](examples/README.md) · [日本語](examples/README.ja.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |

# 许可证

本项目依据 **Apache License 2.0** 授权发布 — 详见 [LICENSE](LICENSE)。

> 第三方归属见 [NOTICE](NOTICE)。WASM I/O 协议参考 [sqlc-gen-greeter](https://github.com/sqlc-dev/sqlc-gen-greeter)（MIT）。
