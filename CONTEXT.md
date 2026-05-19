# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: 核心功能完成 — MoonBit 0.1 兼容的 AST/codegen 管道
- **当前任务**: P1-005 ✅ → P1-001 等
- **最新事件**: 2026-05-19 — 解决 MoonBit 0.1 编译器限制：移除 `?` 操作符（改用嵌套 match + Err(e) 传播）、移除 `{|...|}` lambda（改用 fn(...) + for 循环）、修复 return 在 let-binding 中的类型问题。Emitter 重构多行 match 格式化。新增 Index/BinOp/If 发射器测试。272 测试全通过。
  - sqlc 集成存在已知限制：MoonBit `--target wasm` 始终包含 GC/reference types，sqlc 的 wazero 运行时无法解析
- P0: 39/39 completed ✅
- P1: 3/7 completed (P1-003 ✅ P1-004 ✅ P1-005 ✅)
- P2: 0/1 completed
- 活跃任务: P1-006(待办), P1-007(待办), P1-001(待办), P1-002(待办)

## 执行顺序

1. P1-003 → P1-004 → P1-005（核心链完成）
2. P1-006 可在 P1-003 后并行
3. P1-007 在 P1-005 后收尾验证
