# Archived Tasks

> 归档时间: 2026-05-26
> 项目: MoonBit sqlc WASM Plugin
> 来源: `runtime/tasks/archive/{id}.yaml`

### [P0-048] 事务集成 — 生成函数支持 Transaction
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: build_body 参数化 conn_name；generate_query_fn 接受 conn_name+conn_ty；generate_query_fns 为每个查询生成两个重载（db: DB 和 tx: Transaction）。GOLDEN_USERS 更新。
- 架构: moon check 0 errors, moon test 326/326 passed
- 创建: 2026-05-25
- 完成: 2026-05-25

### [P0-047] :exec/:execrows + RETURNING * 语义修复
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: build_return_ty 和 build_body 检查 query.result_shape。ExecResult+Rows→Result[T,DBError]+db.query_row+decode；ExecCount+Rows→Result[Array[T],DBError]+db.query+collect。无结果行时保持 Int64 原行为。
- 架构: moon check 0 errors, moon test 326/326 passed
- 创建: 2026-05-25
- 完成: 2026-05-25

### [P0-046] 查询注解补全 — :copyfrom / :batch / :execlastid
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 全链路支持三个新注解：adapter(QueryCmd 变体)→IR(cmd_to_cardinality+raw_cmd)→codegen(build_body 分发)→runtime(新增 3 DB 方法)→mock(同步扩展)
- 架构: moon check 0 errors, moon test 326/326 passed
- 创建: 2026-05-25
- 完成: 2026-05-25

