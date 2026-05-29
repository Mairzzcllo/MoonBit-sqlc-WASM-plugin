# Active Tasks — UI Projection

> 生成时间: 2026-05-29
> 项目: MoonBit sqlc WASM Plugin — Bug Fix Sprint
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## Bug Fix Sprint — 2026-05-29 (5 Bugs)

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **P0-055** | 修复 NULL vs 空字符串: Row 加 null_mask | P0 | fix | ✅ done | — |
| **P2-013** | 清理死代码: store_u8 + encode_u32_le + redundant pub | P2 | refactor | ✅ done | — |
| **P2-014** | inspect→debug_inspect 迁移 type_map.mbt (94 处) | P2 | refactor | ✅ done | — |

## Phase 0 — P0 Hotfix Sprint (数据正确性/运行时崩溃)

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **P0-049** | 修复 get_bytes 非 ASCII 字节损坏 (C1) | P0 | fix | ✅ done | — |
| **P0-050** | 修复 NULL 时静默构造无效对象 (C2) | P0 | fix | ✅ done | — |
| **P0-051** | 修复 Time 字段 file-private 不可访问 (C3) | P0 | fix | ✅ done | — |
| **P0-052** | 修复 memory_grow 返回值未检查 (C4) | P0 | fix | ✅ done | — |
| **P0-053** | 修复 get_time 越界 panic (C5) | P0 | fix | ✅ done | — |
| **P0-054** | 修复 read_varint 无限循环与越界 (C6) | P0 | fix | ✅ done | — |

并行性: P0-049~P0-054 全部并行完成。415/415 tests pass ✅, moon check 0 errors ✅

## Sprint S-1 — Value enum + package_name + Release

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **S-001** | Value enum 补全：新增 6 个变体 | P0 | feature | done | P0-008, P0-010(soft) |
| **S-002** | package_name 接入 codegen 管道 | P0 | feature | done | P0-006, P0-011, P0-026(soft) |
| **S-003** | Golden 测试扩展：全 PG 类型覆盖 | P1 | test | done | S-001(hard), P0-011 |
| **S-004** | Release v0.1.0 初始版本标记 | P1 | infra | ✅ done | S-001, S-002, S-003(soft) |

## Phase C — Codegen 可配置性 + 重构 + 补全

### P1 任务

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **P1-032** | 压缩 16 个重复数组解码器 (M4) | P1 | refactor | ✅ done | — |
| **P1-033** | 合并重复类型映射 (M3) | P1 | refactor | ✅ done | — |
| **P1-034** | MockDB 事务可配置 (M5) | P1 | feature | ✅ done | — |

### P2 任务 — Phase C-4 (2026-05-29) 全部完成 ✅

| ID | 标题 | 优先级 | 类型 | 状态 |
|----|------|--------|------|------|
| **P2-002** | type_override 支持 | P2 | feature | ✅ done |
| **P2-003** | rename 重命名映射 | P2 | feature | ✅ done |
| **P2-004** | emit_json / emit_db_tags 标签生成 | P2 | feature | ✅ done |
| **P2-009** | inspect→debug_inspect 全库迁移 (M7) | P2 | refactor | ✅ done |
| **P2-010** | 清理空文件 decoder.mbt (M6) | P2 | refactor | ✅ done |
| **P2-011** | 补全 protobuf codec wire type 1/5 (M8) | P2 | fix | ✅ done |
| **P2-012** | 小问题批量修复 (四) | P2 | refactor | ✅ done |
| **P2-001** | MySQL 数据库支持 | P2 | feature | pending |
| **P2-005** | 多文件输出支持 | P2 | feature | pending |
| **P2-006** | emit_interface 支持 (探索) | P2 | feature | blocked (MoonBit trait) |
