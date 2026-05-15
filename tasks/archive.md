# Archived Tasks

> 归档时间: 2026-05-15
> 项目: MoonBit sqlc WASM Plugin
> 来源: `runtime/tasks/archive/{id}.yaml`

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
