# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: Phase 0 Hotfix + Phase A/B/C 全部完成 ✅ — Phase D 执行中
- **最新事件**: 2026-06-04 — P0-068/069 + P1-049~053 全部完成 ✅ + CD-04/05/06 cancelled (880 tests)
- P0: 69/69 completed ✅ (P0-001~069 all done!)
- P1: 49/53 completed ✅ (P1-001~034, P1-039~053 done; P1-035~038 remaining)
- P2: 12/12 completed ✅ + 3 cancelled (P2-013~015); P2-001/005/006 superseded
- 活跃 Phase: **Phase D — 架构差距消除 + 100 边界情况修复 Sprint**

## Sprint S-1 — Value enum + package_name + Release

| ID | 标题 | 优先级 | 状态 |
|----|------|--------|------|
| S-001 | Value enum 补全：新增 6 个变体 | P0 | ✅ done |
| S-002 | package_name 接入 codegen 管道 | P0 | ✅ done |
| S-003 | Golden 测试扩展：全 PG 类型覆盖 | P1 | ✅ done |
| S-004 | Release v0.1.0 初始版本标记 | P1 | ✅ done |

并行性: S-001 ↔ S-002 已并行完成；S-003 依赖 S-001；S-004 依赖 S-001+S-002+S-003。
Sprint S-1 全部完成，v0.1.0 tag 已推送，Release workflow 已触发。

## Phase A — 核心缺失功能 (2026-05-25)

| ID | 标题 | 优先级 | 状态 |
|----|------|--------|------|
| P0-046 | 查询注解补全 — :copyfrom / :batch / :execlastid | P0 | ✅ done |
| P0-047 | :exec/:execrows + RETURNING * 语义修复 | P0 | ✅ done |
| P0-048 | 事务集成 — 生成函数支持 Transaction | P0 | ✅ done |

并行性: P0-046 ↔ P0-047 ↔ P0-048 无依赖并行完成。测试: 326/326 pass (原 296)。

### P0-046 交付内容
- `adapter.mbt`: QueryCmd 新增 CopyFrom/Batch/ExecLastId 变体
- `ir.mbt`: cmd_to_cardinality 映射 + raw_cmd 字段跟踪原始命令
- `query_codegen.mbt`: build_body 分支分发到 db.copyfrom/db.batch/db.execlastid
- `runtime/db.mbt`: 新增 3 个 DB 方法 + 闭包字段
- `runtime/mock.mbt`: MockDB 同步扩展

### P0-047 交付内容
- `query_codegen.mbt`: build_return_ty 和 build_body 检查 result_shape
  - ExecResult + Rows → Result[T, DBError] + db.query_row + T::decode
  - ExecResult + None → Result[Int64, DBError] + db.exec (不变)
  - ExecCount + Rows → Result[Array[T], DBError] + db.query + collect
  - ExecCount + None → Result[Int64, DBError] + db.execrows (不变)

### P0-048 交付内容
- `query_codegen.mbt`: build_body 参数化 conn_name；generate_query_fn 接受 conn_name+conn_ty；generate_query_fns 为每个查询生成两个重载（db: DB 和 tx: Transaction）
- `golden.mbt`: GOLDEN_USERS 扩展包含 Transaction 重载

## Phase B — 类型映射精度 (2026-05-26)

1. **P1-024 ✅** — 修复 time/timetz 映射不一致：`query_codegen.mbt:46` `type_to_value_constructor` 中 `"time"|"timetz"` 从 `"DateTime"` 改为 `"String"`，与 `map_pg_name` 一致。
2. **P1-022 ✅** — Runtime wrapper 类型定义：新增 5 个 struct（`Decimal{String}`, `Uuid{String}`, `Duration{Int64}`, `Time{Int,Int,Int,Int}`, `IpAddr{String}`）+ 5 个 Value 变体 + 5 个内联测试。
3. **P1-025 ✅** — 数组解码增强：`get_array` stub 替换为 `decode_array_string`/`decode_array_int64`（基于 `@json.parse` 数组解析）。`field_getter_call` 对 `Array[T]` 生成 `decode_array_<suffix>`，对 `Option[Array[T]]` 先判空再解码。
4. **P1-023 ✅** — Row getter / Value 扩展 + 全链路映射更新：5 对 typed getter（require P1-022）、`type_map.mbt` 映射更新（numeric→Decimal, uuid→Uuid, interval→Duration, time→Time, inet→IpAddr）、`type_to_getter_suffix` 新增 5 个分支、golden 测试同步更新。
- **迁移**: numeric/decimal→Decimal, uuid→Uuid, interval→Duration, time/timetz→Time, inet/cidr→IpAddr（原均为 String fallback）
- **Value 枚举**: 9→14 变体
- **Row getter**: +10 个（5 不可空 + 5 可空）
- **测试**: 331/331 pass (原 326), moon check 0 errors
- **Commit**: `6b62ecd` feat: Phase B — type mapping precision

