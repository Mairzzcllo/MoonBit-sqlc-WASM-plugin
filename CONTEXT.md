# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: Phase 0 ✅ 全部完成 — Phase 1 进行中
- **最新事件**: 2026-05-20 — P1-019(P1-021 连续完成：文件名修复 + 警告清理 + 脚本假阴性修复。P1 仅剩 P1-001(文档) 和 P1-002(CI/CD)。
- P0: 45/45 completed ✅
- P1: 18/21 completed ✅ (+2 todo: P1-001/002)
- P2: 0/1 completed
- 活跃任务: P1-001(文档), P1-002(CI/CD), P2-001(MySQL)

## Phase 0 — 解阻塞 ✅ 全部完成

1. **P0-044 ✅** — 分析 WASM GC 类型影响
2. **P0-045 ✅** — 修复 I/O 帧头协议（原始 protobuf 无帧格式）

## Phase 1 — 工程化清理 ✅ 全部完成

3. **P1-011 ⚠️ 重新打开** — 清理未使用的 Value 枚举变体（Date/DateTime 变体仍存在，移至 P1-020 完成）
4. **P1-012 ✅** — 修复 plugin/moon.pkg runtime 依赖声明
5. **P1-013 ✅** — 迁移 main 包黑盒测试到非 main 包
6. **P1-014 ✅** — 类型映射: int2/int4 → Int
7. **P1-015 ✅** — 类型映射: numeric → String
8. **P1-016 ✅** — 类型映射: date/timestamp → Date/DateTime
9. **P1-017 ❌ 已取消** — StringView 理论经验证不成立
10. **P1-018 ✅** — to_snake_case() + $ 转义移除
11. **P1-019 ✅** — 输出文件名修复: codegen.out 作为目录前缀 + "lib.mbt"
12. **P1-020 ✅** — 清理编译警告: 16→1 (pre-existing), 296 tests pass
13. **P1-021 ✅** — 修复验证脚本假阴性: wasm2wat 2>$null + -join
