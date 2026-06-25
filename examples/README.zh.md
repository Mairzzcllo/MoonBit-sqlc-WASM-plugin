<p align="center">
  <a href="README.md">English</a>
  ·
  <a href="README.zh.md"><b>中文</b></a>
  ·
  <a href="README.ja.md">日本語</a>
</p>

# 示例

**文档导航：** [快速开始](../docs/quickstart.zh.md) · [Runtime API](../docs/runtime-api.zh.md) · [README](../README.zh.md) · [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) · [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## users — PostgreSQL 完整示例

从 SQL 生成 MoonBit 代码的最小可复现示例，对应仓库路径 `examples/users/`。

### 文件说明

| 文件 | 说明 |
|------|------|
| `schema.sql` | `users` 表 DDL |
| `query.sql` | sqlc 注解查询（`:one` / `:many` / `:exec`） |
| `sqlc.yaml` | 指向 `_build/wasm/.../plugin.wasm`（debug 默认，release 可切换） |
| `moon.pkg.example` | 集成到业务项目时的 runtime 依赖模板 |
| `types.mbt` | `sqlc generate` 产出（gitignore，本地生成） |
| `queries.mbt` | `sqlc generate` 产出（gitignore，本地生成） |

### 查询注解

| 注解 | 行为 | 示例 |
|------|------|------|
| `:one` | 返回单行 | `GetUser` |
| `:many` | 返回多行 | `ListUsers` |
| `:exec` | 无返回行 | `DeleteUser` |

---

## 复现步骤

### 一键（推荐）

```bash
# 仓库根目录
bash scripts/run-example.sh --release
```

```powershell
# Windows
.\scripts\run-example.ps1 -Release
# 含完整验证：-Full
# 跳过构建：-SkipBuild
```

### 手动

```bash
# 在仓库根目录
moon build --target wasm --release
cd examples/users
sqlc generate
ls types.mbt queries.mbt
```

> E2E / validate 脚本会在 build 后自动 sync `sha256`。**勿将 platform-specific hash 提交进 git**；commit 态 `sqlc.yaml` 应为 debug url active + `sha256: ""`。

---

## 集成到业务项目（mooncakes.io）

本目录**不含** `moon.pkg`，生成文件不会参与插件 monorepo 的 `moon check`。集成到独立 MoonBit 项目时：

### 1. 安装 runtime

在业务项目根目录：

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.6
moon check --target wasm-gc
```

| 项目 | 值 |
|------|-----|
| 包名 | `Mairzzcllo/moonbit_sqlc_plugin` |
| 版本 | **0.1.6** |
| 文档 | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |

### 2. 复制生成代码

将 `types.mbt`、`queries.mbt` 复制到业务项目包目录。

### 3. 配置 moon.pkg

参考 [`moon.pkg.example`](users/moon.pkg.example)：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

### 4. 验证编译

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

### 5. 冒烟脚本（可选）

在**插件仓库根目录**验证 mooncakes 安装：

```bash
bash scripts/setup-mooncakes.sh --version 0.1.6
```

```powershell
.\scripts\setup-mooncakes.ps1 -Version 0.1.6
```

---

## sqlc.yaml 说明

`examples/users/sqlc.yaml` 示例（commit 态）：

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

- **WASM 插件**：本地 `_build/` 或 [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases) 下载
- **Runtime**：仅通过 [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) 的 `moon add` 安装

---

## 生成代码示例

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

测试可使用 `MockDB` / `MockDBBuilder`（含 `.strict(true)` 模式），详见 [Runtime API — MockDB](../docs/runtime-api.zh.md#mockdb)。

---

## 相关文档

| 资源 | 链接 |
|------|------|
| 快速开始 | [quickstart.zh.md](../docs/quickstart.zh.md) · [English](../docs/quickstart.md) · [日本語](../docs/quickstart.ja.md) |
| Runtime API | [runtime-api.zh.md](../docs/runtime-api.zh.md) · [English](../docs/runtime-api.md) · [日本語](../docs/runtime-api.ja.md) |
| 项目 README | [README.zh.md](../README.zh.md) · [English](../README.md) · [日本語](../README.ja.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |
