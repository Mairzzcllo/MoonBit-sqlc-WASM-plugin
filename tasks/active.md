# Active Tasks — UI Projection

> 生成时间: 2026-06-15 | 测试: 887 pass, 0 fail
> 项目: MoonBit sqlc WASM Plugin — P0 70/72 ✅, P1 49/53, P2 12/12 (+3 cancelled)
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## 活跃 P0 任务 (2)

| ID | 标题 | 优先级 | 类型 | 状态 | 来源 |
|----|------|--------|------|------|------|
| **P0-071** | wasi_io panic() → 错误信号替代 — 防止内存哨兵崩溃 | P0 | fix | todo | Bug 报告 #2 |
| **P0-072** | decode_embedded 损坏长度 → error flag 通知 | P0 | fix | todo | Bug 报告 #3 |

## 活跃 P1 任务 (12)

| ID | 标题 | 优先级 | 类型 | 状态 | 来源 |
|----|------|--------|------|------|------|
| **P1-035** | MySQL 数据库支持 — 类型映射 + 查询验证 | P1 | feature | todo | GAP-5 |
| **P1-036** | 根目录 sqlc.yaml 工作模板填充 | P1 | config | todo | GAP-8 |
| **P1-037** | E2E 集成测试 — PowerShell 调用 sqlc + WASM | P1 | test | todo | GAP-9 |
| **P1-038** | emit_interface 探索 — MoonBit trait 限制 + MockDB 替代 | P1 | research | todo | GAP-6 |
| **P1-054** | stdin read_all 最大上限 — 防 OOM | P1 | fix | todo | Bug 报告 #4 |
| **P1-055** | 无效 option 格式 warn + query_parameter_limit 死代码清理 | P1 | fix | todo | Bug 报告 #5, #6 |
| **P1-056** | wire type 4 + 未知 PG 类型 error flag 完善 | P1 | fix | todo | Bug 报告 #7, #8 |
| **P1-057** | null_mask OOB 安全加固 — 静默 not-null → 返回 NULL | P1 | fix | todo | Bug 报告 #12 |
| **P1-058** | 空标识符 sentinel "Empty" → "UnnamedType" 消除碰撞 | P1 | fix | todo | Bug 报告 #10 |
| **P1-059** | PG 数组 JSON 解码兼容 — 兼容 {a,b,c} 原生格式 | P1 | fix | todo | Bug 报告 #11 |
| **P1-060** | 枚举/结构体名称冲突自动消歧后缀 | P1 | fix | todo | Bug 报告 #9 |
| **P1-061** | 死选项清理: emit_methods_with_db_argument + emit_exact_table_names | P1 | refactor | todo | Q3, Q4 |

## 最近完成 (2026-06-15)

| ID | 标题 | 来源 |
|----|------|------|
| **P0-070** | codec abort() → error flag — 防止 WASM trap | Bug 报告 #1 |
| P0-068 | scratch/.data 内存重叠修复 | DR-02 |
| P0-069 | emit_sql_as_comment 默认值一致性 | CD-03 |
| P1-049 | decode_embedded 负长度错误传播 | CD-07 |
| P1-050 | read_varint 静默截断 | CD-08 |
| P1-051 | skip_field 未知 wire type 加固 | CD-09 |
| P1-052 | write_all 悬垂指针 | CP-02 |
| P1-053 | 移除 query_parameter_limit 死代码 | CD-01 |

已归档至 `tasks/archive.md` 及 `tasks/tasks/archive/`。
