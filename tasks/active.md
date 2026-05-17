# Active Tasks — UI Projection

> 生成时间: 2026-05-17
> 项目: MoonBit sqlc WASM Plugin
> 运行时状态来源: `runtime/tasks/active/{id}.yaml`

## P0 — MVP 必经

### [P0-023] WAT shim: 核心 ABI bridge
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 编写 shim/wasi_shim.wat，导出 bytes_data_ptr/fd_read/fd_write，iovec 构造 + rof_len 写入，保留区间 [1024, 1035]
- 依赖: 无
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-17
- 关联: -

### [P0-024] MoonBit I/O 层重写: shim FFI + 正确 iovec
- 优先级: P0
- 类型: feature
- 状态: 待办
- 描述: 修改 protocol.mbt：FFI 导入改为 shim；read_exact/write_raw 使用 bytes_data_ptr + decode_u32_le(rof_len) 正确实现
- 依赖: P0-023（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-17
- 关联: -

### [P0-025] 构建流水线: shim 合并脚本
- 优先级: P0
- 类型: infra
- 状态: 待办
- 描述: 编写 merge-shim 脚本（moon build → wasm-tools merge），产出最终 plugin.wasm
- 依赖: P0-023（hard），P0-024（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-17
- 关联: -

### [P0-026] 集成验证: sqlc generate 端到端
- 优先级: P0
- 类型: test
- 状态: 待办
- 描述: 用 sqlc generate 跑 examples/users/，验证帧协议 + protobuf payload 完整通过
- 依赖: P0-025（hard）
- 锁定: -
- 重试: 0/3
- 创建: 2026-05-17
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
