import Foundation

// MARK: - Comic Response Types

struct ComicScriptResponse: Codable {
    let success: Bool
    let script: String?
    let scriptId: String?
    let sceneCount: Int?
    let message: String?
}

struct ComicCharacterImage: Codable {
    let characterIndex: Int
    let name: String?
    let imageUrl: String?
    let status: String?
    let errorMessage: String?
}

struct ComicCharacterImagesResponse: Codable {
    let success: Bool
    let characters: [ComicCharacterImage]?
    let message: String?
}

struct ComicRetryCharacterResponse: Codable {
    let success: Bool
    let characterIndex: Int?
    let imageUrl: String?
    let message: String?
}

struct ComicShotInfo: Codable {
    let shotIndex: Int
    let shotId: String?
    let status: String?
    let videoUrl: String?
    let errorMessage: String?
}

struct ComicSubmitVideosResponse: Codable {
    let success: Bool
    let taskId: String?
    let shots: [ComicShotInfo]?
    let message: String?
}

struct ComicRetryShotResponse: Codable {
    let success: Bool
    let shotIndex: Int?
    let shotId: String?
    let message: String?
}

struct ComicRescueShotResponse: Codable {
    let success: Bool
    let shotIndex: Int?
    let shotId: String?
    let message: String?
}

struct ComicTaskStatusResponse: Codable {
    let success: Bool
    let status: String?
    let progress: Double?
    let shots: [ComicShotInfo]?
    let videoUrl: String?
    let message: String?
}

struct ComicCancelResponse: Codable {
    let success: Bool
    let cancelledCount: Int?
    let message: String?
}

// MARK: - AI Comic API

extension APIService {

    /// 生成漫画脚本
    func generateComicScript(topic: String, language: String, style: String?,
                              characterCount: Int?, panelCount: Int?) async throws -> ComicScriptResponse {
        var body: [String: Any] = [
            "topic": topic,
            "language": language
        ]
        if let style { body["style"] = style }
        if let characterCount { body["characterCount"] = characterCount }
        if let panelCount { body["panelCount"] = panelCount }
        return try await postJSON("/api/ai-comic/generate-script", body: body)
    }

    /// 提交角色参考图
    func submitComicCharacterImages(scriptId: String, characterIndex: Int,
                                     imageData: Data, imageName: String, imageMime: String) async throws -> ComicCharacterImagesResponse {
        let fields: [(String, String)] = [
            ("scriptId", scriptId),
            ("characterIndex", "\(characterIndex)")
        ]
        let files: [(String, String, String, Data)] = [
            ("image", imageName, imageMime, imageData)
        ]
        let (data, _) = try await uploadMultipart("/api/ai-comic/submit-character-images", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(ComicCharacterImagesResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// 重试单个角色图片生成
    func retryComicCharacterImage(scriptId: String, characterIndex: Int) async throws -> ComicRetryCharacterResponse {
        let body: [String: Any] = [
            "scriptId": scriptId,
            "characterIndex": characterIndex
        ]
        return try await postJSON("/api/ai-comic/retry-character-image", body: body)
    }

    /// 提交漫画视频生成任务
    func submitComicVideos(scriptId: String, characterIds: [String: Int]?) async throws -> ComicSubmitVideosResponse {
        var body: [String: Any] = ["scriptId": scriptId]
        if let characterIds { body["characterIds"] = characterIds }
        return try await postJSON("/api/ai-comic/submit-videos", body: body)
    }

    /// 重试单个镜头
    func retryComicVideoShot(taskId: String, shotIndex: Int) async throws -> ComicRetryShotResponse {
        let body: [String: Any] = [
            "taskId": taskId,
            "shotIndex": shotIndex
        ]
        return try await postJSON("/api/ai-comic/retry-video-shot", body: body)
    }

    /// Rescue 模式：使用 Seedance 回退
    func rescueComicShotSeedance(taskId: String, shotIndex: Int) async throws -> ComicRescueShotResponse {
        let body: [String: Any] = [
            "taskId": taskId,
            "shotIndex": shotIndex
        ]
        return try await postJSON("/api/ai-comic/rescue-shot-seedance", body: body)
    }

    /// 查询漫画任务状态
    func queryComicTaskStatus(taskId: String) async throws -> ComicTaskStatusResponse {
        return try await get("/api/ai-comic/rh-task/\(urlPathComponent(taskId))")
    }

    /// 批量取消 RunningHub 任务
    func cancelComicRunningHubTasks(taskIds: [String]) async throws -> ComicCancelResponse {
        let body: [String: Any] = ["taskIds": taskIds]
        return try await postJSON("/api/ai-comic/cancel-runninghub-tasks", body: body)
    }
}
