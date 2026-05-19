# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: P0 bug 修复中（P0-040 + P0-043 已完成）。P0-036 拆分为 4 子任务：P0-040(#3 query 路由)✅, P0-041(#2 decode 方法)待办, P0-042(#1 行解码)待办, P0-043(#22 字符串转义)✅
- **当前任务**: P0-041（依赖 P0-040 ✅，可开始）
- **最新事件**: 2026-05-19 — P0-040 Query 路由修复完成：runtime/db.mbt 新增 query_fn 字段和 DB::query() 方法；query_codegen.mbt 中 OneRow/ManyRows→db.query(sql), ExecResult→db.exec(sql), ExecCount→db.execrows(sql)。P0-043 字符串转义完成：emitter.mbt 新增 escape_string()，转义 " \\n \\t \\r \\\\ $；StrLit/expr_to_string 两处应用。测试新增 5 个，总数 238。moon check 0 errors，moon test 238/238 通过。
- P0: 37/39 completed（P0-036 父任务进行中，剩余 P0-041/P0-042/P0-037/P0-038/P0-039）
- P1: 0/2 completed
- P2: 0/1 completed
