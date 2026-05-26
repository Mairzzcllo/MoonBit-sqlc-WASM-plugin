# Active Tasks — UI Projection

> 生成时间: 2026-05-26
> 项目: MoonBit sqlc WASM Plugin — Phase C 路线图
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## Sprint S-1 — Value enum + package_name + Release

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **S-001** | Value enum 补全：新增 6 个变体 | P0 | feature | done | P0-008, P0-010(soft) |
| **S-002** | package_name 接入 codegen 管道 | P0 | feature | done | P0-006, P0-011, P0-026(soft) |
| **S-003** | Golden 测试扩展：全 PG 类型覆盖 | P1 | test | done | S-001(hard), P0-011 |
| **S-004** | Release v0.1.0 初始版本标记 | P1 | infra | todo | S-001, S-002, S-003(soft) |

## Phase C (P2) — Codegen 可配置性

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **P2-001** | MySQL 数据库支持 | P2 | feature | 待办 | S-001, S-002 |
| **P2-002** | type_override 支持 | P2 | feature | todo | — |
| **P2-003** | rename 重命名映射 | P2 | feature | todo | — |
| **P2-004** | emit_json / emit_db_tags 标签生成 | P2 | feature | todo | — |
| **P2-005** | 多文件输出支持 | P2 | feature | todo | — |
| **P2-006** | emit_interface 支持 (探索) | P2 | feature | todo | MoonBit trait 更新 |

串行建议: P2-002 → P2-003 → P2-004 → P2-005 (独立可并行，按复杂度递增)
