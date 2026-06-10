# TikTok 达人采集 — 设计文档

## 概述

为 AI 智剪 macOS 客户端增加 TikTok 达人采集模块。用户可管理达人标签、发现并筛选达人、查看达人详情和视频、控制 Apify 采集任务。

## 后端 API

Base: `/api/tiktok`

| 方法 | 路径 | 用途 | 已验证 |
|------|------|------|--------|
| GET | `/tags` | 标签列表 | ✅ 200 |
| POST | `/tags` | 创建标签 | — |
| DELETE | `/tags/{id}` | 删除标签 | — |
| GET | `/creators/discovery` | 达人发现池 | ✅ 200 |
| POST | `/creators/tag` | 给达人打标签 | — |
| POST | `/creators/batch-status` | 批量更新达人状态 | — |
| POST | `/scrape/start` | 启动 Apify 采集 | — |
| GET | `/scrape/status` | 采集状态 | ✅ 200 |
| GET | `/scrape/logs` | 采集日志 | ✅ 200 |
| GET | `/stats` | 统计看板 | ✅ 200 |
| GET | `/creators/{id}/videos` | 达人视频列表 | — |

## 新增文件

```
ai智剪/Services/
  TikTokModels.swift              — 数据模型
  APIService+TikTok.swift         — API 扩展

ai智剪/Views/
  TikTokTagManageView.swift       — 标签管理（列表 + 创建弹窗 + 删除）
  TikTokCreatorsView.swift        — 达人发现池（卡片网格 + 筛选器 + 批量操作）
  TikTokCreatorDetailView.swift   — 达人详情（基本信息 + 视频列表 + 打标签）
  TikTokScrapeControlView.swift   — 采集控制（启动/状态/日志）
```

## 修改文件

- `Views/MainView.swift` — SidebarTab 新增 4 个 case、detailView switch 分支

## 数据模型

```swift
struct TikTokTag: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct TikTokCreator: Codable, Identifiable, Hashable {
    let id: Int
    let nickname: String?
    let avatarUrl: String?
    let followerCount: Int?
    let followingCount: Int?
    let videoCount: Int?
    let country: String?
    let status: CreatorStatus?
    let tags: [TikTokTag]?
    let description: String?
    let scrapeTime: String?
}

enum CreatorStatus: String, Codable, CaseIterable {
    case new = "NEW"
    case interested = "INTERESTED"
    case contacted = "CONTACTED"
    case cooperating = "COOPERATING"
    case rejected = "REJECTED"
    case blacklist = "BLACKLIST"
}

struct TikTokCreatorVideo: Codable, Identifiable {
    let id: Int
    let videoUrl: String?
    let coverUrl: String?
    let title: String?
    let playCount: Int?
    let likeCount: Int?
    let commentCount: Int?
    let shareCount: Int?
    let createTime: String?
}

struct TikTokScrapeStatus: Codable {
    let isRunning: Bool
    let message: String?
}

struct TikTokStats: Codable {
    let totalCreators: Int
    let totalVideos: Int
    let totalTags: Int
    let activeTags: Int
    let managedCount: Int
    let discoveryCount: Int
    let statusCounts: [String: Int]
    let isRunning: Bool
}
```

## View 设计

### 标签管理
- 列表显示所有标签 + 删除按钮
- 顶栏 "+" 按钮弹出创建弹窗（TextField + 确认）
- 搜索过滤（可选，第一版不强制）

### 达人发现池
- 顶部筛选栏：标签 Picker、状态 Segmented Picker、粉丝数范围、国家
- 卡片网格（LazyVGrid）：头像、昵称、粉丝数、状态标签、标签
- 点击卡片 → 达人详情页
- 多选模式 + 底部批量操作栏：批量更新状态、批量打标签

### 达人详情
- 头部：头像、昵称、粉丝/关注/视频数、描述、国家
- 标签列表：已打的标签（可移除），添加标签按钮
- 视频列表：封面、标题、播放量、点赞量

### 采集控制
- 状态指示器（运行中/空闲）
- "启动采集"按钮（运行中时禁用）
- 日志列表（滚动刷新）

## 路由

MainView 侧边栏新增 "营销" 分组（或放在现有分组中），包含：
- TikTok 达人采集 → TikTokCreatorsView
- 达人详情通过 NavigationLink 或 sheet 展示

## 裁剪项（第一版不做）

- 统计看板（TikTokStatsView）
- 趋势图/图表
- 分页加载优化（直接全量加载）
- 达人数据导出