## Phase C — Codegen 可配置性 + 核心语义修复 (2026-05-26)

### Phase C-1: P1 Bugfixes (P1-026~P1-030)

| ID | 标题 | 优先级 | 状态 |
|----|------|--------|------|
| **P1-026** | RETURNING * codegen 检测 result_shape | P1 | ✅ done |
| **P1-027** | sqlc.yaml "package:" vs "package_name=" 配置不匹配 | P1 | ✅ done |
| **P1-028** | 生成代码缺少 import runtime 语句 | P1 | ✅ done |
| **P1-029** | copyfrom/batch/execlastid raw_cmd 分发 | P1 | ✅ done |
| **P1-030** | Row::get_time 解析格式容错 | P1 | ✅ done |

### Phase C-2: P2 (P2-007, P2-008) + P2-009

| ID | 标题 | 优先级 | 状态 |
|----|------|--------|------|
| **P2-007** | Value enum unused warnings 处理 | P2 | ✅ done |
| **P2-008** | Transaction codegen 精确分发 | P2 | ✅ done |
| **P2-009** | inspect→debug_inspect 全库迁移 (M7) | P2 | ✅ done → 2026-05-29 |

### 交付细节

1. **P1-026 ✅** — `build_return_ty` 和 `build_body` 新增 `result_shape: InternalResultShape` 参数。ExecResult+Rows(fields) → decode 路径；ExecCount+Rows(fields) → 多行 decode。Rows 优先于 raw_cmd。
2. **P1-027 ✅** — `parse_plugin_options` 同时匹配 `package=`（8 字符前缀）和 `package_name=`（13 字符前缀）。`examples/users/sqlc.yaml` 统一为 `package_name:`。
3. **P1-028 ✅** — `generate_source` 在 AST items 首位置插入 `Import({ path: "Mairzzcllo/moonbit_sqlc_plugin/runtime", import_alias: None })`。验证 Golden 输出以 import 开头。
4. **P1-029 ✅** — `build_body` 对 ExecResult+None(result_shape) 根据 `query.raw_cmd` 分发：CopyFrom→`.copyfrom()`、Batch→`.batch()`、ExecLastId→`.execlastid()`、Exec→`.exec()`。
5. **P1-030 ✅** — `Row::get_time` 变精度小数容错：<6 位右补零、>6 位截断、无小数→0。7 个测试覆盖 5 种格式。
6. **P2-007 ✅** — Value enum 5 个 unused 变体通过 5 个显式构造测试块消除警告（MoonBit 0.1 不支持 `@suppress` 在 enum variant 上）。新增额外 roundtrip 测试。
7. **P2-008 ✅** — `supports_transaction(cmd: QueryCmd)` 辅助函数：One/Many/Exec/ExecRows→true，CopyFrom/Batch/ExecLastId→false。`generate_query_fns` 对不支持的方法仅生成 db 版本，消除不必要的双倍代码。15 个测试。
- **测试**: 366/366 pass (原 296), moon check 0 errors

## Phase C-3: P1 重构 (P1-032~P1-034) — 2026-05-28

| ID | 标题 | 优先级 | 类型 | 状态 |
|----|------|--------|------|------|
| **P1-032** | 压缩 16 个重复数组解码器 (M4) | P1 | refactor | ✅ done |
| **P1-033** | 合并重复类型映射 (M3) | P1 | refactor | ✅ done |
| **P1-034** | MockDB 事务可配置 (M5) | P1 | feature | ✅ done |

并行性: 全部独立并行完成。测试: 449/449 pass (+34 from P1-034 tx tests), moon check 0 errors。

## Phase 0 — P0 Hotfix Sprint (2026-05-28)

> 🔴 数据正确性/运行时崩溃 Bug，优先于新功能修复

