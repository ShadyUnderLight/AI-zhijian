# TikTok 达人采集 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add TikTok creator collection module to macOS AI 智剪 client — tag management, creator discovery pool, creator details, and scrape control.

**Architecture:** Follow existing project pattern: Models + APIService extension for network layer, standalone SwiftUI Views for UI, SidebarTab enum + detailView switch for routing. XcodeGen auto-scans new files.

**Tech Stack:** SwiftUI, macOS 14+, URLSession async/await, no external dependencies.

---

### Task 1: TikTok 数据模型

**Files:**
- Create: `ai智剪/Services/TikTokModels.swift`

- [ ] **Create TikTokModels.swift with all response types**

```swift
import Foundation

// MARK: - Tags

struct TikTokTag: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct TikTokTagListResponse: Codable {
    let success: Bool
    let data: [TikTokTag]?
    let message: String?
}

struct TikTokCreateTagResponse: Codable {
    let success: Bool
    let data: TikTokTag?
    let message: String?
}

struct TikTokDeleteTagResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Creators

enum CreatorStatus: String, Codable, CaseIterable, Identifiable {
    case new = "NEW"
    case interested = "INTERESTED"
    case contacted = "CONTACTED"
    case cooperating = "COOPERATING"
    case rejected = "REJECTED"
    case blacklist = "BLACKLIST"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: return "新发现"
        case .interested: return "有意向"
        case .contacted: return "已联系"
        case .cooperating: return "合作中"
        case .rejected: return "已拒绝"
        case .blacklist: return "黑名单"
        }
    }
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TikTokCreator, rhs: TikTokCreator) -> Bool {
        lhs.id == rhs.id
    }
}

struct TikTokCreatorDiscoveryResponse: Codable {
    let success: Bool
    let data: [TikTokCreator]?
    let total: Int?
    let message: String?
}

struct TikTokTagCreatorResponse: Codable {
    let success: Bool
    let message: String?
}

struct TikTokBatchStatusResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Videos

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

struct TikTokCreatorVideosResponse: Codable {
    let success: Bool
    let data: [TikTokCreatorVideo]?
    let message: String?
}

// MARK: - Scrape

struct TikTokScrapeStatus: Codable {
    let isRunning: Bool
    let message: String?
}

struct TikTokScrapeStatusResponse: Codable {
    let success: Bool
    let data: TikTokScrapeStatus?
    let message: String?
}

struct TikTokScrapeStartResponse: Codable {
    let success: Bool
    let message: String?
}

struct TikTokScrapeLog: Codable, Identifiable {
    let id: Int?
    let level: String?
    let message: String?
    let createdAt: String?
}

struct TikTokScrapeLogsResponse: Codable {
    let success: Bool
    let data: [TikTokScrapeLog]?
    let message: String?
}

// MARK: - Stats

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

struct TikTokStatsResponse: Codable {
    let success: Bool
    let data: TikTokStats?
    let message: String?
}
```

- [ ] **Commit**

```bash
git add ai智剪/Services/TikTokModels.swift
git commit -m "feat(tiktok): add TikTok data models"
```

---

### Task 2: TikTok API 扩展

**Files:**
- Create: `ai智剪/Services/APIService+TikTok.swift`
- Depends on: Task 1 (models)

- [ ] **Create APIService+TikTok.swift with all API methods**

