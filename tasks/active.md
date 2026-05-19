# Active Tasks — UI Projection

> 生成时间: 2026-05-19 (updated)
> 项目: MoonBit sqlc WASM Plugin
> 运行时状态来源: `runtime/tasks/active/{id}.yaml`

## P0 — 紧急修复

### [P0-036] Codegen 核心修复 (父任务)
- 优先级: P0
- 类型: fix
- 状态: 进行中 (2/4 completed: P0-040✅ P0-043✅)
- 描述: 4 个子任务：P0-040(#3, ✅) → P0-041(#2) → P0-042(#1)；P0-043(#22, ✅) 并行
- 依赖: P0-041(hard) P0-042(hard)
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-18
- 关联: #1 #2 #3 #22

### [P0-041] 生成 decode(Row) 方法
- 优先级: P0
- 类型: fix
- 状态: 待办
- 描述: CRITICAL #2 — 为每个生成的 Row struct 添加 decode(row: Row) -> Self 方法，按字段顺序调用 row.get(i)，数组字段用 row.get_array(i)
- 依赖: P0-040(hard, ✅)
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-19
- 关联: #2

### [P0-042] :one/:many 解码行数据
- 优先级: P0
- 类型: fix
- 状态: 待办
- 描述: CRITICAL #1 — 改用 db.query(sql) 获取结果，StructName::decode(row) 解码；OneRow 取首条 Option.wrap，ManyRows 遍历全部
- 依赖: P0-040(hard, ✅) P0-041(hard)
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-19
- 关联: #1

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
