# AI 智剪

> 海灵智剪 macOS 原生客户端 — 集图片生成、视频生成于一体的 AI 创意工具

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-6.0-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## ✨ 功能

| 模块 | 功能 | 后端 |
|------|------|------|
| 🖼️ 图片生成 | GPT-Image-2 文生图，支持渠道/画幅/分辨率/质量 | `gpt-image-2/text-to-image` |
| 🍌 Banana 图片 | Gemini 图生图/文生图，支持参考图+提示词 | `media/banana` |
| 🎬 Seedance 视频 | Seedance 2.0 视频生成，支持参考图/首尾帧/音频 | `seedance20/submit` |
| 🎥 Wan 视频 | Wan2.2 图生视频 | `media/wan2-image-to-video` |
| 🌐 Veo 视频 | 5 种模式 (text/image/reference/start_end/extend)，3 种模型 | `veo-video/submit` |
| 🤖 Grok 视频 | 5 种模式，支持 6-30s 时长，官方/低价渠道 | `grok-video/submit` |
| 📋 历史记录 | 图片/视频历史网格浏览 | `history` |
| ⏳ 任务队列 | 实时显示活跃任务，自动轮询状态 | — |

## 🖥️ 界面

```
┌──────────────────────────────────────────────────┐
│  AI 智剪 — ShadyUnderLight (ADMIN)        [退出]  │
├───────────┬──────────────────────────────────────┤
│  Sidebar  │                                      │
│           │     ┌─────────────────────────┐      │
│ 🖼️ 图片   │     │                         │      │
│ 🎬 Seedance│    │    功能内容区域           │      │
│ 🍌 Banana │     │                         │      │
│ 🎥 Wan    │     └─────────────────────────┘      │
│ 🌐 Veo    │                                      │
│ 🤖 Grok   │                                      │
│ ──────── │                                      │
│ 📋 历史   │                                      │
│ ⏳ 任务   │                                      │
└───────────┴──────────────────────────────────────┘
```

- **macOS 原生界面**：NavigationSplitView 侧边栏布局
- **原生文件选择**：NSOpenPanel，支持图片/视频类型过滤
- **实时状态轮询**：Task-based 异步，3 秒间隔，状态实时刷新
- **自动登录**：可选保存登录信息，使用 macOS Keychain 安全存储密码
- **原生窗口**：最小化、全屏、Dock 图标

## 🏗️ 技术栈

| 层 | 技术 |
|---|------|
| UI | SwiftUI (NavigationSplitView, List, Form) |
| 网络 | URLSession + async/await |
| 会话 | HTTPCookieStorage 自动管理 |
| 图片加载 | AsyncImage |
| 项目配置 | XcodeGen (project.yml) |
| 最低系统 | macOS 14.0 (Sonoma) |
| 语言 | Swift 6.0 |

## 📦 项目结构

```
AI-zhijian/
├── ai智剪.xcodeproj            # Xcode 项目文件
├── project.yml                 # XcodeGen 配置
├── .gitignore
├── README.md
└── ai智剪/
    ├── ai智剪App.swift          # @main 入口
    ├── ContentView.swift        # 登录/主界面路由
    ├── Info.plist               # 应用配置 (ATS 等)
    ├── Services/
    │   ├── APIService.swift     # API 层 (11 个接口 + 轮询调度)
    │   └── CredentialStore.swift # Keychain 登录凭据存储
    └── Views/
        ├── LoginView.swift           # 登录
        ├── MainView.swift            # 侧边栏导航
        ├── ImageGenView.swift        # 文生图 + TaskPollingView
        ├── SeedanceVideoView.swift   # 视频生成 + FilePickerRow
        ├── BananaView.swift          # Banana 图片
        ├── WanVideoView.swift        # Wan 图生视频
        ├── VeoVideoView.swift        # Veo 视频 (5 模式)
        ├── GrokVideoView.swift       # Grok 视频
        ├── TaskListView.swift        # 任务队列
        └── HistoryView.swift         # 历史记录
```

## 🚀 编译运行

### 环境要求

- macOS 14.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### 编译

```bash
# 1. 生成 Xcode 项目
cd AI-zhijian
xcodegen generate

# 2. 编译
xcodebuild -project "ai智剪.xcodeproj" -scheme "ai智剪" -configuration Debug build

# 3. 产物位置
open ~/Library/Developer/Xcode/DerivedData/ai智剪-*/Build/Products/Debug/AI\ 智剪.app
```

### 或者用 Xcode

```bash
open ai智剪.xcodeproj
# Cmd + R 运行
```

## 🧪 自动化测试

默认 scheme 运行非 UI smoke tests，适合日常后台自动化，不会启动 App 窗口或抢前台焦点：

```bash
xcodebuild -project "ai智剪.xcodeproj" -scheme "ai智剪" -configuration Debug test
```

测试进程会自动禁用启动自动登录和 Keychain 凭据读写，因此不会弹出系统钥匙串授权，也不会改动本机保存的登录信息。

项目当前不包含 macOS UI 自动化测试入口，避免测试启动真实 App 窗口影响日常使用。

## 📡 架构

```
┌──────────────┐   URLSession (Cookie 自动管理)    ┌───────────────────┐
│   SwiftUI     │ ←─────────────────────────────→  │ 43.139.67.8:7777  │
│   Views       │   JSON / multipart/form-data      │ 海灵智剪 API       │
└──────────────┘                                   └───────────────────┘
       ↕
┌──────────────┐
│  APIService  │  @MainActor 单例
│  @Published  │  - isLoggedIn / username / role
│  Observable  │  - activeTasks (实时任务队列)
│              │  - 11 个 API 方法
│              │  - 自动轮询调度
└──────────────┘
```

### 数据流

1. **登录** → Cookie 写入 `HTTPCookieStorage`，勾选记住登录时凭据写入 Keychain
2. **启动检查** → 优先验证 Cookie，会话失效时使用 Keychain 凭据自动登录
3. **后续请求** → URLSession 自动携带 Cookie
4. **生成任务** → 提交 → 返回 taskId → 加入 activeTasks
5. **轮询** → 每 3 秒查询状态 → SUCCESS 时展示结果 → FAILED 时报错
6. **结果** → 图片用 AsyncImage 展示 / 视频用浏览器打开

## 🔐 安全说明

应用已配置 `NSAppTransportSecurity.NSAllowsArbitraryLoads = true` 以允许 HTTP 请求到本地/内网 API。生产环境部署到 HTTPS 时可移除此配置。

选择“记住登录信息”后，密码保存到 macOS Keychain，不写入 `UserDefaults`。取消勾选或退出登录会清除已保存的自动登录凭据。

## 📝 后续计划

- [ ] 视频在本窗口内播放 (AVPlayer)
- [ ] 批量生成队列
- [x] 登录信息持久化
- [ ] 任务本地缓存
- [ ] 多 API 服务器切换
- [ ] macOS 15+ 适配

## 📄 协议

MIT License