| ID | 标题 | 文件 | 状态 |
|----|------|------|------|
| **P0-049** | C1: get_bytes 非 ASCII 损坏 — `(raw[i].to_int() & 0xFF).to_byte()` 修复 4 处 | runtime/row.mbt | ✅ done |
| **P0-050** | C2: NULL 静默无效对象 — 6 个 getter 空字符串→Err(TypeError) | runtime/row.mbt | ✅ done |
| **P0-051** | C3: Time 字段加 pub — hour/min/sec/micros | runtime/value.mbt | ✅ done |
| **P0-052** | C4: memory_grow 返回值检查 — `if result < 0 { break }` | plugin/wasi_io.mbt | ✅ done |
| **P0-053** | C5: get_time 越界 panic — parts 长度 ≤3 检查 | runtime/row.mbt | ✅ done |
| **P0-054** | C6: read_varint 越界 — read_byte 加 pos≥end 检查 | plugin/codec.mbt | ✅ done |

并行性: 全部并行完成。`moon test` 415/415 pass ✅, `moon check` 0 errors ✅。

## Phase C-3 — P2 全部完成 (2026-05-29)

| ID | 标题 | 优先级 | 类型 | 状态 |
|----|------|--------|------|------|
| **P2-010** | M6: 清理空文件 decoder.mbt | P2 | refactor | ✅ done |
| **P2-011** | M8: 补全 protobuf codec wire type 1/5 | P2 | fix | ✅ done |
| **P2-012** | 小问题批量: JsonValue→Json + NoRows 上下文 + Show/Eq | P2 | refactor | ✅ done |
| **P2-009** | M7: inspect→debug_inspect 全库迁移 (784 处) | P2 | refactor | ✅ done |
| **P2-002** | type_override 支持 | P2 | feature | ✅ done |
| **P2-004** | emit_json / emit_db_tags 标签生成 | P2 | feature | ✅ done |
| **P2-003** | rename 重命名映射 | P2 | feature | ✅ done |

### Bug Fix Sprint — 2026-05-30

| ID | 标题 | 优先级 | 类型 | 状态 |
|----|------|--------|------|------|
| **P0-055** | 修复 NULL vs 空字符串: Row 加 null_mask | P0 | fix | ✅ done |
| **P2-013** | 清理死代码: store_u8 + encode_u32_le + redundant pub | P2 | refactor | ✅ done |
| **P2-014** | inspect→debug_inspect 迁移 type_map.mbt (94 处) | P2 | refactor | ✅ done |

### P0-055 交付内容
- `Row` struct 新增 `null_mask: Array[Bool]`，`Row::is_null(index)` 方法
- 所有非空 getter 改用 `is_null` 判断（空字符串不再误判为 TypeError）
- 所有可空 getter 改用 `is_null` 判断（'' 不再误判为 None）
- 同步更新 `runtime/db.mbt`、`runtime/transaction.mbt`、`runtime/mock.mbt` 中所有 Row 构造
- 同步更新 `tests/integration/{basic,wasm}/generated.mbt` 中 Row stub
- 测试: 481/481 pass

### P2-013 交付内容
- 删除 `store_u8` 死函数（wasi_io.mbt）
- 删除 `encode_u32_le`/`decode_u32_le` 死代码 + 14 个测试（protocol.mbt）
- 删除 Time 字段冗余 `pub`（value.mbt）

### P2-014 交付内容
- type_map.mbt 中 94 处 `inspect(` → `debug_inspect(`
- `ast.mbt` 新增 `impl Debug for TypeExpr`

### Phase C-4 — Superseded (→ Phase D)

| 旧 ID | 新 ID | 标题 | 状态 |
|-------|-------|------|------|
| **P2-001** | **P1-035** | MySQL 支持 (upgraded P2→P1) | ❌ cancelled → P1-035 |
| **P2-005** | **P0-060** | 多文件输出 (upgraded P2→P0) | ❌ cancelled → P0-060 |
| **P2-006** | **P1-038** | emit_interface (upgraded P2→P1) | ❌ cancelled → P1-038 |

## Phase D — 架构差距消除 Sprint (2026-05-29)

**背景**: 架构评审识别 9 个 GAP vs 成熟生态插件 (sqlc-gen-go/python/kotlin/typescript)。全部提升为 P0/P1 优先级，2 周 Sprint。