### [P1-021] 修复验证脚本假阴性
- 优先级: P1
- 类型: bugfix
- 状态: 完成
- 描述: validate_plugin.ps1 wasm2wat 多行输出 + stderr 污染导致 -notmatch 假阴性。改用 2>$null 过滤 stderr + -join 合并单字符串后做否定匹配。16 warnings → 1 (pre-existing)。
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P1-020] 清理编译警告
- 优先级: P1
- 类型: refactor
- 状态: 完成
- 描述: (1)移除 plugin/moon.pkg 未用 runtime import (2)Value 枚举移除未用 Date/DateTime 变体 (3)tests stubs 清理 unused self/Null/String/Editor/Viewer/Transaction/begin_fn/UserRole。16 warnings → 1 (pre-existing)。
- 架构: moon check 0 errors, moon test 296/296 passed
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P1-019] 修复输出文件名 + examples 集成
- 优先级: P1
- 类型: bugfix
- 状态: 完成
- 描述: (1) process_request 将 codegen.out 作为目录前缀 + "lib.mbt"（处理尾随斜杠），空值时默认 "lib.mbt" (2) examples/users 配置正确（moon.pkg 含 runtime 依赖, sqlc.yaml out: "."），生成代码落地到包内。
- 架构: moon check 0 errors, moon test 296/296 passed
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P1-016] 类型映射修复: date/timestamp → Date/DateTime
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: PostgreSQL date→Date, timestamp/timestamptz→DateTime (runtime 封装类型)。加回 Date/DateTime Value 变体；type_map.mbt 更新 date/timestamp 映射；golden test 更新 realistic 测试。
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P1-015] 类型映射修复: numeric → String
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: numeric/decimal 从 Double 改为 String，保留完整精度。type_to_value_constructor 同步更新 numeric→String。所有测试期望更新。
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P1-014] 类型映射修复: int2/int4 → Int
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: int2/int4/serial→Int (平台字宽), int8/bigint→Int64 (保留)。type_map.mbt 拆分整数映射；type_codegen.mbt 新增 "Int"→"int64" getter 后缀；所有测试期望 + golden 更新。
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P1-013] 迁移 main 包黑盒测试到 inline test
- 优先级: P1
- 类型: refactor
- 状态: 完成
- 描述: 重命名 golden_test.mbt→golden.mbt, wasm_integration_test.mbt→wasm_integration.mbt，消除 "Main package uses blackbox-only test inputs" 警告。
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P1-012] 修复 plugin/moon.pkg runtime 依赖声明
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: 添加 "Mairzzcllo/moonbit_sqlc_plugin/runtime" 到 plugin/moon.pkg，对齐 AGENTS.md 约定。
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P1-011] 清理未使用的 Value 枚举变体
- 优先级: P1
- 类型: refactor
- 状态: 完成
- 描述: 移除 Bool/Double/Bytes/JsonValue 4 个未用变体；Date/DateTime 因 P1-016 需要临时移除后加回。6 个 unused_constructor 警告消除。
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P0-036] Codegen 核心修复 (父任务)
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: 4 个子任务：P0-040(#3 query 路由) → P0-041(#2 decode 方法) → P0-042(#1 行解码) → P0-043(#22 字符串转义)。行解码逻辑修复：:many 使用 `rows.map({|row| Type::decode(row)})`，:one 使用 `if rows.length() > 0 { Some(Type::decode(rows[0])) } else { None }`
- 架构: moon check 0 errors, moon test 238/238 passed
- 创建: 2026-05-18
- 完成: 2026-05-19
- 关联: #1 #2 #3 #22

### [P0-040] Query 路由修复 (P0-036a)
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: #3 — OneRow/ManyRows 的路由不应通过 db.exec() 丢弃
- 架构: moon check 0 errors, moon test 228/228 passed
- 创建: 2026-05-18
- 完成: 2026-05-19

### [P0-041] 生成 decode(Row) 方法
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: CRITICAL #2 — 为每个生成的 Row struct 添加 decode(row: Row) -> Self 方法。StructName::decode 语法，@string.parse_* + try/catch，238 测试通过
- 依赖: P0-040(hard, ✅)
- 架构: moon check 0 errors, moon test 238/238 passed
- 创建: 2026-05-19
- 完成: 2026-05-19
- 关联: #2

### [P0-042] :one/:many 解码行数据
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: CRITICAL #1 — 改用 db.query(sql) 获取结果，StructName::decode(row) 解码；OneRow 取首条 Option.wrap，ManyRows 遍历全部。AST 新增 If/Index/IntLit/BinOp 变体；emitter 新增对应格式化；build_body 生成行解码表达式
- 依赖: P0-040(hard, ✅) P0-041(hard, ✅)
- 架构: moon check 0 errors, moon test 238/238 passed
- 创建: 2026-05-19
- 完成: 2026-05-19
- 关联: #1

### [P0-044] 分析 WASM GC 类型对 wazero/sqlc 兼容性影响
- 优先级: P0
- 类型: research
- 状态: 完成
- 描述: 用 wasm2wat + sqlc generate 验证根本原因。结论：wazero 成功加载含 269 个 refany 类型注解的 WASM 二进制（270KB）。错误 `proto: cannot parse invalid wire-format data` 来自插件内部 protobuf 解码器，根源是帧头协议不匹配，非 GC 类型拒绝。无需 P0-046。
- 架构: moon check 0 errors, moon test 291/291 passed, sqlc generate exit 1 (预期内)
- 创建: 2026-05-20
- 完成: 2026-05-20

### [P0-043] 字符串转义修复 (P0-036d)
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: #22 — SQL 字符串字面量中的 `$1` 等字符在 MoonBit 中需转义为 `\$1`
- 架构: moon check 0 errors, moon test 228/228 passed
- 创建: 2026-05-18
- 完成: 2026-05-19

### [P0-037] 输出配置与导入声明
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: 修复 3 个缺陷：#23 process_request 使用 codegen.out 作为输出文件名（默认 "lib.mbt"）；#24 新增 PluginOptions + parse_plugin_options 解析 package_name（实验性）；#25 plugin/moon.pkg 添加 runtime 依赖
- 依赖: P0-036（hard）
- 架构: moon check 0 errors, moon test 238/238 passed
- 创建: 2026-05-18
- 完成: 2026-05-19
- 关联: #23 #24 #25

### [P0-038] WASM I/O 清理
- 优先级: P0
- 类型: refactor
- 状态: 完成
- 描述: 清理 wasi_io.mbt 中 5 个缺陷：#13 入口点验证（wasm2wat 确认 _start→__moonbit__main→run_io_loop，添加注释）；#14 O(n²) 字节拷贝不存在（WASI fd_read/fd_write 直接 iovec 传输，添加注释）；#29 SCRATCH 用途文档化注释；#30 read_body fd_read 错误时返回空 Bytes；#31 单次分配已实现（注释说明）
- 架构: moon check 0 errors, moon test 238/238 passed
- 创建: 2026-05-18
- 完成: 2026-05-19
- 关联: #13 #14 #29 #30 #31

### [P0-039] 文档与测试补全
- 优先级: P0
- 类型: docs
- 状态: 完成
- 描述: 修复 4 个文档/测试缺陷：#20 更新 protocol.mbt shim-wrapper→wasi_io.mbt 注释；#26 移除 WRITE_FRAME_DEBUG stderr dump；#28 添加真实 sqlc 输入测试工厂 + golden 测试（bigserial→Int64, pg_catalog.int8→Int64, TEXT[]→Option[Array[String]], timestamptz→String）；#34 创建 ADR-009 已知限制文档
- 架构: moon check 0 errors, moon test 240/240 passed
- 创建: 2026-05-18
- 完成: 2026-05-19
- 关联: #20 #26 #28 #34

### [P0-023] WAT shim: 核心 ABI bridge
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 编写 shim/wasi_shim.wat，包含 bytes_data_ptr/fd_read/fd_write 辅助函数，预留 iovec [1024, 1035] 和 scratch [1036, 65535] 区域
- 架构: moon check 0 errors, moon test 185/185 passed
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-024] MoonBit I/O 层重写: 零 FFI + process_message entry point
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 关键发现：MoonBit `--target wasm` FFI 不支持 Bytes (error 4042) → 架构从「MoonBit 调用 shim」反转为「shim 调用 MoonBit」。MoonBit 移除所有 FFI 声明，暴露 `pub fn process_message(data: Bytes) -> Bytes` 纯计算入口。Shim 在 post-merge 阶段注入 MoonBit 模块，通过直接 WAT 调用访问 MoonBit 内部函数
- 架构: moon check 0 errors, moon test 185/185 passed
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-025] 构建流水线: shim 合并脚本
- 优先级: P0
- 类型: infra
- 状态: 完成
- 描述: 编写 scripts/merge-shim.ps1 实现 5 阶段构建 (moon build → moonc link-core → name resolution → WAT merge → wat2wasm)。修复 PowerShell $ 转义、WAT 导入顺序、if/then 语法、S-expression 折叠。安装 wabt (npm) 提供 wat2wasm。Pipeline 产出 _build/plugin.wasm (438 bytes, stub mode — 受 MoonBit 工具链 dead-code elimination 限制)
- 架构: moon check 0 errors, moon test 185/185 passed. Pipeline 验证通过: wat2wasm -> plugin.wasm 438 bytes
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-001] 项目脚手架搭建
- 优先级: P0
- 类型: infra
- 状态: 完成
- 描述: 搭建 monorepo 结构、MoonBit 构建配置、基础目录结构（plugin/、runtime/、examples/、tests/）
- 架构: 验证通过 — moon check 0 errors, moon build --target wasm 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-002] sqlc WASM 插件协议实现（umbrella）
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 实现 sqlc 的 WASM 插件接口规范。拆分为 5 个子任务（P0-018 类型定义 → P0-019 protobuf 编解码 → P0-020 WASI framing → P0-021 入口集成 → P0-022 单元测试），全部按顺序完成。
- 依赖: P0-001（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 61/61 passed (13 adapter + 48 existing), moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-004] Internal IR Definition
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 定义插件核心内部中间表示（IR），作为 protobuf 与 MoonBit AST 之间的 semantic boundary。包含 QueryCardinality、InternalType、InternalField、InternalParameter、InternalResultShape（Rows/None）和 InternalQuery。提供 build_ir() 转换器从 AdaptRequest 构建 IR。所有类型独立于 protobuf schema 和 MoonBit 语法。
- 依赖: P0-003（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 73/73 passed, moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-005] MoonBit AST Definition
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 定义 MoonBit 抽象语法树类型（SourceFile、TopLevel、StructDef、EnumDef、FnDef、FieldDef、VariantDef、ParamDef、TypeExpr、Expr、TypeAliasDef、ImportDef）。纯 MoonBit 语言结构，无 sqlc/IR/database 语义。AST 层独立于 protobuf schema 和 MoonBit 语法。
- 依赖: P0-001（hard），P0-004（soft）
- 架构: 验证通过 — moon check 0 errors, moon test 89/89 passed (16 new AST tests), moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-006] Pretty Printer / Emitter
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 将 MoonBit AST 输出为格式正确的 MoonBit 源代码。Emitter 结构体 + emit_ 系列函数，处理 import/struct/enum/fn/type_alias 的格式化、缩进、doc comment、type expr、expression（Call/Let/Lambda/Block/Ident/StrLit/Unit）。纯机械 AST → source 转换，无 sqlc/IR 语义。
- 依赖: P0-005（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 113/113 passed (24 new emitter tests), moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-007] Type Mapping Layer
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: PostgreSQL 类型映射表：int2/int4→Int, int8→Int64, float4→Float, float8/numeric→Double, bool→Bool, text/varchar→String, bytea→Bytes, json/jsonb→JsonValue, uuid/inet/timestamptz→String（MVP fallback）。map_internal_type() 处理 Named + Arr，map_internal_type_nullable() 处理 Option[T] 包装。27 种 PG 类型 + 别名覆盖。
- 依赖: P0-003（hard），P0-016（soft），P0-014（soft）
- 架构: 验证通过 — moon check 0 errors, moon test 140/140 passed (27 new type_map tests), moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-008] Type Code Generator
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 从 Internal IR 和 catalog 生成 MoonBit struct/enum 类型定义的 AST 节点。snake_to_pascal 命名转换（users→Users）。generate_struct_from_fields/table/enum、generate_types_from_catalog/queries、generate_types（组合）。map_internal_type_nullable 集成 Optional 策略。
- 依赖: P0-003（hard），P0-004（hard），P0-005（hard），P0-007（hard），P0-014（soft），P0-015（soft）
- 架构: 验证通过 — moon check 0 errors, moon test 160/160 passed (20 new type_codegen tests), moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-009] Query Code Generator
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 从 Internal IR 生成 CRUD 查询函数的 MoonBit AST 节点。generate_query_fn/query_fns 处理 OneRow→Option[T]、ManyRows→Array[T]、ExecResult→Int、ExecCount→Int64。函数签名含 db: DB 首参 + 类型映射参数。body 含 `let sql = "..."` + db.exec/execrows 调用。query_ 前缀命名。
- 依赖: P0-003（hard），P0-004（hard），P0-005（hard），P0-008（hard），P0-015（soft）
- 架构: 验证通过 — moon check 0 errors, moon test 178/178 passed, moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-010] Minimal Runtime Abstraction Layer
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 最简运行时抽象。DB struct（exec/execrows 闭包注入）、Row struct（get 闭包注入）。使用 concrete struct + closure 模式绕过 MoonBit 0.1 的 trait 对象/泛型方法限制。生成的查询函数使用 db.exec(sql)/db.execrows(sql)。不含 transaction/prepared statement/connection lifecycle。
- 依赖: P0-001（hard），P0-013（soft）
- 架构: 验证通过 — moon check 0 errors, moon test 178/178 passed, moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-011] Golden Tests
- 优先级: P0
- 类型: test
- 状态: 完成
- 描述: 确定性输出验证测试套件。输入固定 sqlc CodeGenRequest 数据（users 表 + user_role 枚举 + 3 个 queries），验证全管道输出与 golden string 一致。Snapshot policy 验证：doc comments 保留、enum PascalCase、type mapping、query function 签名。make_users_request() 工厂函数 + 2 个 golden inline tests。
- 依赖: P0-006（hard），P0-008（hard），P0-009（hard），P0-017（soft）
- 架构: 验证通过 — moon check 0 errors, moon test 180/180 passed (2 new golden tests), moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-012] Integration Compilation Tests
- 优先级: P0
- 类型: test
- 状态: 完成
- 描述: 验证生成 MoonBit 代码可被 moonc 成功编译。tests/integration/basic/generated.mbt 包含完整管道输出（Users struct、UserRole enum、ListUsersRow/GetUserRow row types、3 query functions）。Basic package 添加 5 个 compilation tests（构造 Users struct、调用 query 函数、访问 enum variant）。代码生成修正：OneRow/ManyRows body 使用 `let _ = db.exec(sql)` + `None`/`[]` 返回。
- 依赖: P0-006（hard），P0-008（hard），P0-009（hard），P0-010（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 185/185 passed (5 new compilation tests), moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-013] ADR: Runtime Scope
- 优先级: P0
- 类型: research
- 状态: 完成
- 描述: 决策记录 adr/ADR-002.md。Runtime 采用 concrete struct + closure 模式（DB { exec_fn, execrows_fn }, Row { get_fn }），而非 trait。明确 MVP 排除 transaction/prepared statement/connection lifecycle。Decoder 采用约定式静态方法而非 trait 强制。
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-014] ADR: Nullable Strategy
- 优先级: P0
- 类型: research
- 状态: 完成
- 描述: 决策记录 adr/ADR-003.md。使用 `Option[T]` 作为唯一可空性表示方式。`map_internal_type_nullable()` 函数处理 not_null=true 原类型 / not_null=false → Option[T]。
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-015] ADR: Naming Convention
- 优先级: P0
- 类型: research
- 状态: 完成
- 描述: 决策记录 adr/ADR-004.md。snake_case → PascalCase（类型），`query_` 前缀（函数），`<QueryName>Row`（结果行）。`snake_to_pascal()` 算法实现，`db: DB` 首参约定。
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-016] ADR: Type Mapping Policy
- 优先级: P0
- 类型: research
- 状态: 完成
- 描述: 决策记录 adr/ADR-005.md。27 种 PG 类型 → MoonBit 类型映射表（int4→Int, text→String, jsonb→JsonValue 等）。数组通过 Arr 递归映射，未知类型安全 fallback 为 String。
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-017] ADR: AST Stability Policy
- 优先级: P0
- 类型: research
- 状态: 完成
- 描述: 决策记录 adr/ADR-006.md。Emitter 纯函数式 AST→String，确定性保证（schema 声明序、LF 换行、2-space 缩进、item 间空行分隔）。Golden Tests 的 snapshot policy 基础。
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-018] P0-002a — types.mbt: sqlc 协议类型定义
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 定义 sqlc WASM 插件协议的所有 MoonBit 类型（GenerateRequest、GenerateResponse、Catalog、Schema、Table、Column、Query 等）
- 依赖: P0-001（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 7/7 passed
- 创建: 2026-05-15
- 完成: 2026-05-15

