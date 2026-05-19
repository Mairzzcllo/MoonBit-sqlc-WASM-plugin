# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: 规划完成 — P1 参数化查询 + 类型安全运行时阶段
- **当前任务**: P1-004 ✅ → P1-005 待执行
- **最新事件**: 2026-05-19 — P1-004 完成。runtime/row.mbt 新增 16 个类型化 getter（8 不可空 + 8 可空：int64/string/bool/double/bytes/date/datetime/json），使用 @string.parse_* 解析 + @json.parse 解析 JSON。runtime/moon.pkg 添加 @json/@string 导入。269 测试全通过。
- P0: 39/39 completed ✅
- P1: 2/7 completed (P1-003 ✅ P1-004 ✅)
- P2: 0/1 completed
- 活跃任务: P1-005(待办), P1-006(待办), P1-007(待办), P1-001(待办), P1-002(待办)

## 执行顺序

1. P1-003 → P1-004 → P1-005（核心链，串行依赖）
2. P1-006 可在 P1-003 后并行
3. P1-007 在 P1-005 后收尾验证
