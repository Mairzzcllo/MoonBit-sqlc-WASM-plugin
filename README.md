# MoonBit sqlc WASM Plugin

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260512-db6e2a?style=flat-square)](https://www.moonbitlang.com/)
[![sqlc](https://img.shields.io/badge/sqlc-v1_WASM_plugin-00b4d8?style=flat-square)](https://sqlc.dev)
[![License](https://img.shields.io/badge/license-Apache--2.0-brightgreen?style=flat-square)](LICENSE)
[![version](https://img.shields.io/badge/version-0.1.0-blue?style=flat-square)](moon.mod.json)

> Generate type-safe MoonBit database code from SQL queries — a WASM plugin for [sqlc](https://sqlc.dev).

## 项目介绍

[sqlc](https://sqlc.dev) 是一个从 SQL 查询自动生成类型安全数据库代码的编译器。它通过 WASM 插件接口支持自定义代码生成目标。

本项目是一个 sqlc WASM 插件，将 sqlc 的查询分析结果编译为 **MoonBit** 源码。开发者只需编写标准 SQL，即可获得经过类型检查的 MoonBit 数据库操作函数，无需手动编写 ORM 映射或 CRUD 样板代码。

**设计初衷：**

1. **消除运行时开销** — 生成代码直接调用 DB connection 的函数式 API，无 ORM 反射开销
2. **类型安全** — 利用 MoonBit 的强类型系统在编译期捕获 SQL 与代码类型不匹配问题
3. **最小 runtime** — 生成代码依赖三个 concrete struct：`DB`、`Row`、`Decoder`，不含真实数据库驱动
4. **AST-based 代码生成** — 所有输出经 AST → Pretty Printer 管道，禁止字符串拼接

### Built With

| 组件 | 技术 | 版本 |
|------|------|------|
| 语言 | [MoonBit](https://www.moonbitlang.com/) | 0.1.20260512 |
| 目标 | WASM (WASI preview1) | — |
| 宿主 | [sqlc](https://sqlc.dev) | v1.31.1 (wasmtime) |
| 数据库 | PostgreSQL | MVP |

## 架构

### 内部管道

```
sqlc → CodeGenRequest (protobuf)
  → P0-002: WASM Plugin Protocol (protocol.mbt)
  → P0-003: Protobuf Adapter Layer (adapter.mbt)
  → P0-004: Internal IR (ir.mbt)
    → P0-007: Type Mapping (type_map.mbt)
    → P0-008: Type Code Generator (type_codegen.mbt)
    → P0-009: Query Code Generator (query_codegen.mbt)
    → P0-005: MoonBit AST (ast.mbt)
      → P0-006: Pretty Printer (emitter.mbt)
        → CodeGenResponse → 生成 MoonBit 源码
```

### Native WASI I/O via Inline WAT FFI

MoonBit `--target wasm` 支持内联 WAT FFI（`= "module" "name"` 语法直接导入 WASI 函数，`= "(func ...)"` 执行原始内存操作）。I/O 层完全在 MoonBit 侧实现，无需外部 shim。

```
┌─────────────────────────────────────┐
│  wasmtime (sqlc generate)           │
│  ┌─ plugin.wasm ─────────────────┐  │
│  │  ┌─ wasi_io.mbt ─────────────┐│  │
│  │  │  inline WAT FFI           ││  │
│  │  │  fd_read / fd_write       ││  │
│  │  │  run_io_loop (_start)     ││  │
│  │  └───────────────────────────┘│  │
│  │  ┌─ codegen pipeline ────────┐│  │
│  │  │  process_message          ││  │
│  │  │  decode_request →         ││  │
│  │  │  process_request →        ││  │
│  │  │  encode_response          ││  │
│  │  └───────────────────────────┘│  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

iovec 结构（12 字节）固定在预留内存 `[1024, 1035]` 区域（iovec at 1024, rof_len at 1032），数据缓冲区由 GC `Bytes::new` 动态分配。构建一步到位：`moon build --target wasm`，无后处理步骤。

## 快速开始

### 环境要求

- [MoonBit](https://www.moonbitlang.com/) ≥ 0.1.20260512
- [sqlc](https://sqlc.dev) ≥ v1.27.0

### 安装

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon check
moon test
```

### 构建 WASM 插件

```bash
moon build --target wasm
```

### 配置 sqlc

`sqlc.yaml`:
```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./target/wasm/release/build/plugin/plugin.wasm
      sha256: <build 后填入>
sql:
  - engine: postgresql
    schema: schema.sql
    queries: query.sql
    codegen:
      out: gen
      plugin: moonbit
```

### 生成代码用法

```moonbit
fn init {
  let db: DB = connect_to_postgres("host=localhost dbname=myapp")

  let user = query_users_get_by_id(db, 42)
  match user {
    Some(u) => println("Hello, \{u.name}!")
    None => println("User not found")
  }

  let all = query_users_list(db)
  println("Found \{all.length()} users")

  let new = query_users_create(db, "Alice", "alice@example.com")
  println("Created user \{new.id}")
}
```

### Runtime 设计

Runtime 使用 concrete struct + closure 模式（因 MoonBit 0.1 不支持 trait 对象和泛型 trait 方法）：

```moonbit
pub struct DB {
  exec_fn : (String) -> Int
  execrows_fn : (String) -> Int64
}
```

生成函数中非匹配 return type 的 db 调用使用 `let _ = db.exec(sql)` 丢弃。

### 插件选项

在 `sqlc.yaml` 的 `codegen:` 段 `plugin_options:` 中支持以下配置：

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `package_name` | string | `"main"` | 生成代码的包名 |
| `emit_json_tags` | bool | `false` | 生成 `@json.tag("name")` 注解 |
| `emit_db_tags` | bool | `false` | 生成 `@db.tag("name")` 注解 |
| `emit_sql_as_comment` | bool | `false` | 在函数上方嵌入原始 SQL 作为 doc comment |
| `omit_unused_structs` | bool | `false` | 跳过未被查询引用的 struct 类型生成 |
| `emit_empty_slices` | bool | `false` | `:many` 无结果时返回空数组 `[]` 而非 `Err(NoRows)` |
| `initialisms` | string | `""` | 逗号分隔的首字母缩写词，如 `"API,HTTP,ID"` |
| `json_tags_case_style` | string | `"snake"` | JSON 标签命名风格：`snake` / `camel` / `pascal` |
| `query_parameter_limit` | int | `0` | 查询参数数量上限（`0` = 无限制） |
| `emit_exact_table_names` | bool | `false` | struct 名使用数据库表名原样（不转换单复数） |
| `emit_methods_with_db_argument` | bool | `false` | 生成显式接收 `db: DB` 参数的方法变体（实验性） |

示例：
```yaml
codegen:
  out: gen
  plugin: moonbit
  plugin_options:
    - package_name=moonbit_app
    - emit_json_tags=true
    - emit_empty_slices=true
    - initialisms=API,HTTP,ID
    - json_tags_case_style=camel
```

> **注意**: 所有选项均向后兼容，默认值保持现有行为。

## 项目结构

```
.
├── plugin/              # WASM 插件主包 (15 .mbt 文件)
│   ├── main.mbt         # 入口 (fn main → run_io_loop)
│   ├── wasi_io.mbt      # Native WASI I/O via inline WAT FFI
│   ├── protocol.mbt     # WASM 插件协议 + process_message
│   ├── adapter.mbt      # Protobuf → 内部模型适配器
│   ├── types.mbt        # Protobuf 协议类型定义
│   ├── codec.mbt        # 手动 protobuf 编解码 (LEB128 + length-delimited)
│   ├── ir.mbt           # 中间表示层 (codegen 核心枢纽)
│   ├── ast.mbt          # MoonBit AST 定义
│   ├── emitter.mbt      # Pretty Printer (AST → 源码)
│   ├── type_map.mbt     # SQL 类型 → MoonBit 类型映射
│   ├── type_codegen.mbt # 类型代码生成器
│   ├── query_codegen.mbt# 查询函数代码生成器
│   └── golden.mbt       # Golden 测试（确定性输出验证）
├── naming.mbt           # 命名转换 (initialisms, case style) — 顶层共享模块
├── runtime/             # 生成代码运行时库
│   ├── db.mbt           # DB concrete struct (exec/execrows/query/query_row/begin)
│   ├── row.mbt          # Row concrete struct (typed getter 16 种)
│   ├── row_iter.mbt     # RowIter streaming iterator
│   ├── transaction.mbt  # Transaction (commit/rollback)
│   ├── value.mbt        # Value enum + Date/DateTime wrappers
│   ├── error.mbt        # DBError enum
│   └── mock.mbt         # MockDB for testing
├── shim/archive/        # 存档 (WAT shim 参考实现)
├── examples/users/      # 完整使用示例 (schema.sql + query.sql + sqlc.yaml)
├── tests/               # 集成测试 (basic + wasm)
├── docs/                # API 参考与快速开始指南
├── adr/                 # 架构决策记录 (14 条)
└── tasks/               # 任务追踪 (active.md + archive/)
```

## 测试

```bash
moon check              # 类型检查
moon test               # 运行所有 555 个 inline 测试
```

测试使用 inline `test { ... }` 块而非 `_test.mbt` 文件（main 包不支持 blackbox 测试）。空类型数组用 `Array::make(0, <默认值>)` 构造以推断泛型。

## 约定

- 代码层始终通过 **AST → Pretty Printer** 管道生成，禁止字符串拼接
- 生成函数使用 **snake_case** 函数名，**PascalCase** 类型名
- Query 函数命名：`query_<表名>_<操作>`（如 `query_users_by_id`）
- protobuf 保留关键字 `type` 映射为 `ty`
- Enum constructor 不包含类型前缀：`One` 而非 `QueryCmd::One`
- MoonBit struct 字段默认 file-private，跨文件构造需要 `pub fn new()`
- 所有 doc comment 使用标准 MoonBit `///` 格式

## 架构决策记录

| ADR | 标题 | 状态 |
|-----|------|------|
| ADR-001 | AST-based Code Generation Strategy | Accepted |
| ADR-002 | Runtime Scope | Accepted (v3) |
| ADR-003 | Nullable Strategy | Draft |
| ADR-004 | Naming Convention | Draft |
| ADR-005 | Type Mapping Policy | Draft |
| ADR-006 | AST Stability Policy | Draft |
| ADR-007 | WAT Shim ABI Bridge | Superseded (by ADR-008) |
| ADR-008 | Native WASI I/O via Inline WAT FFI | Accepted |
| ADR-009 | Known Limitations and MVP Boundaries | Draft |
| ADR-010 | Transaction Support: Concrete Struct + Closure Pattern | Accepted |
| ADR-011 | Codegen Build Body: result_shape Priority and Method Dispatch | Accepted |
| ADR-012 | Phase D Architecture Gaps: ExecResult, Type Overrides, TimeTZ | Accepted |
| ADR-013 | 100 Edge Cases Analysis: Classification and Fix Feasibility | Accepted |
| ADR-014 | Plugin Options Extension (GAP-4) | Accepted |

## 路线图

详细任务分解见 [`tasks/active.md`](tasks/active.md)，已完成任务见 [`tasks/archive.md`](tasks/archive.md)。

## 许可证

Apache-2.0。详见 [LICENSE](LICENSE)。

*由 sqlc 驱动，为 MoonBit 生态而生。*