### [P0-019] P0-002b — codec.mbt: 手动 protobuf 编解码
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: plugin/codec.mbt — 手动 protobuf 编解码器（varint LEB128、length-delimited、嵌入消息）。decode_request → GenerateRequest、encode_response → GenerateResponse。使用 @encoding/utf8 处理 UTF-8 字符串
- 依赖: P0-018（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 19/19 passed
- 创建: 2026-05-15
- 完成: 2026-05-15

### [P0-020] P0-002c — protocol.mbt: 4-byte LE framing + WASI 读写
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: plugin/protocol.mbt — stdio 传输层：4-byte LE 长度前缀帧 + WASI fd_read/fd_write FFI。read_message()/write_message() 纯 MoonBit 帧层 + 5 个边界测试
- 依赖: P0-018（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 24/24 passed
- 创建: 2026-05-15
- 完成: 2026-05-15

### [P0-021] P0-002d — main.mbt: 入口集成 + 协议循环
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: plugin/main.mbt — 完整协议循环 read_message→decode_request→process_request(empty stub)→encode_response→write_message + stderr 日志
- 依赖: P0-019（hard），P0-020（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 24/24 passed
- 创建: 2026-05-15
- 完成: 2026-05-15

### [P0-022] P0-002e — 单元测试全覆盖
- 优先级: P0
- 类型: test
- 状态: 完成
- 描述: 为 P0-002 补充 25 个测试：codec roundtrip 全覆盖（Settings/Catalog/Schema/Query/Table/Enum/CompositeType/Parameter），protocol 帧边界（零长度/大值/字节模式），varint 多字节，string/bytes 空值，skip_field
- 依赖: P0-019（hard），P0-020（hard），P0-021（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 49/49 passed
- 创建: 2026-05-15
- 完成: 2026-05-15

