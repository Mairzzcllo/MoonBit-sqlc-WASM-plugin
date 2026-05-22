# CONTEXT.md

## 项目状态

- **项目**: MoonBit sqlc WASM Plugin
- **阶段**: P0+P1 全部完成 ✅ — Sprint S-1 进行中
- **最新事件**: 2026-05-22 — 深度代码评审完成，修正规划错误后实施 S-1（Value enum 补全 + package_name 接通 + Release v0.1.0）
- P0: 45/45 completed ✅
- P1: 21/21 completed ✅
- P2: 0/1 completed (P2-001 MySQL 推迟至 S-1 之后)
- 活跃 Sprint: **S-1** — 4 个子任务

## Sprint S-1 — Value enum + package_name + Release

| ID | 标题 | 优先级 | 状态 |
|----|------|--------|------|
| S-001 | Value enum 补全：新增 6 个变体 | P0 | ✅ done |
| S-002 | package_name 接入 codegen 管道 | P0 | ✅ done |
| S-003 | Golden 测试扩展：全 PG 类型覆盖 | P1 | todo |
| S-004 | Release v0.1.0 初始版本标记 | P1 | todo |

并行性: S-001 ↔ S-002 已并行完成；S-003 依赖 S-001；S-004 依赖 S-001+S-002。

## 关键勘误记录（2026-05-22 代码评审）

1. **`:execresult` IR 已实现** — `ExecResult` 和 `ExecCount` 在 ir.mbt 中对应 `:exec` 和 `:execrows`，此前规划误判为缺失
2. **PostgreSQL enum 已支持** — `generate_enum_from_enum()` 在 type_codegen.mbt 中完整实现，golden 输出包含 `UserRole` enum
3. **Engine 字段在 AdaptSettings 非 AdaptCatalog** — adapter.mbt 定义 `AdaptSettings.engine`，此前规划误标为 `AdaptCatalog`
4. **`package_name` key 无 mismatch** — 解析器期望 `package_name=`，配置也使用 `package_name=`，一致
5. **`nullable_style: pointer` 不可行** — MoonBit 0.1 无指针类型，`Option[T]` 唯一可空表示（ADR-003）
6. **Value enum 9 变体确认** — `JsonValue(Json)` 复用 `@json.Json` 类型；Date/DateTime 复用 runtime 内建 struct
7. **`type_to_value_constructor()` 完整** — 无需修改，已有全部映射
8. **`param_to_value_expr()` nullable 分支正确** — `Some(x) => Ctor(x)` 类型推导正确
9. **`emit_empty_slices` 推迟至 Phase 2** — 与 ADR-003 冲突

## Phase 0 — 解阻塞 ✅ 全部完成

1. **P0-044 ✅** — 分析 WASM GC 类型影响
2. **P0-045 ✅** — 修复 I/O 帧头协议（原始 protobuf 无帧格式）

## Phase 1 — 工程化清理 ✅ 全部完成

3. **P1-011 ⚠️ 重新打开** — 清理未使用的 Value 枚举变体（Date/DateTime 变体仍存在，移至 P1-020 完成）
4. **P1-012 ✅** — 修复 plugin/moon.pkg runtime 依赖声明
5. **P1-013 ✅** — 迁移 main 包黑盒测试到非 main 包
6. **P1-014 ✅** — 类型映射: int2/int4 → Int
7. **P1-015 ✅** — 类型映射: numeric → String
8. **P1-016 ✅** — 类型映射: date/timestamp → Date/DateTime
9. **P1-017 ❌ 已取消** — StringView 理论经验证不成立
10. **P1-018 ✅** — to_snake_case() + $ 转义移除
11. **P1-019 ✅** — 输出文件名修复: codegen.out 作为目录前缀 + "lib.mbt"
12. **P1-020 ✅** — 清理编译警告: 16→1 (pre-existing), 296 tests pass
13. **P1-001 ✅** — 文档与示例: README 同步、quickstart.md、runtime-api.md、examples/README
14. **P1-002 ✅** — GitHub Actions CI/CD: check→test→build→validate + release workflow
15. **P1-021 ✅** — 修复验证脚本假阴性: wasm2wat 2>$null + -join

## Sprint S-1 完成工作 (2026-05-22)

1. **S-001 ✅** — Value enum 补全：新增 Bool/Double/Bytes/Date/DateTime/JsonValue 六个变体，补齐 9 变体完整集合。新增 6 个内联测试。moon test 302/302 pass (原 296)。
2. **S-002 ✅** — package_name 接入 codegen 管道：`generate_source` 接受 `PluginOptions` 参数；`emit_source_file` 新增 `emit_package_declaration()` 前置输出 `"package <name>\n\n"`；GOLDEN_USERS 更新包含 package 声明行；`make_users_request` 设置 `plugin_options: b"package_name=testdb"`。
   - **Bug 修复**: `parse_plugin_options` 中 `s[14:]` 应为 `s[13:]`（`"package_name="` 为 13 字符非 14），导致包名首字符被静默丢弃（`"testdb"` → `"estdb"`）
