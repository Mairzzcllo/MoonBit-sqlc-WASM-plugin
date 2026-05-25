# Active Tasks — UI Projection

> 生成时间: 2026-05-25
> 项目: MoonBit sqlc WASM Plugin — 修正路线图 Sprint S-1
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## Sprint S-1 — Value enum + package_name + Release

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **S-001** | Value enum 补全：新增 6 个变体 | P0 | feature | done | P0-008, P0-010(soft) |
| **S-002** | package_name 接入 codegen 管道 | P0 | feature | done | P0-006, P0-011, P0-026(soft) |
| **S-003** | Golden 测试扩展：全 PG 类型覆盖 | P1 | test | done | S-001(hard), P0-011 |
| **S-004** | Release v0.1.0 初始版本标记 | P1 | infra | todo | S-001, S-002, S-003(soft) |

所有 Sprint S-1 子任务已完成，S-004 可执行。

## Phase 1 待启动

| ID | 标题 | 优先级 | 前置条件 |
|----|------|--------|----------|
| P2-001 | MySQL 数据库支持 | P2 | S-001, S-002 |
