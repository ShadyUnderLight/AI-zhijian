# 第六阶段：工作流补齐 — 设计文档

## 概述

在 macOS 客户端实现 HailinAI 后端已有的 4 个独立工作流，补齐 Web 端的完整功能矩阵。

## 工作流清单

| # | 工作流 | 类型 | 实现方式 | 后端 API 状态 |
|---|--------|------|---------|-------------|
| 1 | 文→图→视频 | 轻量三步 | DAG 模板 | ✅ 已确认 |
| 2 | Grok-Veo 联合 | 多分镜批量 | DAG 模板 | ✅ 已确认 |
| 3 | 健康动作科普 | 人机审核 | 独立页面 | ✅ 已确认 |
| 4 | 软广 | 项目管线 | 独立页面 | ✅ 已确认 |

## 架构方案

- **模板方式（1/2）**：在现有 `WorkflowDefinition.templates` 中追加新模板，用户通过"工作流编辑器 → 从模板创建"使用。零新页面。
- **独立页面方式（3/4）**：遵循 `DramaWizardView` 模式，新建 SwiftUI View + APIService 扩展 + SidebarTab 注册。

## 数据流

所有工作流调用均通过 `APIService` 的 `postJSON`/`get`/`uploadMultipart` 方法，使用已有 session cookie 鉴权。结果通过 `GenerationQueueStore` 轮询或直接返回。

## 测试策略

- 模板：WorkflowCanvasTests 中加模板构建和验证测试
- 独立页面：SmokeTests 中加导航可达性测试
- DAG 执行：WorkflowCanvasTests 中加 batch 节点执行测试