```swift
import Foundation

// MARK: - TikTok API Extension

extension APIService {

    // MARK: Tags

    func tiktokGetTags() async throws -> [TikTokTag] {
        let response: TikTokTagListResponse = try await get(path: "/api/tiktok/tags")
        return response.data ?? []
    }

    func tiktokCreateTag(name: String) async throws -> TikTokTag {
        let body: [String: String] = ["name": name]
        let response: TikTokCreateTagResponse = try await postJSON(path: "/api/tiktok/tags", body: body)
        guard let tag = response.data else {
            throw APIError.serverMessage(response.message ?? "创建标签失败")
        }
        return tag
    }

    func tiktokDeleteTag(id: Int) async throws {
        let response: TikTokDeleteTagResponse = try await postJSON(
            path: "/api/tiktok/tags/\(id)",
            body: ["_method": "DELETE"] as [String: String]
        )
        if !response.success {
            throw APIError.serverMessage(response.message ?? "删除标签失败")
        }
    }

    // MARK: Creators

    func tiktokGetCreatorsDiscovery(tagId: Int? = nil,
                                   status: CreatorStatus? = nil,
                                   minFollowers: Int? = nil,
                                   maxFollowers: Int? = nil,
                                   country: String? = nil,
                                   keyword: String? = nil) async throws -> [TikTokCreator] {
        var params: [String: String] = [:]
        if let tagId { params["tagId"] = String(tagId) }
        if let status { params["status"] = status.rawValue }
        if let minFollowers { params["minFollowers"] = String(minFollowers) }
        if let maxFollowers { params["maxFollowers"] = String(maxFollowers) }
        if let country { params["country"] = country }
        if let keyword { params["keyword"] = keyword }
        let response: TikTokCreatorDiscoveryResponse = try await get(path: "/api/tiktok/creators/discovery", params: params)
        return response.data ?? []
    }

    func tiktokTagCreator(creatorId: Int, tagId: Int) async throws {
        let body: [String: Any] = ["creatorId": creatorId, "tagId": tagId]
        let response: TikTokTagCreatorResponse = try await postJSON(path: "/api/tiktok/creators/tag", body: body)
        if !response.success {
            throw APIError.serverMessage(response.message ?? "打标签失败")
        }
    }

    func tiktokBatchUpdateStatus(creatorIds: [Int], status: CreatorStatus) async throws {
        let body: [String: Any] = ["creatorIds": creatorIds, "status": status.rawValue]
        let response: TikTokBatchStatusResponse = try await postJSON(path: "/api/tiktok/creators/batch-status", body: body)
        if !response.success {
            throw APIError.serverMessage(response.message ?? "批量更新状态失败")
        }
    }

    // MARK: Videos

    func tiktokGetCreatorVideos(creatorId: Int) async throws -> [TikTokCreatorVideo] {
        let response: TikTokCreatorVideosResponse = try await get(path: "/api/tiktok/creators/\(creatorId)/videos")
        return response.data ?? []
    }

    // MARK: Scrape

    func tiktokStartScrape() async throws {
        let response: TikTokScrapeStartResponse = try await postJSON(path: "/api/tiktok/scrape/start", body: [:] as [String: String])
        if !response.success {
            throw APIError.serverMessage(response.message ?? "启动采集失败")
        }
    }

    func tiktokGetScrapeStatus() async throws -> TikTokScrapeStatus {
        let response: TikTokScrapeStatusResponse = try await get(path: "/api/tiktok/scrape/status")
        return response.data ?? TikTokScrapeStatus(isRunning: false, message: nil)
    }

    func tiktokGetScrapeLogs() async throws -> [TikTokScrapeLog] {
        let response: TikTokScrapeLogsResponse = try await get(path: "/api/tiktok/scrape/logs")
        return response.data ?? []
    }

    // MARK: Stats

    func tiktokGetStats() async throws -> TikTokStats {
        let response: TikTokStatsResponse = try await get(path: "/api/tiktok/stats")
        return response.data ?? TikTokStats(totalCreators: 0, totalVideos: 0, totalTags: 0, activeTags: 0, managedCount: 0, discoveryCount: 0, statusCounts: [:], isRunning: false)
    }
}
```

Note: `postJSON` expects body to be `Encodable`. The `[String: Any]` dictionary won't work directly. I need to check how the existing API does it. Let me adjust.

Actually, looking at `APIService+Admin.swift`, they use concrete structs for request bodies. Let me use `[String: String]` or create request body structs where needed.

For `tiktokTagCreator`, I'll use a struct. For `tiktokBatchUpdateStatus`, same.

Let me revise the API extension code properly. Also need to check what `postJSON` signature looks like.

Let me look at the APIService postJSON method to understand what types it accepts.<｜end▁of▁thinking｜>

<｜｜DSML｜｜tool_calls>
<｜｜DSML｜｜invoke name="grep">
<｜｜DSML｜｜parameter name="pattern" string="true">func postJSON