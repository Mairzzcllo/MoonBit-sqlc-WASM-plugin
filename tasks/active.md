# Active Tasks — UI Projection

> 生成时间: 2026-06-01
> 项目: MoonBit sqlc WASM Plugin — Phase D: 架构差距消除 + 边界情况修复
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## Phase D — 架构差距消除 + 100 边界情况修复 Sprint

并行策略:
- P0-056~060 ↔ P0-061~067 (可并行, 互不依赖)
- P1-035 → P0-058(hard); P1-037 → P0-056/057/060(soft)
- P1-039~048 ↔ P0-061~067 (可并行)

### P0 任务

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **P0-057** | 插件选项扩展 (8 新选项) | P0 | feature | done | — |
| **P0-058** | 类型覆盖扩展 (column + nullable) | P0 | feature | done ✅ | — |
| **P0-059** | TIMETZ 时区支持 (TimeTZ struct) | P0 | feature | done ✅ | — |
| **P0-060** | 多文件输出支持 | P0 | feature | done ✅ | — |
| **P0-061** | Codec bounds hardening — skip_field/OOB/error→abort | P0 | bugfix | todo | — |
| **P0-062** | :one 查询多行静默取第一条 — TooManyRows 错误 | P0 | bugfix | todo | — |
| **P0-063** | 字段解码按列名而非索引 — 列顺序变化静默错位 | P0 | bugfix | ✅ done ✅ | — |
| **P0-064** | 输出路径路径穿越防护 — out_name 合法性验证 | P0 | bugfix | ✅ done ✅ | — |
| **P0-065** | MoonBit 关键字冲突 — 字段名转义覆盖全部关键字 | P0 | bugfix | ✅ done ✅ | — |
| **P0-066** | 空/无效标识符处理 — 空名称/空类型/空查询名 | P0 | bugfix | ✅ done ✅ | — |
| **P0-067** | iovec 保留内存区间隔离验证与加固 | P0 | bugfix | ✅ done ✅ | — |

### P1 任务

| ID | 标题 | 优先级 | 类型 | 状态 | 依赖 |
|----|------|--------|------|------|------|
| **P1-035** | MySQL 数据库支持 | P1 | feature | todo | P0-058(hard) |
| **P1-036** | 根目录 sqlc.yaml 模板填充 | P1 | config | todo | — |
| **P1-037** | E2E 集成测试 (PowerShell) | P1 | test | todo | P0-056/057/060(soft) |
| **P1-038** | emit_interface 探索 (MockDB 替代) | P1 | research | todo | — (Blocked by MoonBit) |

### 旧任务状态

| 旧 ID | 新 ID | 状态 |
|-------|-------|------|
| P2-001 (MySQL) | → P1-035 | ❌ cancelled |
| P2-005 (多文件) | → P0-060 | ❌ cancelled |
| P2-006 (interface) | → P1-038 | ❌ cancelled |