### [P0-003] Protobuf Adapter Layer
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 解析 sqlc CodeGenRequest protobuf metadata，转换为插件内部模型（catalog、schema、queries 等）。定义 11 个 Adapted 类型（AdaptRequest/AdaptCatalog/AdaptSchema/AdaptTable/AdaptColumn/AdaptEnum/AdaptQuery/AdaptParameter/AdaptIdentifier/AdaptSettings）和 QueryCmd 枚举，提供 convert_request() 转换器从 raw GenerateRequest 生成内部模型。wired into main.mbt process_request。
- 依赖: P0-001（hard），P0-002（hard）
- 架构: 验证通过 — moon check 0 errors, moon test 61/61 passed, moon build 0 errors
- 创建: 2026-05-14
- 完成: 2026-05-15

### [P0-026] 集成验证: sqlc generate 端到端
- 优先级: P0
- 类型: test
- 状态: 完成
- 描述: 用 sqlc generate 跑 examples/users/，验证帧协议 + protobuf payload 完整通过
- 架构: moon check 0 errors, moon test 185/185 passed
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-027] wasi_ffi — 内联 WAT FFI 基础层
- 优先级: P0
- 类型: infra
- 状态: 完成
- 描述: 创建 plugin/wasi_io.mbt，实现 bytes_data_ptr，store_i32，load_i32 内联 WAT FFI 和 fd_read/fd_write 模块 FFI
- 架构: moon check 0 errors, moon test 185/185 passed
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-028] wasi_io — I/O 协议循环
- 优先级: P0
- 类型: feature
- 状态: 完成
- 描述: 在 wasi_io.mbt 中实现 read_frame_header，read_body，write_frame，run_io_loop。12 字节 iovec 固定 [1024,1035]，数据缓冲区用 Bytes::new 动态分配
- 架构: moon check 0 errors, moon test 185/185 passed
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-029] main 入口整合 + protocol 注释更新
- 优先级: P0
- 类型: refactor
- 状态: 完成
- 描述: main.mbt 改为 fn main { run_io_loop() }，去掉 process_message 引用 stub。protocol.mbt 去掉 shim 引用注释
- 架构: moon check 0 errors, moon test 185/185 passed
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-030] 清理废弃文件
- 优先级: P0
- 类型: chore
- 状态: 完成
- 描述: shim/wasi_shim.wat → shim/archive/，移除 scripts/merge-shim.ps1，清理 plugin_test.wat 等
- 架构: moon check 0 errors, moon test 185/185 passed
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-031] 验证脚本和文档更新
- 优先级: P0
- 类型: docs
- 状态: 完成
- 描述: validate_plugin.ps1 去掉 shim checks，AGENTS.md 更新构建命令，CONTEXT.md 更新进度，创建 ADR-008
- 架构: moon check 0 errors, moon test 185/185 passed
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-032] 端到端集成验证
- 优先级: P0
- 类型: test
- 状态: 完成
- 描述: moon build --target wasm → sqlc generate 在 test project 中运行通过，WASM binary 结构验证。修复 protocol.mbt:34 process_message 遗留 stub
- 架构: moon check 0 errors, moon test 195/195 passed, moon build --target wasm 0 errors
- 创建: 2026-05-17
- 完成: 2026-05-17

