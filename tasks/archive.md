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