**并行策略**: P0-056~060 可全部并行执行; P1-035 依赖 P0-058(hard); P1-036/038 独立; P1-037 最后。

### P0-056 交付内容 ✅
- runtime/value.mbt: 新增 `ExecResult { last_insert_id: Int64, rows_affected: Int64 }` + 构造函数 + inline test
- plugin/query_codegen.mbt:
  - `build_return_ty`: ExecResult+None → `Result[ExecResult, DBError]`; ExecCount+None 不变
  - `build_body`: ExecResult+None 裸 Call 改为 Match 包裹 ExecResult::new()
    - Exec/CopyFrom/Batch: `ExecResult::new(0L, n)` (rows_affected=n)
    - ExecLastId: `ExecResult::new(n, 1L)` (last_insert_id=n)
- plugin/golden.mbt: GOLDEN_USERS 中 query_delete_user 更新为 ExecResult 返回 + Match body
- 测试: 486/486 pass (482 original + 4 new Match arm structure tests)

### P0-057 交付内容 ✅
- **7 新选项**: emit_sql_as_comment（SQL 注释）, omit_unused_structs（跳过未用结构体）, emit_empty_slices（空结果返回空数组）, initialisms（命名缩写）, json_tags_case_style（标签大小写风格）, emit_exact_table_names（精确表名）, emit_methods_with_db_argument（DB 参数函数风格）（原 query_parameter_limit 已在 P1-053 移除）
- **naming.mbt (NEW)**: capitalize_first, lowercase_first, parse_initialisms, snake_to_pascal/camel, apply_case_style + 21 内联测试
- **adapter.mbt**: 所有选项解析支持 snake_case + kebab-case；全部布尔选项有 =true/=false 分支；+27 内联测试
- **type_codegen.mbt**: omit_unused_structs 过滤；emit_exact_table_names 透传；initialisms 影响枚举/结构体命名；json_tags_case_style 影响标签
- **query_codegen.mbt**: emit_sql_as_comment 生成 SQL 文档注释；emit_empty_slices 正确匹配 Err(NoRows)→Ok([]) 而非掩盖所有错误；emit_methods_with_db_argument 文档澄清
- **golden.mbt**: 7 个新 golden 变体覆盖 emit_sql_as_comment、json_tags_case_style、initialisms、emit_exact_table_names、emit_empty_slices、emit_methods_with_db_argument、omit_unused_structs
- **测试**: 555/555 pass (+68 from 486), moon check 0 errors

### P0-059 交付内容 ✅
- runtime/value.mbt: 新增 `TimeTZ { hour: Int, min: Int, sec: Int, micros: Int, tz_offset: Int }` struct + `Value::TimeTZ(TimeTZ)` 变体 + inline test
- runtime/row.mbt: 新增 `get_timetz(pos) -> Result[TimeTZ, DBError]` 和 `get_nullable_timetz(pos) -> Result[Option[TimeTZ], DBError]`
- plugin/type_map.mbt: `"timetz"` → `"TimeTZ"` 映射；`type_to_value_constructor` 新增 `"TimeTZ"` → `TimeTZ(...)` 构造函数
- plugin/type_codegen.mbt: `type_to_getter_suffix` 新增 `"TimeTZ"` → `"timetz"` 映射
- plugin/query_codegen.mbt: `type_to_value_constructor("TimeTZ")` 返回 `Value::TimeTZ(...)` 表达式
- 测试: 597/597 pass (+26 from 571)

### P0-060 交付内容 ✅
- plugin/main.mbt: `generate_sources()` 返回 `Array[(String, String)]`，拆分 types.mbt (structs/enums) 和 queries.mbt (查询函数)
- `process_request()` 遍历 generate_sources 结果为每个输出文件创建 `GenerateResponse.File` 条目
- `generate_source()` 保留为向后兼容的单一文件入口
- plugin/golden.mbt: golden 测试更新为期望 types.mbt + queries.mbt 双文件输出
- 测试: 598/598 pass (+1 golden test from 597)

### Phase D-1 — 100 边界情况 P0 批次修复 (2026-06-01)

