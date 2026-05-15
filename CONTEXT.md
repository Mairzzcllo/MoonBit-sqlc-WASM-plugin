# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: 规划完成，待开发
- **当前任务**: P0-020 (protocol.mbt: 4-byte LE framing + WASI 读写)
- **最新事件**: /task P0-019 完成（codec.mbt + moon check ✅ + moon test 19/19 ✅）
- **远程仓库**: https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git

## 技术栈

- 语言: MoonBit
- 目标: WASM (WASI)
- 宿主: sqlc v1 (WASM plugin API)
- 数据库: PostgreSQL (MVP), MySQL (后续)

## 目录结构

```
.
├── adr/               # 架构决策记录
├── events/            # 事件日志（按任务分目录）
├── runtime/
│   └── tasks/
│       ├── active/    # 任务运行时状态 (YAML)
│       └── archive/   # 已完成任务归档
├── tasks/active.md    # UI projection (read-only)
├── CONTEXT.md         # 上下文快照
└── AGENTS.md          # 项目知识库
```

## 架构概要

```
sqlc → CodeGenRequest (protobuf)
  → P0-002: WASM Plugin Protocol
  → P0-003: Protobuf Adapter Layer
  → P0-004: Internal IR (semantic boundary)
    ├→ P0-007: Type Mapping Layer
    └→ P0-008: Type Code Generator
      └→ P0-009: Query Code Generator
        → P0-005: MoonBit AST Definition
          → P0-006: Pretty Printer / Emitter
            → CodeGenResponse → 生成 MoonBit 源码
```

层间严格单向依赖：protobuf → IR → AST → source。禁止跨层跳转。

## 关键决策

| 决策 | 选择 |
|------|------|
| 代码生成 | AST-based (非 string-concat) |
| API 风格 | Connection-oriented functional |
| 项目结构 | Monorepo |
| 数据库策略 | MVPs 不含真实 DB runtime |
| 测试策略 | Golden Tests + Compilation Tests |

## 任务进度

- P0: 3/22 completed
- P1: 0/2 completed
- P2: 0/1 completed
