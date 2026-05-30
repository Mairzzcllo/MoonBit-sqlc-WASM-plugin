# AGENTS.md

## 构建命令

- `moon build` — 构建插件 WASM 二进制（等同于 `moon build --target wasm`）
- `moon test` — 运行测试（481 测试）
- `moon check` — 类型检查
- `moon build --target wasm` — 显式指定 WASM 目标
- `wasm2wat` — 检查 WASM 二进制 WAT 结构（需 npm i -g wabt）
- CI/CD: `.github/workflows/ci.yml` (check→test→build→validate) + `.github/workflows/release.yml` (tag v*)
- Docs: `docs/quickstart.md` (快速开始), `docs/runtime-api.md` (API 参考)
- 生成代码示例: `examples/` — `sqlc generate` 在 `examples/users/` 下可完整运行

## 设计理念

### 架构风格

1. AST-based code generation — 代码层始终通过 AST → Pretty Printer 管道生成，禁止字符串拼接
2. Connection-oriented functional API — 生成代码接受 DB connection 参数的函数，不引入 Repository/DI/ORM
3. Plugin-host separation — WASM 插件只负责 codegen，不包含真实数据库驱动

### 技术选型理由

1. MoonBit 语言 — 编译到 WASM 体积小、性能高、类型系统强于 TypeScript
2. Monorepo — plugin/runtime/tests 同步演进，避免版本协调问题
3. Native WASI I/O via inline WAT FFI — MoonBit `--target wasm` 支持 `= "module" "name"` 语法直接导入 WASI 函数，以及 `= "(func ...)"` 内联 WAT 执行原始内存操作。iovec 结构（12 字节）固定在 [1024,1035]，数据缓冲区由 GC Bytes::new 动态分配。构建一步到位（`moon build --target wasm`），无后处理步骤。保留了 shim 设计参考文档在 `shim/archive/` 供 MoonBit 工具链更新后对比优化。

### 约定

1. MoonBit 源码风格:
   - 生成代码使用 `snake_case` 函数名，`PascalCase` 类型名
   - 所有生成函数文档注释使用标准 MoonBit doc comment 格式
   - Query 函数命名: `query_<表名>_<操作>` (如 `query_users_by_id`)
   - protobuf 保留关键字 `type` 映射为 `ty`（避免 MoonBit 关键字冲突）
    - 测试使用 inline `test { ... }` 块而非 `_test.mbt`（main 包不支持 blackbox 测试）
    - 空类型数组用 `Array::make(0, <默认值>)` 构造以推断泛型
    - WASI FFI: 使用内联 WAT ABI bridge 方案。MoonBit `--target wasm` 支持 `= "module" "name"` 语法直接导入 WASI 函数，以及 `= "(func ...)"` 内联 WAT 执行原始内存操作。iovec 结构体（12 字节）固定在 [1024,1035]，数据缓冲区由 GC Bytes::new 动态分配。
    - Reserved memory: [1024, 1035] — iovec at 1024 (8 bytes), rof_len at 1032 (4 bytes); [1036, ~65535] — scratch buffer。MoonBit .data 初始段在 10000+，TLSF allocator 元数据在 13136+，区间无冲突
    - `moon test` 在 moonrun 下运行所有 481 测试通过；I/O 层仅在 wasmtime 环境（sqlc generate）时触发
    - AST Expr 新增变体：`If(cond, then, else)`、`Index(target, idx)`、`IntLit(n)`、`BinOp(op, left, right)` — 用于生成 if/else、索引访问、数字字面量和比较表达式
    - Plugin options 解析：`parse_plugin_options(bytes)` → `PluginOptions { package_name }` — 从 `plugin_options` Bytes 中提取 key=value 配置。支持 `package_name=` 和 `package=` 双前缀（兼容 sqlc yaml 中 `package:` 和 `package_name:` 两种写法）
    - 输出文件名从 `req.settings.codegen.out` 获取，空值时默认 `"lib.mbt"`（process_request）
    - plugin/moon.pkg 依赖 `Mairzzcllo/moonbit_sqlc_plugin/runtime` 保证编译期兼容性
    - 内部模型适配器模式: 原始 protobuf 类型 → adapter 层内建类型 → 下游 IR。adapter 层是 protobuf schema 和 codegen 逻辑之间的唯一桥梁，禁止跨层直接引用 protobuf 类型
    - Enum constructor 引用不包含类型前缀: `One` 而非 `QueryCmd::One`
    - IR 层是独立的 semantic boundary: IR 类型不引用 protobuf 类型（types.mbt）也不引用 MoonBit AST 类型，仅基于 adapter 层类型构建。IR 是 codegen 管道的核心枢纽：adapter → IR → AST → source