| ID | 边界情况 # | 标题 | 类型 | 状态 |
|----|-----------|------|------|------|
| **P0-063** | #60 | 字段解码按列名而非索引 — Row 新增 col_names + index_of()→Result | bugfix | ✅ done |
| **P0-064** | #89 | 输出路径穿越防护 — validate_output_path 拒绝 `..` 段 + Windows 驱动器检测 | bugfix | ✅ done |
| **P0-065** | #88 | MoonBit 关键字冲突 — escape_keyword 覆盖 55+ 关键字 + rename_to 也转义 | bugfix | ✅ done |
| **P0-066** | #31, #35, #36, #53 | 空/无效标识符处理 — snake_to_pascal("")→"Empty", convert_column/query fallback | bugfix | ✅ done |
| **P0-067** | #10 | iovec 保留内存区间隔离验证 — panic 诊断消息 + startups check 顺序 | bugfix | ✅ done |

**5 任务全部经 3 轮 coder→tester→reviewer 迭代完成。**
**测试**: 682/682 pass (+13 from 669), moon check 0 errors.

### Phase D-2 — 100 边界情况 P1 批次修复 (2026-06-01)

| ID | 边界情况 # | 标题 | 类型 | 状态 |
|----|-----------|------|------|------|
| **P1-039** | #3, #4 | Codec 静默错误传播 — read_string/decode_embedded 错误→abort | bugfix | ✅ done |
| **P1-040** | #17, #18, #19 | 类型格式验证 — 5 个 parse_* 函数 (Date/DateTime/UUID/IP/Decimal) | feature | ✅ done |
| **P1-041** | #50, #51, #54-59 | 命名边缘情况加固 — 重复/冲突/特殊字符 | bugfix | ✅ done |
| **P1-042** | #66-69 | MockDB API — builder 模式 + 按 SQL 匹配 | feature | ✅ done |
| **P1-043** | #73-79 | Test 覆盖扩展 — 多表/数组/枚举/命令生成器 | test | ✅ done |
| **P1-044** | #83, #85 | DBError 增强 — TooManyRows(Int, String) + ColumnNotFound(String) | feature | ✅ done |
| **P1-045** | #87, #90 | 代码生成去重与包名保护 — import 去重 + 空包名 guard | bugfix | ✅ done |
| **P1-046** | #37, #43, #72 | Row 运行时加固 — check_bounds() + collect_limited() | bugfix | ✅ done |
| **P1-047** | #52 | 枚举运行时值验证 — 变体匹配检查测试 | bugfix | ✅ done |
| **P1-048** | #80-82 | 集成测试基础设施加固 — basic/wasm 同步 + 编译隔离 | test | ✅ done |

**10 任务全部经 3 轮 coder→tester→reviewer 迭代完成。**
**测试**: 870/870 pass (+188 from 682), moon check 0 errors.

### Phase D-3 — I/O 基础设施加固 + Codec 错误传播 + 死代码清理 (2026-06-04)

| ID | 类型 | 标题 | 状态 |
|----|------|------|------|
| **P0-068** | bugfix | scratch/.data 内存重叠 — GC Bytes::new 动态分配 I/O 缓冲区 | ✅ done |
| **P0-069** | bugfix | emit_sql_as_comment 默认值文档一致化 (false→true) | ✅ done |
| **P1-049** | bugfix | decode_embedded 错误传播 — Decoder error 标记 | ✅ done |
| **P1-050** | bugfix | read_varint 截断错误 — error flag 替代部分返回值 | ✅ done |
| **P1-051** | bugfix | skip_field 未知 wire type — error 标记通知调用者 | ✅ done |
| **P1-052** | bugfix | write_all Bytes 悬垂指针 — _keep_alive 双重引用保活 | ✅ done |
| **P1-053** | cleanup | query_parameter_limit 死代码移除 | ✅ done |
| **P2-013** | refactor | parse_plugin_options 硬编码索引重构 | ❌ cancelled (CD-04) |
| **P2-014** | refactor | snake_case/kebab-case 解析去重 | ❌ cancelled (CD-05) |
| **P2-015** | refactor | trim_str Unicode 空白字符扩展 | ❌ cancelled (CD-06) |

**测试**: 880/880 pass (+10 from 870), moon check 0 errors.

#### P0-068 交付内容
- `plugin/wasi_io.mbt`: scratch 缓冲区从固定 [1036,65535] 改为 GC `Bytes::new(65536)` 动态分配
- 移除 `SCRATCH`/`SCRATCH_END`/`memory_grow` 常量和手动内存管理
- `read_all` 使用 `bytes_data_ptr(buf)` 获取 iovec.buf 地址
- `verify_reserved_memory()` 简化为仅验证 [1024,1035] iovec 结构区域
- 根因：固定 scratch 地址与 MoonBit .data 段 (10000+) 和 TLSF 元数据 (13136+) 实际重叠

