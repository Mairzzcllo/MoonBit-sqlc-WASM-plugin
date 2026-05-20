# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: Phase 0 ✅ 全部完成 — Phase 1 进行中
- **最新事件**: 2026-05-20 — P1-011~016 全部完成。P1-011: 移除 Value 未用变体(Bool/Double/Bytes/JsonValue)保留 Date/DateTime。P1-012: plugin/moon.pkg 添加 runtime 依赖。P1-013: 黑盒测试文件重命名(golden_test→golden, wasm_integration_test→wasm_integration)。P1-014: int2/int4/serial→Int, int8/bigint→Int64。P1-015: numeric/decimal→String。P1-016: date→Date, timestamp/timestamptz→DateTime。
- P0: 45/45 completed ✅
- P1: 14/16 completed ✅ (+2: P1-001/002 todo)
- P2: 0/1 completed
- 活跃任务: P1-001(文档), P1-002(CI/CD), P2-001(MySQL支持)

## Phase 0 — 解阻塞 ✅ 全部完成

1. **P0-044 ✅** — 分析 WASM GC 类型影响
2. **P0-045 ✅** — 修复 I/O 帧头协议（原始 protobuf 无帧格式）

## Phase 1 — 工程化清理 ✅ 全部完成

3. **P1-011 ✅** — 清理未使用的 Value 枚举变体
4. **P1-012 ✅** — 修复 plugin/moon.pkg runtime 依赖声明
5. **P1-013 ✅** — 迁移 main 包黑盒测试到非 main 包
6. **P1-014 ✅** — 类型映射: int2/int4 → Int
7. **P1-015 ✅** — 类型映射: numeric → String
8. **P1-016 ✅** — 类型映射: date/timestamp → Date/DateTime
