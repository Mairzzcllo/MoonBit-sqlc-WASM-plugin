# MoonBit sqlc WASM Plugin

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260512-db6e2a?style=flat-square)](https://www.moonbitlang.com/)
[![sqlc](https://img.shields.io/badge/sqlc-v1_WASM_plugin-00b4d8?style=flat-square)](https://sqlc.dev)
[![License](https://img.shields.io/badge/license-Apache--2.0-brightgreen?style=flat-square)](LICENSE)
[![version](https://img.shields.io/badge/version-0.1.0-blue?style=flat-square)](moon.mod.json)

> Generate type-safe MoonBit database code from SQL queries — a WASM plugin for [sqlc](https://sqlc.dev).

---

## 目录

- [项目介绍](#-项目介绍)
- [快速开始](#-快速开始)
- [开发指南](#-开发指南)
- [路线图](#-路线图)
- [许可证](#-许可证)

---

## ✨ 项目介绍

### About The Project

[sqlc](https://sqlc.dev) 是一个从 SQL 查询自动生成类型安全数据库代码的编译器。它通过 WASM 插件接口支持自定义代码生成目标。

本项目是一个 sqlc WASM 插件，将 sqlc 的查询分析结果编译为 **MoonBit** 源码。开发者只需编写标准 SQL，即可获得经过类型检查的 MoonBit 数据库操作函数，无需手动编写 ORM 映射或 CRUD 样板代码。

**设计初衷：**

1. **消除运行时开销** — 生成代码直接调用 DB connection 的函数式 API，无 ORM 反射开销
2. **类型安全** — 利用 MoonBit 的强类型系统在编译期捕获 SQL 与代码类型不匹配问题
3. **最小 runtime** — 生成的代码仅依赖三个 trait（`DB`、`Row`、`Decoder`），不含真实数据库驱动
4. **AST-based 代码生成** — 所有输出经 AST → Pretty Printer 管道，禁止字符串拼接，保证输出格式一致

### Built With

| 组件 | 技术 | 版本 |
|------|------|------|
| 语言 | [MoonBit](https://www.moonbitlang.com/) | 0.1.20260512 |
| 目标 | WASM (WASI / wasm-gc) | — |
| 宿主 | [sqlc](https://sqlc.dev) | v1 (WASM plugin API) |
| 数据库 | PostgreSQL | MVP |

### 核心功能

- **解析 sqlc CodeGenRequest** — 将 protobuf 协议类型映射为 MoonBit 结构体
- **手动 protobuf 编解码** — varint (LEB128)、length-delimited、嵌入消息，零依赖
- **Connection-oriented API** — 生成函数接受 `DB` 连接参数，无 Repository/DI/ORM 模式
- **增量代码生成** — 按表生成 struct 类型和 CRUD 查询函数
- **Golden Test 验证** — 确定性输出验证，确保生成代码一致性

---

## 🚀 快速开始

### 环境要求

- [MoonBit](https://www.moonbitlang.com/) ≥ 0.1.20260512
- [sqlc](https://sqlc.dev) ≥ v1.27.0（支持 WASM 插件接口）
- PostgreSQL（目标数据库）

### 安装

```bash
# 克隆仓库
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin

# 检查编译
moon check

# 运行测试
moon test

# 构建 WASM 插件二进制
moon build --target wasm
```

### 配置 sqlc

在项目根目录创建 `sqlc.yaml`：

```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./path/to/moonbit_sqlc_plugin.wasm
      sha256: "..."

sql:
  - engine: postgresql
    schema: schema.sql
    queries: query.sql
    codegen:
      out: gen
      plugin: moonbit
      options:
        package: db
```

### 基本用法

**1. 编写 SQL 查询 (`query.sql`)**

```sql
-- name: GetUser :one
SELECT id, name, email, created_at
FROM users
WHERE id = $1;

-- name: ListUsers :many
SELECT id, name, email, created_at
FROM users
ORDER BY created_at DESC;

-- name: CreateUser :one
INSERT INTO users (name, email)
VALUES ($1, $2)
RETURNING id, name, email, created_at;
```

**2. 运行 sqlc 生成代码**

```bash
sqlc generate
```

**3. 使用生成的 MoonBit 代码**

```moonbit
fn init {
  // 创建数据库连接（需用户提供 DB trait 实现）
  let db: DB = connect_to_postgres("host=localhost dbname=myapp")

  // 查询单个用户 — 返回 Option[User]
  let user = query_users_get_by_id(db, 42)
  match user {
    Some(u) => println("Hello, \{u.name}!")
    None => println("User not found")
  }

  // 查询所有用户 — 返回 Array[User]
  let all = query_users_list(db)
  println("Found \{all.length()} users")

  // 创建用户 — 返回新创建的 User
  let new = query_users_create(db, "Alice", "alice@example.com")
  println("Created user \{new.id}")
}
```

生成的函数命名遵循 `query_<表名>_<操作>` 格式（如 `query_users_get_by_id`），参数顺序与 SQL 查询中的 `$1`、`$2` 占位符一致。

---

## 🤝 开发指南

### 项目结构

```
.
├── plugin/              # WASM 插件主包
│   ├── main.mbt         # 入口（WASI _start）
│   ├── types.mbt        # sqlc 协议类型定义
│   └── codec.mbt        # 手动 protobuf 编解码器
├── runtime/             # 生成代码运行时库
│   ├── db.mbt           # DB trait
│   ├── decoder.mbt      # Decoder trait
│   └── row.mbt          # Row trait
├── examples/            # 使用示例
├── tests/               # Golden + 编译测试
├── adr/                 # 架构决策记录
└── tasks/               # 任务追踪
```

### 构建命令

```bash
moon check     # 类型检查
moon build     # 构建调试 WASM
moon test      # 运行所有测试
moon build --target wasm  # 构建发布 WASM
```

### 约定

- `snake_case` 函数名，`PascalCase` 类型名
- Query 函数命名：`query_<表名>_<操作>`
- 测试使用 inline `test { ... }` 块
- 原型字段映射详见 `adr/ADR-001`

### 贡献

1. 查看 [`tasks/active.md`](tasks/active.md) 了解当前进度和待办任务
2. Fork 本仓库并创建特性分支
3. 提交前运行 `moon check` 和 `moon test` 确保无错误
4. 创建 Pull Request

已知问题请查阅 [GitHub Issues](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/issues)。

---

## 🗺 路线图

任务按优先级分为三档：

| 优先级 | 范围 | 进度 |
|--------|------|------|
| **P0** | MVP 必经 — 类型定义、protobuf 编解码、WASI 协议、入口集成、测试 | 3 / 22 |
| **P1** | 迭代 — 文档、CI/CD、示例 | 0 / 2 |
| **P2** | 后续 — MySQL 支持 | 0 / 1 |

详细任务分解见 [`tasks/active.md`](tasks/active.md)，已完成任务见 [`tasks/archive.md`](tasks/archive.md)。

### 架构流水线

```
sqlc → CodeGenRequest (protobuf)
  → P0-002: WASM Plugin Protocol
  → P0-003: Protobuf Adapter Layer
  → P0-004: Internal IR
    → P0-007: Type Mapping
    → P0-008: Type Code Generator
    → P0-009: Query Code Generator
    → P0-005: MoonBit AST
      → P0-006: Pretty Printer
        → CodeGenResponse → 生成 MoonBit 源码
```

---

## 📄 许可证

本项目基于 Apache-2.0 许可证。详见 [LICENSE](LICENSE)。

---

*由 MoonBit 驱动，为 sqlc 生态系统而生。*
