import Foundation

// MARK: - Drama Response Types

struct DramaGenerateResponse: Codable {
    let success: Bool
    let outline: String?
    let outlineId: String?
    let message: String?
}

struct DramaStoryboardResponse: Codable {
    let success: Bool
    let storyboard: String?
    let storyboardId: String?
    let message: String?
}

struct DramaScriptResponse: Codable {
    let success: Bool
    let script: String?
    let scriptId: String?
    let message: String?
}

struct DramaVoiceoverResponse: Codable {
    let success: Bool
    let taskId: String?
    let message: String?
}

struct DramaTaskStatusResponse: Codable {
    let success: Bool
    let status: String?
    let progress: Double?
    let videoUrl: String?
    let message: String?
}

struct DramaConcatResponse: Codable {
    let success: Bool
    let videoUrl: String?
    let taskId: String?
    let message: String?
}

struct DramaSubmitVideoResponse: Codable {
    let success: Bool
    let tasks: [DramaVideoTask]?
    let message: String?
}

struct DramaVideoTask: Codable {
    let taskId: String
    let sceneIndex: Int?
    let status: String?
}

// MARK: - Drama Outline API

extension APIService {

    /// 生成短剧大纲
    func generateDramaOutline(dramaType: String, productInfo: String?, educationTopic: String?,
                               language: String, perspectiveIndex: Int?, changePerspective: Bool?,
                               previousOutline: String?) async throws -> DramaGenerateResponse {
        var body: [String: Any] = [
            "dramaType": dramaType,
            "language": language
        ]
        if let productInfo { body["productInfo"] = productInfo }
        if let educationTopic { body["educationTopic"] = educationTopic }
        if let perspectiveIndex { body["perspectiveIndex"] = perspectiveIndex }
        if let changePerspective { body["changePerspective"] = changePerspective }
        if let previousOutline { body["previousOutline"] = previousOutline }
        return try await postJSON("/api/drama-outline/generate", body: body)
    }

    /// 生成分镜（Storyboard）
    func generateDramaStoryboard(outlineId: String) async throws -> DramaStoryboardResponse {
        let body: [String: Any] = ["outlineId": outlineId]
        return try await postJSON("/api/drama-outline/generate-storyboard", body: body)
    }

    /// 生成完整脚本
    func generateDramaScript(outlineId: String, storyboardId: String?) async throws -> DramaScriptResponse {
        var body: [String: Any] = ["outlineId": outlineId]
        if let storyboardId { body["storyboardId"] = storyboardId }
        return try await postJSON("/api/drama-outline/generate-script", body: body)
    }

    /// 提交配音/旁白任务
    func submitDramaVoiceover(scriptId: String, voiceId: String?, platform: String?) async throws -> DramaVoiceoverResponse {
        var body: [String: Any] = ["scriptId": scriptId]
        if let voiceId { body["voiceId"] = voiceId }
        if let platform { body["platform"] = platform }
        return try await postJSON("/api/drama-outline/voiceover", body: body)
    }

    /// 提交视频生成任务
    func submitDramaVideoTasks(outlineId: String, scriptId: String) async throws -> DramaSubmitVideoResponse {
        let body: [String: Any] = [
            "outlineId": outlineId,
            "scriptId": scriptId
        ]
        return try await postJSON("/api/drama-outline/submit-video-tasks", body: body)
    }

    /// 查询任务状态
    func queryDramaTaskStatus(taskId: String) async throws -> DramaTaskStatusResponse {
        return try await get("/api/drama-outline/task-status/\(urlPathComponent(taskId))")
    }

    /// 拼接最终视频
    func concatDramaVideo(taskIds: [String]) async throws -> DramaConcatResponse {
        let body: [String: Any] = ["taskIds": taskIds]
        return try await postJSON("/api/drama-outline/concat", body: body)
    }
}