### [P0-034] Type Mapping 类型映射完善
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: 修复 type_map.mbt 中 6 个缺陷：#5 bigserial/serial/smallserial 映射；#6 schema 限定名 (pg_catalog.*) 前缀剥离；#7 完整空格类型名 (timestamp with time zone, double precision)；#27 interval MVP 注释；#32 大小写不敏感匹配；numeric→Double 精度损失注释
- 架构: moon check 0 errors, moon test 226/226 passed (16 new tests)
- 创建: 2026-05-18
- 完成: 2026-05-19

### [P0-035] IR 层数组与 RETURNING* 支持
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: 修复 ir.mbt 中 2 个缺陷：#11 adapt_column_to_field/adapt_parameter_to_ir 添加 is_array 判断使 TEXT[] 不丢失数组信息；#21 build_result_shape 对 ExecResult/ExecCount 有返回列时返回 Rows(fields) 而非 None（RETURNING * 支持）
- 架构: moon check 0 errors, moon test 233/233 passed (7 new tests)
- 创建: 2026-05-18
- 完成: 2026-05-19

### [P1-004] Runtime: Typed Row Getters + Nullable
- 优先级: P1
- 类型: feature
- 状态: 完成
- 描述: Row 新增 16 个类型化 getter（8 不可空 get_int64/get_string/get_bool/get_double/get_bytes/get_date/get_datetime/get_json + 8 可空 get_nullable_*）。不可空 → Result[T, DBError]，可空 → Result[Option[T], DBError]，空字符串约定为 NULL。使用 @string.parse_* 解析数值/bool，@json.parse 解析 JSON，逐字节 Array[Byte] 构建。
- 依赖: P1-003(hard)
- 架构: moon check 0 errors, moon test 269/269 passed
- 创建: 2026-05-19
- 完成: 2026-05-19
- 关联: P1-005

