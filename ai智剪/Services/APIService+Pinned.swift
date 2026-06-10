import Foundation

// MARK: - PinnedItem Models

struct PinnedItem: Codable, Identifiable, Hashable {
    let id: Int
    let itemType: String
    let itemId: String
    let displayOrder: Int?
    let createdAt: String?
}

struct PinnedItemListResponse: Codable {
    let success: Bool
    let items: [PinnedItem]?
    let message: String?
}

struct PinnedItemCreateResponse: Codable {
    let success: Bool
    let item: PinnedItem?
    let message: String?
}

struct PinnedItemDeleteResponse: Codable {
    let success: Bool
    let message: String?
}

struct PinnedItemReorderResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Pinned API Extension

extension APIService {

    // MARK: 📌 置顶管理

    func pinnedGetItems() async throws -> PinnedItemListResponse {
        try await get("/api/pinned/")
    }

    func pinnedAddItem(itemType: String, itemId: String) async throws -> PinnedItemCreateResponse {
        let body: [String: Any] = [
            "itemType": itemType,
            "itemId": itemId
        ]
        return try await postJSON("/api/pinned/", body: body)
    }

    func pinnedRemoveItem(itemType: String, itemId: String) async throws -> PinnedItemDeleteResponse {
        let body: [String: Any] = [
            "itemType": itemType,
            "itemId": itemId
        ]
        // Backend uses POST with DELETE semantics
        var fullBody = body
        fullBody["_method"] = "DELETE"
        return try await postJSON("/api/pinned/", body: fullBody)
    }

    func pinnedReorderItems(itemIds: [String]) async throws -> PinnedItemReorderResponse {
        let body: [String: Any] = ["itemIds": itemIds]
        return try await postJSON("/api/pinned/reorder", body: body)
    }
}