#### P0-069 交付内容
- `README.md`:157 `emit_sql_as_comment` 默认值从 `false` 纠正为 `true`
- 代码中 4 个独立位置均确认为 `true`（struct doc comment / 空数据默认 / 可变初始值 / 单元测试）
- 检查 `docs/runtime-api.md` 无相关错误引用

#### P1-049~P1-051 交付内容（Codec 错误传播三连）
- `plugin/codec.mbt`: `Decoder` struct 新增 `mut error: Bool = false` 字段
- **P1-049**: `decode_embedded` 异常分支（len<0 或 len>remaining）设置 `dec.error = true` 后跳过 payload
- **P1-050**: `read_varint` 中 `remaining() <= 0` 时设置 `self.error = true`；`read_tag`/`read_string`/`read_bytes`/`read_bool` 调用后检查 error 标记
- **P1-051**: `skip_field` 未知 wire type (6+) 保留跳至 message end，新增 error 标记；WT_LEN/WT_BITS64/WT_BITS32 OOB 同步设置
- 顶层 `decode_generate_request`/`decode_generate_response` 循环后检查 error 标记并 abort
- 新增 10 个错误传播/截断检测测试

#### P1-052 交付内容
- `plugin/wasi_io.mbt`: `write_all` 在 `bytes_data_ptr(data)` 后添加 `let _keep_alive = data` 具名引用
- while 循环体内引用 `data.length()` 双重保活，防止 GC 回收底层内存导致悬垂指针
- `read_all` 同步添加 `_keep_alive` 保护
- `P0-068` 动态 Bytes 分配方案从架构层面消除此类风险

#### P1-053 交付内容
- `PluginOptions` 移除 `query_parameter_limit` 字段
- `parse_plugin_options` 移除 snake_case + kebab-case 两处解析分支
- `generate_sources`/`generate_source` 移除字段传递
- `main.mbt` 两处 TODO 注释已删除
- `README.md` 中相关文档行已移除
- 移除约 4 个相关单元测试

#### Code Debt 取消记录 (CD-04/05/06)
以下 3 个 P2 重构任务因 MoonBit 0.1 工具链限制取消：

| CD | 任务 | 限制 |
|----|------|------|
| **CD-04** | P2-013 硬编码索引重构 (split API) | MoonBit 0.1 String::split 不可靠，边界行为未定义 |
| **CD-05** | P2-014 parse 解析去重 (replace API) | MoonBit 0.1 String::replace 在 WASM 目标下可能触发 GC 导致 raw ptr 失效 |
| **CD-06** | P2-015 Unicode 空白字符支持 | MoonBit 0.1 不支持 UInt16 hex 字面量比较 (0x3000)，Char::to_int() 行为未定义 |

这些任务将在 MoonBit 工具链成熟（String API 稳定 + Unicode code point 支持）后重新评估。

### P0 任务

| ID | GAP | 标题 | 类型 | 状态 | 依赖 |
|----|-----|------|------|------|------|
| **P0-056** | GAP-2 | :execresult 完整语义 — LastInsertId + RowsAffected 结构体 | feature | ✅ done | — |
| **P0-057** | GAP-4 | 插件选项扩展 — 7 新选项（query_parameter_limit 后续移除） | feature | ✅ done | — |
| **P0-058** | GAP-3 | 类型覆盖扩展 — column 级 + nullable 级覆盖 | feature | ✅ done | — |
| **P0-059** | GAP-7 | TIMETZ 时区支持 — 新增 TimeTZ struct + Value 变体 | feature | ✅ done | — |
| **P0-060** | GAP-1 | 多文件输出 — 按类型/查询拆分 + output_*_file_name 配置 | feature | ✅ done | — |

### P1 任务

| ID | GAP | 标题 | 类型 | 状态 | 依赖 |
|----|-----|------|------|------|------|
| **P1-035** | GAP-5 | MySQL 数据库支持 — 类型映射 + 查询验证 | feature | todo | P0-058(hard) |
| **P1-036** | GAP-8 | 根目录 sqlc.yaml 工作模板填充 | config | todo | — |
| **P1-037** | GAP-9 | E2E 集成测试 — PowerShell 调用 sqlc + WASM | test | todo | P0-056/057/060(soft) |
| **P1-038** | GAP-6 | emit_interface 探索 — MoonBit trait 限制 + MockDB 替代 | research | todo | — (Blocked) |