- Runtime 使用 concrete struct + closure 模式（而非 trait），因 MoonBit 0.1 不支持 trait 对象和泛型 trait 方法: DB { exec_fn, execrows_fn, query_fn, query_row_fn }, Row { get_fn, null_mask }, RowIter { next_fn }
- Value 枚举: `Null | Int64(Int64) | String(String) | Bool(Bool) | Double(Double) | Bytes(Array[Byte]) | Date(Date) | DateTime(DateTime) | JsonValue(Json) | Decimal(Decimal) | Uuid(Uuid) | Duration(Duration) | Time(Time) | IpAddr(IpAddr)` — JsonValue 变体使用 `@json.Json` 类型，非 `JsonValue`
- DBError 枚举: `ConnectionError(String) | QueryError(String) | TypeError(String) | NoRows`
- DB 方法签名：`exec(sql, Array[Value]) -> Result[Int64, DBError]`；`execrows(sql, Array[Value]) -> Result[Int64, DBError]`；`query(sql, Array[Value]) -> Result[RowIter, DBError]`；`query_row(sql, Array[Value]) -> Result[Row, DBError]`
- Row 类型化 getter：不可空 `get_int64(pos) -> Result[Int64, DBError]` 等；可空 `get_nullable_int64(pos) -> Result[Option[Int64], DBError]`，每对覆盖 Int64/String/Bool/Double/Bytes/Date/DateTime/JsonValue 八种类型
- RowIter 方法：`next() -> Result[Option[Row], DBError]`；`collect() -> Result[Array[Row], DBError]`
- 生成函数 body：:one 使用 `db.query_row(sql, params)?; let row = ...; row.decode()` → `Result[T, DBError]`；:many 使用 `db.query(sql, params)?; iter.map(|row| T::decode(row)).collect()` → `Result[Array[T], DBError]`；:execrows 使用 `db.execrows(sql, params)` → `Result[Int64, DBError]`
- Decode 方法返回 `Result[T, DBError]` 而非 `Option[T]`，保留错误传播
    - MoonBit struct 字段默认 file-private（跨文件/包构造需要 pub fn new() 构造函数）
    - sqlc v2 配置格式: codegen 在 `sql[]` 下，WASM 插件定义在 `plugins[]` 下，URL 支持 `file://` 和 `https://`；sha256 建议填入避免启动时重复计算
    - 字符串字面量转义使用 escape_string(s) 函数（emitter.mbt），转义表：'"'→'\"'、'\n'→'\\n'、'\t'→'\\t'、'\r'→'\\r'、'\\'→'\\\\'、'$'→'\\$'（MoonBit $ 标识符前缀需转义）
- Transaction struct: 与 DB 相同的 concrete struct + closure 模式，额外包含 commit_fn/rollback_fn。DB::begin() → Result[Transaction, DBError]
- Row 类型化 getter 不可空变体返回 `Result[T, DBError]`，可空变体返回 `Result[Option[T], DBError]`，空字符串约定为 NULL 值
    - Row::get_time 变精度小数容错：<6 位右补零、>6 位截断、无小数→0
    - build_body ExecResult 分支：result_shape(Rows) 优先于 raw_cmd，有列时走 decode 路径而非 conn.exec()
    - build_body ExecResult 分支：按 raw_cmd 分发方法名 — CopyFrom→.copyfrom(), Batch→.batch(), ExecLastId→.execlastid(), Exec→.exec()
    - Transaction 重载生成规则：`supports_transaction()` 判定 One/Many/Exec/ExecRows 生成 tx 重载，CopyFrom/Batch/ExecLastId 跳过（Transaction 不支持）
    - 生成代码以 import "Mairzzcllo/moonbit_sqlc_plugin/runtime" 开头，位于 package 声明之后
