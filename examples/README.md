# Examples

## users — PostgreSQL 完整示例

从 SQL 生成 MoonBit 代码的最小可复现示例。

### 文件

| 文件 | 说明 |
|------|------|
| `schema.sql` | `users` 表 DDL |
| `query.sql` | sqlc 注解查询（`:one` / `:many` / `:exec`） |
| `sqlc.yaml` | 指向 `_build/wasm/.../plugin.wasm` |
| `moon.pkg.example` | 集成到业务项目时的 runtime 依赖模板 |
| `types.mbt` | `sqlc generate` 产出（gitignore，本地生成） |
| `queries.mbt` | `sqlc generate` 产出（gitignore，本地生成） |

### 复现步骤

**一键（推荐）：**

```bash
# 仓库根目录
bash scripts/run-example.sh
# Windows: .\scripts\run-example.ps1
```

**手动：**
# 在仓库根目录
moon build --target wasm
cd examples/users
sqlc generate
ls types.mbt queries.mbt
```

本目录**不含** `moon.pkg`，生成文件不会参与插件 monorepo 的 `moon check`。集成到项目时复制生成文件并参考 `moon.pkg.example`。

详细说明见根目录 [README.md](../README.md)。

### 查询注解

| 注解 | 行为 | 示例 |
|------|------|------|
| `:one` | 返回单行 | `GetUser` |
| `:many` | 返回多行 | `ListUsers` |
| `:exec` | 无返回行 | `DeleteUser` |