### 100 边界情况分析 (2026-05-30)

**结论**: 100 个边界情况中，30 个已被历史任务覆盖，20 个为设计决策，剩余 **~50 个** 新增为 7 个 P0 + 10 个 P1 任务。

### 新增 P0 任务 (P0-061~P0-067)

| ID | 边界情况 # | 标题 | 类型 | 状态 |
|----|-----------|------|------|------|
| P0-061 | #5, #9, #11, #13 | Codec bounds hardening — skip_field/OOB/error→abort | bugfix | ✅ done |
| P0-062 | #84 | :one 多行静默取第一条 — TooManyRows 错误 | bugfix | ✅ done |
| P0-063 | #60 | 字段解码按索引而非列名 — 列顺序变化静默错位 | bugfix | ✅ done |
| P0-064 | #89 | 输出路径穿越防护 — out_name 合法性验证 | bugfix | ✅ done |
| P0-065 | #88 | MoonBit 关键字冲突 — 全部关键字转义 | bugfix | ✅ done |
| P0-066 | #31, #35, #36, #53 | 空/无效标识符处理 | bugfix | ✅ done |
| P0-067 | #10 | iovec 保留内存区间隔离验证 | bugfix | ✅ done |

### 新增 P1 任务 (P1-039~P1-048)

| ID | 边界情况 # | 标题 | 类型 | 状态 |
|----|-----------|------|------|------|
| P1-039 | #3, #4 | Codec 静默错误传播 | bugfix | ✅ done |
| P1-040 | #17, #18, #19 | 类型格式验证 | feature | ✅ done |
| P1-041 | #50, #51, #54-59 | 命名边缘情况加固 | bugfix | ✅ done |
| P1-042 | #66-69 | MockDB 可用性改进 | feature | ✅ done |
| P1-043 | #73-79 | Test 覆盖扩展 | test | ✅ done |
| P1-044 | #83, #85 | DBError 增强 | feature | ✅ done |
| P1-045 | #87, #90 | 代码生成去重与包名保护 | bugfix | ✅ done |
| P1-046 | #37, #43, #72 | Row 运行时加固 | bugfix | ✅ done |
| P1-047 | #52 | 枚举运行时值验证 | bugfix | ✅ done |
| P1-048 | #80-82 | 集成测试基础设施加固 | test | ✅ done |

### 设计决策保留 (不修复)

- #24/#25: 所有 int→Int64, 所有 float→Double (统一化设计)
- #14/#29/#32/#33: 未知类型→String fallback, 无表→无输出 (静默回退)
- #12: 无帧头协议 (P0-045 决议)
- #44/#46/#47: wrapper 类型无格式验证, 调试输出格式 (MVP 边界)
- #49: 0 变体枚举 (MoonBit 允许)
- #62/#65: Transaction 无 copyfrom/batch (P2-008 决议), 无线程安全

## 技术决策记录

1. **GAP-2 ExecResult**: `ExecResult { last_insert_id: Int64, rows_affected: Int64 }` 双值结构体，类似 sql.Result
2. **GAP-7 TimeTZ**: 新增独立 struct `TimeTZ { hour, min, sec, micros: Int, tz_offset: Int }`，Value 新增 `TimeTZ(TimeTZ)` 变体
3. **GAP-3 Overrides**: 扩展 adapter 解析 `overrides[]` 配置，支持 `column` 精确列匹配和 `nullable` 可空覆盖
4. **GAP-4 Options** ✅: 全部 7 个选项通过 `parse_plugin_options` 统一提取，`PluginOptions` struct 新增字段。naming.mbt 新增命名转换工具链。emit_empty_slices 正确实现 Err(NoRows) 过滤。（query_parameter_limit 已在 P1-053 移除。）
5. **GAP-9 E2E**: PowerShell 脚本调用本地 sqlc.exe + WASM 验证生成结果

## 关键勘误记录（2026-05-22 代码评审）