- Row get_bytes 使用 `Array::make(n, (0).to_byte())` + for 循环逐字节构建 `Array[Byte]`，不使用 `String::to_bytes()`（返回 `Bytes` 类型而非 `Array[Byte]`）
- MockDB in `runtime/mock.mbt`: `MockDB` struct (预设 exec/execrows/query/query_row 的 Result)，`MockDB::build()` → `DB`。Call tracking 通过 `let mut` 闭包在测试侧手动实现
- Row get_json 使用 `@json.parse(raw[:])` + try/catch 解析 JSON 字符串
- runtime/moon.pkg 导入 `moonbitlang/core/json` @json 和 `moonbitlang/core/string` @string
- 验证脚本: `tests/integration/wasm/validate_plugin.ps1` 用于检查 WASM 构建产物和 sqlc 集成
    - 测试中 deprecated `inspect(value, content=...)` 迁移为 `debug_inspect(value, content=...)`（独立函数，prelude 内置，无需 import）
    - MoonBit String 内部存储为 UTF-16LE，`s.to_bytes()` 返回 UTF-16LE 字节；字符串操作应使用 Char/StringView 方法而非字节操作
    - `capitalize_first`: `let upper = (c.to_int() - 32).unsafe_to_char(); [upper] + s[1:].to_owned()`

## 决策索引

- ADR-001 — AST-based Code Generation Strategy
- ADR-002 — Runtime Scope（已接受 v3）
- ADR-003 — Nullable Strategy（待定）
- ADR-004 — Naming Convention（待定）
- ADR-005 — Type Mapping Policy（待定）
- ADR-006 — AST Stability Policy（待定）
- ADR-007 — WAT Shim ABI Bridge（已接受，由 ADR-008 取代）
- ADR-008 — Native WASI I/O via Inline WAT FFI（已接受）
- ADR-009 — Known Limitations and MVP Boundaries（草稿）
- ADR-010 — Transaction Support: Concrete Struct + Closure Pattern（已接受）
- ADR-011 — Codegen Build Body: result_shape Priority and Method Dispatch（已接受）
- ADR-012 — Phase D Architecture Gaps: ExecResult, Type Overrides, TimeTZ（已接受）
- ADR-013 — 100 Edge Cases Analysis: Classification and Fix Feasibility（已接受）

## 已知限制

### sqlc WASM 集成状态

sqlc v1.31.1 使用 wazero 作为 WASM 运行时。**实测确认 wazero 可加载含 refany GC 类型注解的 WASM 二进制**（270KB, 269 个 refany 类型）— 错误 `proto: cannot parse invalid wire-format data` 的根源是**帧头协议不匹配**，非 GC 类型拒绝。

MoonBit `--target wasm` 输出始终包含 GC 类型注解（refany），WAT 输出包含 refany 类型签名（非标准 WASM MVP），但 wazero 可以正常加载和执行。

### sqlc WASM 插件协议

sqlc WASM 插件的 I/O 协议是**无帧格式的原始 stdin/stdout protobuf**（参考 sqlc-gen-greeter）:
- stdin: 读取原始 protobuf `GenerateRequest` 字节
- stdout: 写入原始 protobuf `GenerateResponse` 字节
- 无 4 字节 LE 帧头前缀

当前 MoonBit I/O 层已修复（P0-045）：使用 `read_all` + `write_all` 无帧格式原始 protobuf。

### Phase D — 架构差距 (2026-05-29 评审) + 100 边界情况 (2026-05-30)

9 个已知 GAP vs 成熟生态插件:
- GAP-1: 单文件输出 → P0-060
- GAP-2: :execresult 缺失 LastInsertId → P0-056 ✅ done
- GAP-3: 类型覆盖简陋 → P0-058
- GAP-4: 插件选项极少 → P0-057
- GAP-5: 仅 PostgreSQL → P1-035
- GAP-6: 无 trait/interface → P1-038 (Blocked by MoonBit)
- GAP-7: TIMETZ 时区丢失 → P0-059
- GAP-8: 根 sqlc.yaml 空模板 → P1-036
- GAP-9: 缺 E2E 集成测试 → P1-037

