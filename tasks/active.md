# Active Tasks — UI Projection

> 生成时间: 2026-06-15 | 测试: 899 pass, 0 fail
> 项目: MoonBit sqlc WASM Plugin — P0 72/72 ✅, P1 57/61, P2 12/12 (+3 cancelled)
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## 活跃 P0 任务 (0)

**Batch A 完成** — P0-070 ~ P0-072 全部归档。

## 活跃 P1 任务 (4)

| ID | 标题 | 优先级 | 类型 | 状态 | 来源 |
|----|------|--------|------|------|------|
| **P1-035** | MySQL 数据库支持 — 类型映射 + 查询验证 | P1 | feature | todo | GAP-5 |
| **P1-036** | 根目录 sqlc.yaml 工作模板填充 | P1 | config | todo | GAP-8 |
| **P1-037** | E2E 集成测试 — PowerShell 调用 sqlc + WASM | P1 | test | todo | GAP-9 |
| **P1-038** | emit_interface 探索 — MoonBit trait 限制 + MockDB 替代 | P1 | research | todo | GAP-6 |

## 最近完成 (2026-06-15 Batch B)

| ID | 标题 | 来源 |
|----|------|------|
| **P1-061** | 死选项清理: emit_methods_with_db_argument + emit_exact_table_names | Q3, Q4 |
| **P1-060** | 枚举/结构体名称冲突自动消歧后缀 | Bug 报告 #9 |
| **P1-059** | PG 数组 JSON 解码兼容 — {a,b,c} 原生格式 | Bug 报告 #11 |
| **P1-058** | 空标识符 sentinel Empty → UnnamedType | Bug 报告 #10 |
| **P1-057** | null_mask OOB 安全加固 | Bug 报告 #12 |
| **P1-056** | wire type 4 + 未知 PG 类型 warn | Bug 报告 #7, #8 |
| **P1-055** | 无效 option warn + query_parameter_limit 清理 | Bug 报告 #5, #6 |
| **P1-054** | stdin read_all 16MB 上限 | Bug 报告 #4 |
| P0-071 | wasi_io panic() → Bool 优雅降级 | Bug 报告 #2 |
| P0-072 | decode_embedded field-level has_error() 传播 | Bug 报告 #3 |
| P0-070 | codec abort() → error flag | Bug 报告 #1 |

已归档至 `tasks/archive.md` 及 `tasks/tasks/archive/`。
