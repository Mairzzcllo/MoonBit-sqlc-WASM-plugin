# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: 核心功能完成 — MoonBit 0.1 兼容的 AST/codegen 管道
- **当前任务**: P1-007 ✅ → P1-001 等
- **最新事件**: 2026-05-19 — MockDB + 集成测试: runtime/mock.mbt 含 MockDB preset + 8 个 inline 测试覆盖 :one/:many/:exec/:execrows/错误传播/空结果/typed getter decode。更新 generated.mbt stubs 添加 begin_fn/Transaction。291 测试全通过。
  - sqlc 集成存在已知限制：MoonBit `--target wasm` 始终包含 GC/reference types，sqlc 的 wazero 运行时无法解析
- P0: 39/39 completed ✅
- P1: 5/7 completed (P1-003 ✅ P1-004 ✅ P1-005 ✅ P1-006 ✅ P1-007 ✅)
- P2: 0/1 completed
- 活跃任务: P1-001(待办), P1-002(待办)

## 执行顺序

1. P1-003 → P1-004 → P1-005（核心链完成）
2. P1-006 — 已完成（Transaction Support）
3. P1-007 — 已完成（MockDB + 集成测试）