100 边界情况分析 (2026-05-30): 100 edge cases → 50 新任务 (7 P0 + 10 P1)
- P0-061: Codec bounds hardening (skip_field/OOB/error→abort)
- P0-062: :one TooManyRows error (多行静默取第一条)
- P0-063: 字段解码按列名而非索引 (列顺序变化错位)
- P0-064: 输出路径穿越防护 (out_name 验证)
- P0-065: MoonBit 关键字冲突 (完整转义表)
- P0-066: 空/无效标识符处理 (空查询名/列名)
- P0-067: iovec 保留内存区间隔离验证
- P1-039: Codec 静默错误传播 (read_string/decode_embedded)
- P1-040: 类型格式验证 (Date/DateTime/UUID/IP)
- P1-041: 命名转换边缘情况加固
- P1-042: MockDB 可用性改进
- P1-043: Test 覆盖扩展 (多表/数组/枚举)
- P1-044: DBError 增强 (嵌套错误 + TooManyRows)
- P1-045: 代码生成去重与空包名保护
- P1-046: Row 运行时加固 (越界/类型混淆/挂起)
- P1-047: 枚举运行时值验证
- P1-048: 集成测试基础设施加固

## 代码库勘误（2026-05-22 深度评审记录）

### 规划陷阱清单 — 避免重复犯错

1. **`:execresult` 已实现** — `ir.mbt` 中 `ExecResult` 对应 `:exec`，`ExecCount` 对应 `:execrows`，均有完整 codegen。不要重复实现
2. **PostgreSQL enum 已支持** — `generate_enum_from_enum()` 在 `type_codegen.mbt:74` 完整实现，golden 输出包含 `UserRole` 枚举
3. **Engine 字段位置** — `AdaptSettings.engine`（`adapter.mbt:117`），非 `AdaptCatalog`
4. **`package_name` key 一致** — 解析器和配置都用 `package_name=`，不存在 mismatch
5. **MoonBit 无可空指针** — `nullable_style: "pointer"` 不可行，`Option[T]` 唯一可空表示（ADR-003）
6. **`emit_empty_slices` 非 easy win** — 与 ADR-003 冲突，推迟至 Phase 2
7. **`type_to_value_constructor()` 完整** — `query_codegen.mbt:33` 已有全部映射（Int64/String/Double/Bool/Bytes/Date/DateTime/JsonValue），无需修改
8. **`param_to_value_expr()` nullable 正确** — `Some(x) => Ctor(x)` 模式类型推导自动匹配，无需修改
9. **`parse_plugin_options` slice indices 必须手工验证** — `adapter.mbt` 中 `s[14:]` 应为 `s[13:]`（`"package_name="` 为 13 字符）。硬编码前缀长度与 `has_prefix` 常量字符串长度需一致，不可凭印象写值
10. **GAP-2 ExecResult 是增强，非重复实现** — `ir.mbt` 已有 `ExecResult` IR 变体，P0-056 是在此基础上增加 LastInsertId + RowsAffected 结构体返回值，不是重新实现
11. **GAP-3 类型覆盖 vs P2-002** — P2-002 已实现 `override_<type>=<moonbit_type>` 格式，但缺乏 column 级和 nullable 级覆盖维度。P0-058 是扩展而非重写
12. **GAP-4 emit_empty_slices 不再推迟** — 先前标记「推迟至 Phase 2」，现纳入 P0-057 立即实现
13. **GAP-7 TimeTZ 新 struct** — 不修改现有 Time struct，新增独立 `TimeTZ { hour, min, sec, micros, tz_offset: Int }` 保持向后兼容

### 任务分解约定

- Sprint 任务使用 `S-` 前缀（如 `S-001`），优先级映射 P0/P1/P2
- 并行性分析: `S-xxx ↔ S-yyy` 表示无依赖可并行；`S-xxx → S-yyy` 表示硬依赖
- 每个任务 yaml 包含 `execution_notes` 字段记录实现注意事项
- Golden 更新是每个 codegen 变更的验收标准，非留到最后统一处理

## 远程仓库

- URL: https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
- 默认分支: main
- 推送方式: GitHub PAT (classic, repo scope)
