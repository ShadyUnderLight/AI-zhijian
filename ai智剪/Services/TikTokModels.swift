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
