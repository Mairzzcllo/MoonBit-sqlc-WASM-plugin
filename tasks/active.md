# Active Tasks — UI Projection

> 生成时间: 2026-05-15
> 项目: MoonBit sqlc WASM Plugin
> 运行时状态来源: `runtime/tasks/active/{id}.yaml`

## P0 — MVP 必经

### [P0-002] sqlc WASM 插件协议实现
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 实现 sqlc 的 WASM 插件接口规范，包括 CodeGenRequest/Response 的 protobuf 编解码、WASI 入口函数
- 依赖: P0-001（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

### [P0-003] Protobuf Adapter Layer
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 解析 sqlc CodeGenRequest protobuf metadata，转换为插件内部模型（catalog、schema、queries 等）
- 依赖: P0-001（hard），P0-002（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

### [P0-004] Internal IR Definition
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 定义插件核心内部中间表示（IR），作为 protobuf 与 MoonBit AST 之间的 semantic boundary。包含 InternalQuery、InternalType、InternalField、InternalParameter、InternalResultShape、QueryCardinality。确保 IR 独立于 protobuf schema 和 MoonBit 语法。
- 依赖: P0-003（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: ADR-002, ADR-004

### [P0-005] MoonBit AST Definition
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 定义 MoonBit 抽象语法树类型（module、struct、enum、fn、type_alias、import 等节点）。AST 层不应包含任何 sqlc/IR 语义，仅表达 MoonBit 语言结构。与 P0-004 IR 保持严格单向依赖（IR → AST）。
- 依赖: P0-001（hard），P0-004（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: ADR-005

### [P0-006] Pretty Printer / Emitter
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 将 MoonBit AST 输出为格式正确的 MoonBit 源代码，处理缩进、导入排序、格式化等。Emitter 不应包含任何 sqlc/IR 语义逻辑 — 仅做 AST → source code 的机械转换。
- 依赖: P0-005（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: ADR-005

### [P0-007] Type Mapping Layer
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: PostgreSQL 类型（int4/int8/text/timestamptz/bool/numeric/jsonb 等）与 MoonBit 类型（Int/Int64/String/Bool/Float/JsonValue 等）的双向映射表。所有映射决策记录到 ADR-004 和 ADR-002。
- 依赖: P0-003（hard），P0-016（soft），P0-014（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: ADR-002, ADR-004

### [P0-008] Type Code Generator
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 从 Internal IR（InternalType/InternalField）生成 MoonBit struct/enum 类型定义的 AST 节点。处理 nullable 策略（Option[T] vs Nullable[T]）、命名转换（snake_case table → PascalCase type）。
- 依赖: P0-003（hard），P0-004（hard），P0-005（hard），P0-014（soft），P0-015（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: ADR-002, ADR-003

### [P0-009] Query Code Generator
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 从 Internal IR（InternalQuery/InternalParameter/InternalResultShape/QueryCardinality）生成 CRUD 查询函数的 MoonBit AST 节点。包含 Query Metadata Normalization（:one/:many/:exec/:execrows → QueryReturnKind 枚举）。函数命名遵循 ADR-003。
- 依赖: P0-003（hard），P0-004（hard），P0-005（hard），P0-008（hard），P0-015（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: ADR-003

### [P0-010] Minimal Runtime Abstraction Layer
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 提供最简运行时抽象，仅定义三个 trait：DB（query 执行入口）、Row（结果行抽象）、Decoder（类型解码器接口）。不含 transaction、prepared statement、connection lifecycle。生成代码依赖此层编译，但不包含真实数据库驱动。
- 依赖: P0-001（hard），P0-013（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: ADR-001

### [P0-011] Golden Tests
- 优先级: P0
- 类型: test
- 状态: 待办
- 描述: 确定性输出验证测试套件。输入固定 sqlc CodeGenRequest 数据，验证输出 MoonBit 代码与 golden file 一致。Golden output 必须满足 Snapshot Policy：stable import ordering（字母序）、stable field ordering（schema 声明序）、stable formatting（Emitter 保证）、stable newline（LF）。
- 依赖: P0-006（hard），P0-008（hard），P0-009（hard），P0-017（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: ADR-005

### [P0-012] Integration Compilation Tests
- 优先级: P0
- 类型: test
- 状态: 待办
- 描述: 验证生成的 MoonBit 代码可被 moonc（MoonBit 编译器）成功编译，无类型错误。
- 依赖: P0-006（hard），P0-008（hard），P0-009（hard），P0-010（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

### [P0-013] ADR: Runtime Scope
- 优先级: P0
- 类型: research
- 状态: 待办
- 描述: 决策记录 — 定义 Runtime 职责边界，明确 MVP 仅含 DB/Row/Decoder 三个 trait。写入 adr/ADR-002。
- 依赖: P0-001（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

### [P0-014] ADR: Nullable Strategy
- 优先级: P0
- 类型: research
- 状态: 待办
- 描述: 决策记录 — 可空列/参数在生成代码中的表示方式（Option[T] / Nullable[T] / 按上下文选择）。写入 adr/ADR-003。
- 依赖: P0-003（soft），P0-004（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

### [P0-015] ADR: Naming Convention
- 优先级: P0
- 类型: research
- 状态: 待办
- 描述: 决策记录 — 生成代码的命名规范（table→type、column→field、query 函数命名模板）。写入 adr/ADR-004。
- 依赖: -
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

### [P0-016] ADR: Type Mapping Policy
- 优先级: P0
- 类型: research
- 状态: 待办
- 描述: 决策记录 — PG type ↔ MoonBit type 映射策略（基础映射、复合类型、自定义扩展、unknown fallback）。写入 adr/ADR-005。
- 依赖: P0-003（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

### [P0-017] ADR: AST Stability Policy
- 优先级: P0
- 类型: research
- 状态: 待办
- 描述: 决策记录 — AST → source code 确定性保证（import/field 排序、doc comment 格式、空白行策略）。写入 adr/ADR-006。
- 依赖: P0-004（soft），P0-005（soft）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

## P1 — 迭代

### [P1-001] 文档与示例
- 优先级: P1
- 类型: docs
- 状态: 待办
- 描述: 项目 README、使用示例、API 文档、快速开始指南
- 依赖: P0-002（hard），P0-010（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

### [P1-002] GitHub Actions CI/CD
- 优先级: P1
- 类型: infra
- 状态: 待办
- 描述: 配置 GitHub Actions 流水线：lint → test → build → release
- 依赖: P0-001（hard），P0-011（hard），P0-012（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -

## P2 — 后续

### [P2-001] MySQL 数据库支持
- 优先级: P2
- 类型: feature
- 状态: 待办
- 描述: 扩展 Type Mapping Layer 支持 MySQL 类型，验证 MySQL 查询生成
- 依赖: P0-007（hard），P0-008（hard），P0-009（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-14
- 关联: -
