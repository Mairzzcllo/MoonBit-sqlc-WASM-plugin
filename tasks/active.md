# Active Tasks — UI Projection

> 生成时间: 2026-05-19 (updated)
> 项目: MoonBit sqlc WASM Plugin
> 运行时状态来源: `runtime/tasks/active/{id}.yaml`

## P0 — 紧急修复

### [P0-036] Codegen 核心修复
- 优先级: P0
- 类型: fix
- 状态: 待办
- 描述: 修复 query_codegen.mbt / type_codegen.mbt / emitter.mbt 中 4 个 CRITICAL 缺陷：:one/:many 改用 db.query() 并解码行数据（不再返回 None/[]）；生成 decode(Row) 方法；字符串字面量转义（双引号、换行符）；清理 build_body 未使用的 result_type 参数
- 依赖: P0-034（已完成），P0-035（已完成）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-18
- 关联: #1 #2 #3 #22

### [P0-037] 输出配置与导入声明
- 优先级: P0
- 类型: fix
- 状态: 待办
- 描述: 修复 main.mbt + moon.pkg 中 3 个缺陷：使用 codegen.out 作为输出文件名；传递 codegen.options 中的包名等配置；添加 runtime 包依赖确保编译期类型兼容性验证
- 依赖: P0-036（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-18
- 关联: #23 #24 #25

### [P0-038] WASM I/O 清理
- 优先级: P0
- 类型: refactor
- 状态: 待办
- 描述: 清理 wasi_io.mbt 中 5 个缺陷：验证 run_io_loop()/main 入口点（ADR-008 后应可达）；字节拷贝 O(n²)→批量拷贝；清理未使用 SCRATCH 常量；fd_read/fd_write 错误处理；消除冗余内存分配
- 依赖: -
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-18
- 关联: #13 #14 #29 #30 #31

### [P0-039] 文档与测试补全
- 优先级: P0
- 类型: docs
- 状态: 待办
- 描述: 修复 4 个文档/测试缺陷：更新 protocol.mbt 注释匹配 ADR-008 架构；清理 WRITE_FRAME_DEBUG stderr 输出；补充真实 sqlc 输入测试（bigserial、数组列、schema 限定名）；创建 ADR 记录已知类型映射限制
- 依赖: P0-033（hard），P0-034（hard），P0-035（hard），P0-036（hard），P0-037（hard），P0-038（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-18
- 关联: #20 #26 #28 #34

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
