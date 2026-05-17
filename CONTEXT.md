# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: P0-023~P0-024 完成。P0-025 构建流水线待实施
- **当前任务**: P0-025 (构建流水线: shim 合并脚本)
- **最新事件**: 2026-05-17 — P0-024 验证关键发现：MoonBit `--target wasm` FFI 不支持 Bytes 参数 → 架构从「MoonBit 调用 shim」反转为「shim 调用 MoonBit」。MoonBit 暴露 `process_message(data: Bytes) -> Bytes` 纯计算入口
- P0: 24/24 completed (23-24 新增)
- P1: 0/2 completed
- P2: 0/1 completed
