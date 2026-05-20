# Active Tasks — UI Projection

> 生成时间: 2026-05-20
> 项目: MoonBit sqlc WASM Plugin
> 运行时状态来源: `tasks/tasks/active/{id}.yaml`

## Phase 0 — 解阻塞 (P0)

*全部完成 ✅*

## Phase 1 — 工程化清理 (P1) ✅ P1-012~016, P1-018 已完成

### [P1-001] 文档与示例
类型: docs | 状态: todo | 创建: 2026-05-14
描述: 项目 README、使用示例、API 文档、快速开始指南

### [P1-002] GitHub Actions CI/CD
类型: infra | 状态: todo | 创建: 2026-05-14
描述: 配置 GitHub Actions 流水线：lint → test → build → release

### [P1-019] 修复输出文件名 + examples 集成
类型: bugfix | 状态: todo | 创建: 2026-05-20
描述: (1) codegen.out 作为目录前缀 + "lib.mbt" (2) examples/users 集成生成代码

### [P1-020] 清理编译警告
类型: refactor | 状态: todo | 创建: 2026-05-20
描述: (1) 移除 plugin/moon.pkg 未用 runtime import (2) Value 枚举移除未用 Date/DateTime 变体 (3) stub 清理未用项

### [P1-021] 修复验证脚本假阴性
类型: bugfix | 状态: todo | 创建: 2026-05-20
描述: validate_plugin.ps1 wasm2wat 多行输出 + stderr 污染导致假阴性，加 2>$null + -join 修复

## P2 — 后续

### [P2-001] MySQL 数据库支持
类型: feature | 状态: todo | 创建: 2026-05-14
描述: 扩展 Type Mapping Layer 支持 MySQL 类型
