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

### WAT Shim ABI Bridge

MoonBit `--target wasm` 无法在 FFI 边界传递引用类型（Bytes/String）（error 4042: Invalid stub type）。解决方案是 **WAT shim ABI bridge**：手写 WAT 包装层接管所有 I/O（WASI fd\_read/fd\_write、iovec 构造、LE framing），MoonBit 仅暴露纯计算入口 `process_message(data: Bytes) -> Bytes`。

```
┌─────────────────────────────────────┐
│  wasmtime (sqlc generate)           │
│  ┌─ plugin.wasm ─────────────────┐  │
│  │  ┌─ WAT shim (wasi_shim.wat)─┐│  │
│  │  │  _start 协议循环           |│  │
│  │  │  fd_read → decode frame   |│  │
│  │  │  → process_message →      |│  │
│  │  │  encode frame → fd_write  |│  │
│  │  └───────────────────────────┘│  │
│  │  ┌─ MoonBit codegen ─────────┐│  │
│  │  │  protocol.mbt             ││  │
│  │  │  adapter.mbt → ir.mbt     ││  │
│  │  │  → codegen → emitter.mbt  ││  │
│  │  └───────────────────────────┘│  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

Shim 和 MoonBit 的 WAT 通过 `scripts/merge-shim.ps1` 在文本层面合并。构建流程：

1. `moon build --target wasm` → `.core` 目标文件
2. `moonc link-core` → 完整 WAT
3. 解析 mangled 函数名
4. 合并 `shim/wasi_shim.wat` 到 MoonBit WAT
5. `wat2wasm` → `plugin.wasm`

> 当前 MoonBit 工具链 (v0.9.2) 的死代码消除会移除未被 `_start` 可达的函数，导致链接输出为 215 字节的 stub。完整 WASM 输出需要 MoonBit 工具链支持 standalone WASM export。

## 快速开始

### 环境要求

- [MoonBit](https://www.moonbitlang.com/) ≥ 0.1.20260512
- [sqlc](https://sqlc.dev) ≥ v1.27.0
- [wabt](https://github.com/WebAssembly/wabt) (`npm i -g wabt`，提供 `wat2wasm`)

### 安装

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon check
moon test
```

### 构建 WASM 插件

```bash
# 构建插件
moon build --target wasm

# 合并 WAT shim 并编译为 WASM
./scripts/merge-shim.ps1
```

### 配置 sqlc

`sqlc.yaml`:
```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./_build/plugin.wasm
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

## 项目结构

```
.
├── plugin/              # WASM 插件主包 (13 .mbt 文件)
│   ├── main.mbt         # 入口（空 main，被 shim _start 替换）
│   ├── protocol.mbt     # WASM 插件协议 + 4-byte LE framing
│   ├── adapter.mbt      # Protobuf → 内部模型适配器 (336 行)
│   ├── types.mbt        # Protobuf 协议类型定义
│   ├── codec.mbt        # 手动 protobuf 编解码 (LEB128 + length-delimited)
│   ├── ir.mbt           # 中间表示层 (codegen 核心枢纽)
│   ├── ast.mbt          # MoonBit AST 定义
│   ├── emitter.mbt      # Pretty Printer (AST → 源码)
│   ├── type_map.mbt     # SQL 类型 → MoonBit 类型映射
│   ├── type_codegen.mbt # 类型代码生成器
│   ├── query_codegen.mbt# 查询函数代码生成器
│   └── golden_test.mbt  # Golden 测试（确定性输出验证）
├── runtime/             # 生成代码运行时库
│   ├── db.mbt           # DB concrete struct (exec/execrows)
│   ├── decoder.mbt      # Decoder concrete struct
│   └── row.mbt          # Row concrete struct (get_fn closure)
├── shim/
│   └── wasi_shim.wat    # WAT shim ABI bridge (I/O 层)
├── scripts/
│   └── merge-shim.ps1   # WAT shim 合并构建脚本
├── examples/            # 使用示例
├── tests/               # 集成测试
├── adr/                 # 架构决策记录 (7 条)
└── tasks/               # 任务追踪 (active.md + archive.md)
```

## 测试

```bash
moon check              # 类型检查
moon test               # 运行所有 185 个 inline 测试
moon test --target wasm # 以 WASM 目标运行测试
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
| ADR-002 | Runtime Scope | Draft |
| ADR-003 | Nullable Strategy | Draft |
| ADR-004 | Naming Convention | Draft |
| ADR-005 | Type Mapping Policy | Draft |
| ADR-006 | AST Stability Policy | Draft |
| ADR-007 | WAT Shim ABI Bridge | Accepted |

## 路线图

详细任务分解见 [`tasks/active.md`](tasks/active.md)，已完成任务见 [`tasks/archive.md`](tasks/archive.md)。

## 许可证

Apache-2.0。详见 [LICENSE](LICENSE)。

*由 MoonBit 驱动，为 sqlc 生态系统而生。*
