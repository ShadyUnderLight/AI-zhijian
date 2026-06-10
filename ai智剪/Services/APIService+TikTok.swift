import Foundation

// MARK: - TikTok API Extension

extension APIService {

    // MARK: Tags

    func tiktokGetTags() async throws -> [TikTokTag] {
        let response: TikTokTagListResponse = try await get("/api/tiktok/tags")
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "获取标签列表失败")
        }
        return response.data ?? []
    }

    func tiktokCreateTag(name: String) async throws -> TikTokTag {
        let body: [String: Any] = ["name": name]
        let response: TikTokCreateTagResponse = try await postJSON("/api/tiktok/tags", body: body)
        guard let tag = response.data else {
            throw APIError.requestFailed(response.message ?? "创建标签失败")
        }
        return tag
    }

    func tiktokDeleteTag(id: Int) async throws {
        // Backend treats POST with _method=DELETE as delete (same pattern as Admin module)
        let response: TikTokDeleteTagResponse = try await postJSON(
            "/api/tiktok/tags/\(id)",
            body: ["_method": "DELETE"] as [String: Any]
        )
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "删除标签失败")
        }
    }

    // MARK: Creators

    func tiktokGetCreatorsDiscovery(
        tagId: Int? = nil,
        status: CreatorStatus? = nil,
        minFollowers: Int? = nil,
        maxFollowers: Int? = nil,
        country: String? = nil,
        keyword: String? = nil
    ) async throws -> [TikTokCreator] {
        var params: [String: String] = [:]
        if let tagId { params["tagId"] = String(tagId) }
        if let status { params["status"] = status.rawValue }
        if let minFollowers { params["minFollowers"] = String(minFollowers) }
        if let maxFollowers { params["maxFollowers"] = String(maxFollowers) }
        if let country { params["country"] = country }
        if let keyword { params["keyword"] = keyword }
        let response: TikTokCreatorDiscoveryResponse = try await get("/api/tiktok/creators/discovery", params: params)
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "获取达人列表失败")
        }
        return response.data ?? []
    }

    func tiktokTagCreator(creatorId: Int, tagId: Int) async throws {
        let body: [String: Any] = ["creatorId": creatorId, "tagId": tagId]
        let response: TikTokTagCreatorResponse = try await postJSON("/api/tiktok/creators/tag", body: body)
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "打标签失败")
        }
    }

    func tiktokBatchUpdateStatus(creatorIds: [Int], status: CreatorStatus) async throws {
        let body: [String: Any] = ["creatorIds": creatorIds, "status": status.rawValue]
        let response: TikTokBatchStatusResponse = try await postJSON("/api/tiktok/creators/batch-status", body: body)
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "批量更新状态失败")
        }
    }

    // MARK: Videos

    func tiktokGetCreatorVideos(creatorId: Int) async throws -> [TikTokCreatorVideo] {
        let response: TikTokCreatorVideosResponse = try await get("/api/tiktok/creators/\(creatorId)/videos")
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "获取达人视频失败")
        }
        return response.data ?? []
    }

    // MARK: Scrape

    func tiktokStartScrape() async throws {
        let body: [String: Any] = [:]
        let response: TikTokScrapeStartResponse = try await postJSON("/api/tiktok/scrape/start", body: body)
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "启动采集失败")
        }
    }

    func tiktokGetScrapeStatus() async throws -> TikTokScrapeStatus {
        let response: TikTokScrapeStatusResponse = try await get("/api/tiktok/scrape/status")
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "获取采集状态失败")
        }
        return response.data ?? TikTokScrapeStatus(isRunning: false, message: nil)
    }

    func tiktokGetScrapeLogs() async throws -> [TikTokScrapeLog] {
        let response: TikTokScrapeLogsResponse = try await get("/api/tiktok/scrape/logs")
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "获取采集日志失败")
        }
        return response.data ?? []
    }

    // MARK: Stats

    func tiktokGetStats() async throws -> TikTokStats {
        let response: TikTokStatsResponse = try await get("/api/tiktok/stats")
        guard response.success else {
            throw APIError.requestFailed(response.message ?? "获取统计数据失败")
        }
        return response.data ?? TikTokStats(
            totalCreators: 0, totalVideos: 0, totalTags: 0,
            activeTags: 0, managedCount: 0, discoveryCount: 0,
            statusCounts: [:], isRunning: false
        )
    }
}
