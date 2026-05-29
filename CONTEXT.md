# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: Phase 0 Hotfix 全部完成 ✅ — Phase C 活跃
- **最新事件**: 2026-05-29 — P2-002/003/004/009/010/011/012 全部完成 (497 测试通过)
- P0: 54/54 completed ✅
- P1: 30/30 completed ✅
- P2: 10/10 completed ✅ (+ 全部 P2 任务)
- 活跃 Phase: **Phase C — 全部完成** ✅

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

### Phase C-4 — Pending

| ID | 标题 | 优先级 | 类型 | 状态 |
|----|------|--------|------|------|
| **P2-001** | MySQL 数据库支持 | P2 | feature | pending |
| **P2-005** | 多文件输出支持 | P2 | feature | pending |
| **P2-006** | emit_interface 支持 (探索) | P2 | feature | blocked |

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