### [P1-003] Runtime: Value + DBError + RowIter + DB 签名
- 优先级: P1
- 类型: feature
- 状态: 完成
- 描述: 创建 runtime/value.mbt（Value 枚举 9 variants + Date/DateTime struct 封装）、runtime/error.mbt（DBError 枚举 4 variants）、runtime/row_iter.mbt（RowIter next/collect）。重写 runtime/db.mbt（4 方法签名使用 Array[Value] params + Result[T, DBError] 返回）。
- 依赖: 无
- 架构: moon check 0 errors, moon test 256/256 passed
- 创建: 2026-05-19
- 完成: 2026-05-19
- 关联: P1-004, P1-005, P1-006

### [P0-033] Codec 编解码安全加固
- 优先级: P0
- 类型: fix
- 状态: 完成
- 描述: 修复 codec.mbt + protocol.mbt 中 9 个缺陷：#4 Varint 编码死循环（5 字节上限 + 掩码保护）、#8 Varint 解码 5 字节上限、#9 read_string/read_bytes 边界检查、#10 decode_embedded 长度验证、#15 skip_field match 重构 + 注释、#16 decode_embedded 位置推进修复（先子解析再推进）、#17 encode_request 空 plugin_options 无条件编码、#18 Column 字段 2 缺口注释、#19 decode_u32_le 边界保护
- 架构: moon check 0 errors, moon test 210/210 passed (15 new boundary tests)
- 创建: 2026-05-18
- 完成: 2026-05-18