1. **`:execresult` IR 已实现** — `ExecResult` 和 `ExecCount` 在 ir.mbt 中对应 `:exec` 和 `:execrows`，此前规划误判为缺失
2. **PostgreSQL enum 已支持** — `generate_enum_from_enum()` 在 type_codegen.mbt 中完整实现，golden 输出包含 `UserRole` enum
3. **Engine 字段在 AdaptSettings 非 AdaptCatalog** — adapter.mbt 定义 `AdaptSettings.engine`，此前规划误标为 `AdaptCatalog`
4. **`package_name` key 无 mismatch** — 解析器期望 `package_name=`，配置也使用 `package_name=`，一致
5. **`nullable_style: pointer` 不可行** — MoonBit 0.1 无指针类型，`Option[T]` 唯一可空表示（ADR-003）
6. **Value enum 9 变体确认** — `JsonValue(Json)` 复用 `@json.Json` 类型；Date/DateTime 复用 runtime 内建 struct
7. **`type_to_value_constructor()` 完整** — 无需修改，已有全部映射
8. **`param_to_value_expr()` nullable 分支正确** — `Some(x) => Ctor(x)` 类型推导正确
9. **`emit_empty_slices` 推迟至 Phase C** — 与 ADR-003 冲突

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
13. **P1-001 ✅** — 文档与示例: README 同步、quickstart.md、runtime-api.md、examples/README
14. **P1-002 ✅** — GitHub Actions CI/CD: check→test→build→validate + release workflow
15. **P1-021 ✅** — 修复验证脚本假阴性: wasm2wat 2>$null + -join

## Phase A 完成工作 (2026-05-25)

1. **P0-046 ✅** — 查询注解补全：`adapter.mbt` QueryCmd 新增 CopyFrom/Batch/ExecLastId 三个变体；`parse_query_cmd` 识别 `:copyfrom`/`:batch`/`:execlastid`；`ir.mbt` `cmd_to_cardinality` 映射到 ExecResult 并新增 `raw_cmd` 跟踪；`query_codegen.mbt` `build_body` 分发到 `db.copyfrom`/`db.batch`/`db.execlastid`；`runtime/db.mbt` 新增 3 个方法 + 闭包字段；`runtime/mock.mbt` 同步扩展。新增 36 个测试。
2. **P0-047 ✅** — `:exec`/`:execrows` + RETURNING * 语义修复：`build_return_ty` 和 `build_body` 检查 `query.result_shape`，当有结果行时像 OneRow/ManyRows 一样返回类型化解码结果，无结果行时保持 Int64 行为。
3. **P0-048 ✅** — 事务集成：`build_body` 参数化 `conn_name`；`generate_query_fn` 接受 `conn_name+conn_ty`；`generate_query_fns` 为每个查询生成 `fn query_xxx(db: DB, ...)` 和 `fn query_xxx(tx: Transaction, ...)` 两个重载。GOLDEN_USERS 更新。

## Sprint S-1 完成工作 (2026-05-22)

1. **S-001 ✅** — Value enum 补全：新增 Bool/Double/Bytes/Date/DateTime/JsonValue 六个变体，补齐 9 变体完整集合。新增 6 个内联测试。moon test 302/302 pass (原 296)。
2. **S-002 ✅** — package_name 接入 codegen 管道：`generate_source` 接受 `PluginOptions` 参数；`emit_source_file` 新增 `emit_package_declaration()` 前置输出 `"package <name>\n\n"`；GOLDEN_USERS 更新包含 package 声明行；`make_users_request` 设置 `plugin_options: b"package_name=testdb"`。
   - **Bug 修复**: `parse_plugin_options` 中 `s[14:]` 应为 `s[13:]`（`"package_name="` 为 13 字符非 14），导致包名首字符被静默丢弃（`"testdb"` → `"estdb"`）
3. **S-003 ✅** — Golden 测试扩展：全 PG 类型覆盖。新增 `make_all_types_request()` 构建含 17 个 PG 类型（bool, float8, bytea, date, timestamp, timestamptz, jsonb, numeric, uuid, inet, int2, float4, varchar, time, interval, text[], int4）的 GenerateRequest。新增 3 个 golden 测试验证 struct 字段类型、decode getter、Value constructor。moon test 305/305 pass (原 302)。
4. **S-004 ✅** — Release v0.1.0: `git tag v0.1.0 && git push origin v0.1.0` ✅。Release workflow 在 GitHub Actions 中自动运行。AGENTS.md 测试计数同步更新 (296→415)。
