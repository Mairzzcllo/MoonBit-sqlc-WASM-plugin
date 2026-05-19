# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: P0-035 完成。P0 第二阶段（bug 修复）推进：type_map 类型映射完善 + IR 层数组/RETURNING* 支持完成。架构迁移：WAT shim → 原生 WASI I/O
- **当前任务**: P0-036（依赖 P0-034 + P0-035，均已就绪）
- **最新事件**: 2026-05-19 — P0-034 Type Mapping 类型映射完善完成。修复 6 个缺陷（#5 serial/bigserial/smallserial, #6 pg_catalog.* schema 前缀, #7 空格类型名, #27 interval 注释, #32 大小写, numeric 精度注释）。P0-035 IR 层数组与 RETURNING* 支持完成。修复 2 个缺陷（#11 is_array 丢失, #21 RETURNING * 行数据丢失）。新增 23 个测试。moon check 0 errors，moon test 233/233 通过。
- P0: 35/39 completed（紧急修复阶段：3/7）
- P1: 0/2 completed
- P2: 0/1 completed
