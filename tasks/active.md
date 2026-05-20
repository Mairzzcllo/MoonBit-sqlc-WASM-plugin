# Active Tasks — UI Projection

> 生成时间: 2026-05-20
> 项目: MoonBit sqlc WASM Plugin
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## Phase 0 — 解阻塞 (P0)

*全部完成 ✅*

## Phase 1 — 工程化清理 (P1)

### [P1-001] 文档与示例
类型: docs | 状态: todo | 创建: 2026-05-14
描述: 项目 README、使用示例、API 文档、快速开始指南

### [P1-002] GitHub Actions CI/CD
类型: infra | 状态: todo | 创建: 2026-05-14
描述: 配置 GitHub Actions 流水线：lint → test → build → release

### [P1-011] 清理未使用的 Value 枚举变体
类型: refactor | 状态: todo | 创建: 2026-05-20
描述: Bool/Double/Bytes/Date/DateTime/JsonValue 6 变体未构造，移除或标注

### [P1-012] 修复 plugin/moon.pkg runtime 依赖声明
类型: fix | 状态: todo | 创建: 2026-05-20
描述: 添加 Mairzzcllo/moonbit_sqlc_plugin/runtime 到 moon.pkg，对齐 AGENTS.md 约定

### [P1-013] 迁移 main 包黑盒测试到 inline test 块
类型: refactor | 状态: todo | 创建: 2026-05-20
描述: 消除 "Main package uses blackbox-only test inputs" 警告

### [P1-014] 类型映射修复: int2/int4 → Int（当前 Int64）
类型: fix | 状态: todo | 创建: 2026-05-20
描述: type_map.mbt 修改映射表 + golden test 更新

### [P1-015] 类型映射修复: numeric → String（当前 Double 精度丢失）
类型: fix | 状态: todo | 创建: 2026-05-20
描述: numeric/decimal → String，消除大精度数值丢失

### [P1-016] 类型映射修复: date/timestamp → Date/DateTime（当前 String）
类型: fix | 状态: todo | 创建: 2026-05-20
描述: 利用 runtime 已定义的 Date/DateTime 封装类型

## P2 — 后续

### [P2-001] MySQL 数据库支持
类型: feature | 状态: todo | 创建: 2026-05-14
描述: 扩展 Type Mapping Layer 支持 MySQL 类型
