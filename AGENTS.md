# AGENTS.md

## 构建命令

- `moon build` — 构建插件 WASM 二进制
- `moon test` — 运行测试
- `moon check` — 类型检查
- `moon build --target wasm` — 显式指定 WASM 目标

## 设计理念

### 架构风格

1. AST-based code generation — 代码层始终通过 AST → Pretty Printer 管道生成，禁止字符串拼接
2. Connection-oriented functional API — 生成代码接受 DB connection 参数的函数，不引入 Repository/DI/ORM
3. Plugin-host separation — WASM 插件只负责 codegen，不包含真实数据库驱动

### 技术选型理由

1. MoonBit 语言 — 编译到 WASM 体积小、性能高、类型系统强于 TypeScript
2. Monorepo — plugin/runtime/tests 同步演进，避免版本协调问题

### 约定

1. MoonBit 源码风格:
   - 生成代码使用 `snake_case` 函数名，`PascalCase` 类型名
   - 所有生成函数文档注释使用标准 MoonBit doc comment 格式
   - Query 函数命名: `query_<表名>_<操作>` (如 `query_users_by_id`)
   - protobuf 保留关键字 `type` 映射为 `ty`（避免 MoonBit 关键字冲突）
   - 测试使用 inline `test { ... }` 块而非 `_test.mbt`（main 包不支持 blackbox 测试）
   - 空类型数组用 `Array::make(0, <默认值>)` 构造以推断泛型
   - WASI FFI: `String` 在 wasm-gc 可用，`--target wasm` 尚不支持 `Bytes`/`String`（需 `#borrow`/`#owned` 但当前版本有 parse error）

## 决策索引

- ADR-001 — AST-based Code Generation Strategy
- ADR-002 — Runtime Scope（待定）
- ADR-003 — Nullable Strategy（待定）
- ADR-004 — Naming Convention（待定）
- ADR-005 — Type Mapping Policy（待定）
- ADR-006 — AST Stability Policy（待定）

## 远程仓库

- URL: https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
- 默认分支: main
- 推送方式: GitHub PAT (classic, repo scope)
