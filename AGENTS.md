# AGENTS.md

## 构建命令

- `moon build` — 构建插件 WASM 二进制
- `moon test` — 运行测试
- `moon check` — 类型检查
- `moon build --target wasm` — 显式指定 WASM 目标
- `scripts/merge-shim.ps1` — WAT shim 合并脚本 (需 npm i -g wabt)
- `wasm2wat` — 检查 WASM 二进制 WAT 结构
- `wat2wasm` — WAT 编译为 WASM 二进制

## 设计理念

### 架构风格

1. AST-based code generation — 代码层始终通过 AST → Pretty Printer 管道生成，禁止字符串拼接
2. Connection-oriented functional API — 生成代码接受 DB connection 参数的函数，不引入 Repository/DI/ORM
3. Plugin-host separation — WASM 插件只负责 codegen，不包含真实数据库驱动

### 技术选型理由

1. MoonBit 语言 — 编译到 WASM 体积小、性能高、类型系统强于 TypeScript
2. Monorepo — plugin/runtime/tests 同步演进，避免版本协调问题
3. WAT shim ABI bridge — MoonBit `--target wasm` 不支持 wasm-gc、无法构造 WASI iovec 时，手写 WAT shim 层接管 iovec 构造和 raw memory 操作。MoonBit 仅暴露 raw ptr/len，不依赖 runtime allocator/GC internals，不等待上游 FFI 更新。这解决了 MoonBit `--target wasm` 与 sqlc (wasmtime v1.31.1) 的 ABI 不兼容问题

### 约定

1. MoonBit 源码风格:
   - 生成代码使用 `snake_case` 函数名，`PascalCase` 类型名
   - 所有生成函数文档注释使用标准 MoonBit doc comment 格式
   - Query 函数命名: `query_<表名>_<操作>` (如 `query_users_by_id`)
   - protobuf 保留关键字 `type` 映射为 `ty`（避免 MoonBit 关键字冲突）
    - 测试使用 inline `test { ... }` 块而非 `_test.mbt`（main 包不支持 blackbox 测试）
    - 空类型数组用 `Array::make(0, <默认值>)` 构造以推断泛型
    - WASI FFI: 使用 WAT shim ABI bridge 方案。MoonBit `--target wasm` 不支持 reference types 跨 FFI 边界（error 4042: Invalid stub type）。改用反向架构：shim 包装层在 post-merge 阶段注入 MoonBit 模块，通过直接 WAT 调用调用 MoonBit 函数，MoonBit 侧零 FFI 声明。MoonBit 暴露 `pub fn process_message(data: Bytes) -> Bytes` 纯计算入口。
    - WAT shim reserved memory: [1024, 1035] — iovec at 1024 (8 bytes), rof_len at 1032 (4 bytes); [1036, ~65535] — scratch buffer。MoonBit .data 初始段在 10000+，TLSF allocator 元数据在 13136+，区间无冲突
    - `moon test` 在 moonrun 下运行所有 185 测试通过；I/O 层仅在 wasmtime 环境（sqlc generate）时触发
    - 内部模型适配器模式: 原始 protobuf 类型 → adapter 层内建类型 → 下游 IR。adapter 层是 protobuf schema 和 codegen 逻辑之间的唯一桥梁，禁止跨层直接引用 protobuf 类型
    - Enum constructor 引用不包含类型前缀: `One` 而非 `QueryCmd::One`
    - IR 层是独立的 semantic boundary: IR 类型不引用 protobuf 类型（types.mbt）也不引用 MoonBit AST 类型，仅基于 adapter 层类型构建。IR 是 codegen 管道的核心枢纽：adapter → IR → AST → source
    - Runtime 使用 concrete struct + closure 模式（而非 trait），因 MoonBit 0.1 不支持 trait 对象和泛型 trait 方法: DB { exec_fn, execrows_fn }, Row { get_fn }
    - 生成函数 body 中非匹配 return type 的 db 调用使用 `let _ = db.exec(sql)` 丢弃，后跟 `None`（OneRow）/`[]`（ManyRows）
    - MoonBit struct 字段默认 file-private（跨文件/包构造需要 pub fn new() 构造函数）

## 决策索引

- ADR-001 — AST-based Code Generation Strategy
- ADR-002 — Runtime Scope（待定）
- ADR-003 — Nullable Strategy（待定）
- ADR-004 — Naming Convention（待定）
- ADR-005 — Type Mapping Policy（待定）
- ADR-006 — AST Stability Policy（待定）
- ADR-007 — WAT Shim ABI Bridge（已接受）

## 远程仓库

- URL: https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
- 默认分支: main
- 推送方式: GitHub PAT (classic, repo scope)
