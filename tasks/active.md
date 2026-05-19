# Active Tasks — UI Projection

> 生成时间: 2026-05-19 (revised)
> 项目: MoonBit sqlc WASM Plugin
> 运行时状态来源: `runtime/tasks/active/{id}.yaml`

## P0 — 紧急修复

（全部 39 项已完成 ✅）

## P1 — 迭代

### [P1-001] 文档与示例
- 优先级: P1
- 类型: docs
- 状态: 待办
- 描述: 项目 README、使用示例、API 文档、快速开始指南
- 依赖: P0-002（hard），P0-009（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14

### [P1-002] GitHub Actions CI/CD
- 优先级: P1
- 类型: infra
- 状态: 待办
- 描述: 配置 GitHub Actions 流水线：lint → test → build → release
- 依赖: P0-001（hard），P0-011（hard），P0-012（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14

### [P1-005] Codegen: Decoder + 参数绑定 + :one/:many/:execrows
- 优先级: P1
- 类型: feature
- 状态: 待办
- 描述: type_codegen 改用 typed getter decode；query_codegen 传参 + Result 返回 + 三种模式全覆盖；更新 golden tests
- 依赖: P1-003（hard），P1-004（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-19
- 关联: -

### [P1-006] Transaction Support
- 优先级: P1
- 类型: feature
- 状态: 待办
- 描述: Transaction struct + DB::begin
- 依赖: P1-003（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-19
- 关联: -

### [P1-007] Mock DB + Integration Tests
- 优先级: P1
- 类型: test
- 状态: 待办
- 描述: MockDB 实现 + 端到端集成测试（四种查询模式 + 参数绑定验证）
- 依赖: P1-004（hard），P1-005（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-19
- 关联: -

## P2 — 后续

### [P2-001] MySQL 数据库支持
- 优先级: P2
- 类型: feature
- 状态: 待办
- 描述: 扩展 Type Mapping Layer 支持 MySQL 类型，验证 MySQL 查询生成
- 依赖: P0-006（hard），P0-007（hard），P0-008（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -
