# Active Tasks — UI Projection

> 生成时间: 2026-06-04 | 测试: 880 pass, 0 fail
> 项目: MoonBit sqlc WASM Plugin — P0 69/69 ✅, P1 49/53, P2 12/12 (+3 cancelled)
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## 活跃任务 (4)

| ID | 标题 | 优先级 | 类型 | 状态 | 阻塞原因 |
|----|------|--------|------|------|----------|
| **P1-035** | MySQL 数据库支持 — 类型映射 + 查询验证 | P1 | feature | todo | 需 P0-058 基础设施 |
| **P1-036** | 根目录 sqlc.yaml 工作模板填充 | P1 | config | todo | — |
| **P1-037** | E2E 集成测试 — PowerShell 调用 sqlc + WASM | P1 | test | todo | 需 sqlc 环境 |
| **P1-038** | emit_interface 探索 — MoonBit trait 限制 + MockDB 替代 | P1 | research | todo | MoonBit 0.1 无 trait object |

## 最近完成 (2026-06-04)

| ID | 标题 | 来源 |
|----|------|------|
| P0-068 | scratch/.data 内存重叠修复 | DR-02 |
| P0-069 | emit_sql_as_comment 默认值一致性 | CD-03 |
| P1-049 | decode_embedded 负长度错误传播 | CD-07 |
| P1-050 | read_varint 静默截断 | CD-08 |
| P1-051 | skip_field 未知 wire type 加固 | CD-09 |
| P1-052 | write_all 悬垂指针 | CP-02 |
| P1-053 | 移除 query_parameter_limit 死代码 | CD-01 |

已归档至 `tasks/archive.md` 及 `tasks/tasks/archive/`。