### [P1-024] 修复 time/timetz 映射不一致
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: type_to_value_constructor (query_codegen.mbt:46) 中 time/timetz 从 "DateTime" 改为 "String"，与 map_pg_name 一致。
- 架构: moon check 0 errors, moon test 331/331 passed
- 创建: 2026-05-25
- 完成: 2026-05-26

### [P1-022] Runtime wrapper 类型定义 — Decimal/Uuid/Duration/Time/IpAddr
- 优先级: P1
- 类型: feature
- 状态: 完成
- 描述: 新增 5 个 wrapper struct（Decimal/Uuid/Duration/Time/IpAddr）+ 5 个 Value 枚举变体 + 5 个内联测试。
- 架构: moon check 0 errors, moon test 331/331 passed
- 创建: 2026-05-25
- 完成: 2026-05-26

### [P1-025] 数组解码增强
- 优先级: P1
- 类型: feature
- 状态: 完成
- 描述: get_array stub 替换为 decode_array_string/int64 类型化解码（基于 @json.parse）。field_getter_call 对 Array[T] 生成 decode_array_<suffix>，对 Option[Array[T]] 先判空再解码。
- 架构: moon check 0 errors, moon test 331/331 passed
- 创建: 2026-05-25
- 完成: 2026-05-26

### [P1-023] Row getter / Value 扩展 + 映射更新
- 优先级: P1
- 类型: feature
- 状态: 完成
- 描述: 新增 5 对 typed getter（Decimal/Uuid/Duration/Time/IpAddr）；type_map.mbt numeric→Decimal, uuid→Uuid, interval→Duration, time→Time, inet→IpAddr；type_codegen.mbt type_to_getter_suffix 新增 5 个分支；golden 测试同步更新。依赖 P1-022(hard)。
- 架构: moon check 0 errors, moon test 331/331 passed
- 创建: 2026-05-25
- 完成: 2026-05-26

### [P1-026] RETURNING * codegen 检测 result_shape
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: build_return_ty 和 build_body 新增 result_shape 参数。ExecResult+Rows(fields) → decode 路径；ExecCount+Rows(fields) → 多行 decode。Rows 优先于 raw_cmd。
- 架构: moon check 0 errors, moon test 347/347 passed
- 创建: 2026-05-26
- 完成: 2026-05-26

### [P1-027] sqlc.yaml "package:" 键与 parse_plugin_options 不匹配
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: parse_plugin_options 同时匹配 package= (8 字符前缀) 和 package_name= (13 字符前缀)。examples/users/sqlc.yaml 统一为 package_name: 格式。
- 架构: moon check 0 errors, moon test 331/331 passed
- 创建: 2026-05-26
- 完成: 2026-05-26

### [P1-028] 生成代码缺少 import runtime 语句
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: generate_source 在 AST items 首位置插入 Import node 生成 import "Mairzzcllo/moonbit_sqlc_plugin/runtime" 语句，位于 package 声明之后。
- 架构: moon check 0 errors, moon test 331/331 passed
- 创建: 2026-05-26
- 完成: 2026-05-26

### [P1-029] copyfrom/batch/execlastid raw_cmd 分发
- 优先级: P1
- 类型: feature
- 状态: 完成
- 描述: build_body 对 ExecResult+None(result_shape) 根据 query.raw_cmd 分发：CopyFrom→.copyfrom()、Batch→.batch()、ExecLastId→.execlastid()、Exec→.exec()。result_shape(Rows) 始终优先于 raw_cmd。
- 架构: moon check 0 errors, moon test 352/352 passed
- 创建: 2026-05-26
- 完成: 2026-05-26

### [P1-030] Row::get_time 解析格式容错
- 优先级: P1
- 类型: fix
- 状态: 完成
- 描述: 变精度小数容错：<6 位右补零、>6 位截断、无小数→0。覆盖 HH:MM:SS / HH:MM:SS.f / HH:MM:SS.ffffff 等格式。
- 架构: moon check 0 errors, moon test 366/366 passed
- 创建: 2026-05-26
- 完成: 2026-05-26

### [P2-007] Value enum unused warnings 处理
- 优先级: P2
- 类型: fix
- 状态: 完成
- 描述: 5 个 unused_constructor 警告（Decimal/Uuid/Duration/Time/IpAddr）通过 5 个显式构造测试块消除。MoonBit 0.1 不支持 @suppress 在 enum variant 上，故采用构造测试方案。
- 架构: moon check 0 errors, moon test 366/366 passed
- 创建: 2026-05-26
- 完成: 2026-05-26

### [P2-008] Transaction codegen 精确分发
- 优先级: P2
- 类型: refactor
- 状态: 完成
- 描述: supports_transaction(cmd) 辅助函数判定 One/Many/Exec/ExecRows→true, CopyFrom/Batch/ExecLastId→false。generate_query_fns 对不支持的方法仅生成 db: DB 版本，消除不必要的 tx 重载。
- 架构: moon check 0 errors, moon test 366/366 passed
- 创建: 2026-05-26
- 完成: 2026-05-26
