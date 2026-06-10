import Foundation

// MARK: - Soft Ad Workflow Models

struct SoftAdProject: Identifiable, Codable {
    let id: Int
    let name: String
    let productInfo: String?
    let target: String?
    let status: String
    let createdAt: String?
    let updatedAt: String?
}

struct SoftAdImageTask: Identifiable, Codable {
    let taskId: String
    let sceneIndex: Int?
    let status: String?

    var id: String { taskId }
}

struct SoftAdVideoTask: Identifiable, Codable {
    let taskId: String
    let sceneIndex: Int?
    let status: String?

    var id: String { taskId }
}

// MARK: - Soft Ad Workflow Response Types

struct SoftAdProjectListResponse: Codable {
    let success: Bool
    let projects: [SoftAdProject]?
    let message: String?
}

struct SoftAdProjectResponse: Codable {
    let success: Bool
    let project: SoftAdProject?
    let message: String?
}

struct SoftAdDeleteResponse: Codable {
    let success: Bool
    let message: String?
}

struct SoftAdGenerateScriptResponse: Codable {
    let success: Bool
    let script: String?
    let scriptId: String?
    let message: String?
}

struct SoftAdImageSubmitResponse: Codable {
    let success: Bool
    let tasks: [SoftAdImageTask]?
    let message: String?
}

struct SoftAdImagePollResponse: Codable {
    let success: Bool
    let status: String?
    let imageUrls: [String]?
    let message: String?
}

struct SoftAdVideoSubmitResponse: Codable {
    let success: Bool
    let tasks: [SoftAdVideoTask]?
    let message: String?
}

struct SoftAdVideoPollResponse: Codable {
    let success: Bool
    let status: String?
    let videoUrl: String?
    let message: String?
}

struct SoftAdConcatResponse: Codable {
    let success: Bool
    let videoUrl: String?
    let taskId: String?
    let message: String?
}

struct SoftAdExportResponse: Codable {
    let success: Bool
    let exportUrl: String?
    let message: String?
}

struct SoftAdOptimizePromptResponse: Codable {
    let success: Bool
    let optimizedText: String?
    let message: String?
}

// MARK: - Soft Ad Workflow API

extension APIService {

    // MARK: Project CRUD

    /// 获取软广项目列表
    func fetchSoftAdProjects() async throws -> SoftAdProjectListResponse {
        try await get("/api/soft-ad-workflow/projects")
    }

    /// 创建软广项目
    func createSoftAdProject(name: String, productInfo: String, target: String) async throws -> SoftAdProjectResponse {
        let body: [String: Any] = [
            "name": name,
            "productInfo": productInfo,
            "target": target
        ]
        return try await postJSON("/api/soft-ad-workflow/projects", body: body)
    }

    /// 获取单个软广项目
    func getSoftAdProject(id: Int) async throws -> SoftAdProjectResponse {
        try await get("/api/soft-ad-workflow/projects/\(urlPathComponent(String(id)))")
    }

    /// 更新软广项目
    func updateSoftAdProject(id: Int, name: String, productInfo: String, target: String) async throws -> SoftAdProjectResponse {
        let body: [String: Any] = [
            "name": name,
            "productInfo": productInfo,
            "target": target
        ]
        guard let url = URL(string: "/api/soft-ad-workflow/projects/\(urlPathComponent(String(id)))", relativeTo: AppConfig.apiBaseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let result = try? JSONDecoder().decode(SoftAdProjectResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// 删除软广项目
    func deleteSoftAdProject(id: Int) async throws -> SoftAdDeleteResponse {
        guard let url = URL(string: "/api/soft-ad-workflow/projects/\(urlPathComponent(String(id)))", relativeTo: AppConfig.apiBaseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: req)
        if let result = try? JSONDecoder().decode(SoftAdDeleteResponse.self, from: data) {
            return result
        }
        return SoftAdDeleteResponse(success: true, message: nil)
    }

    // MARK: Script

    /// 生成软广脚本
    func generateSoftAdScript(projectId: Int) async throws -> SoftAdGenerateScriptResponse {
        let body: [String: Any] = [:]
        return try await postJSON("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/generate-script", body: body)
    }

    // MARK: Images

    /// 提交各场景图片生成任务
    func submitSoftAdImages(projectId: Int, scenePrompts: [String]) async throws -> SoftAdImageSubmitResponse {
        let body: [String: Any] = ["scenePrompts": scenePrompts]
        return try await postJSON("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/images/submit", body: body)
    }

    /// 轮询图片生成结果
    func pollSoftAdImage(projectId: Int, taskId: String) async throws -> SoftAdImagePollResponse {
        try await get("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/images/poll/\(urlPathComponent(taskId))")
    }

    // MARK: Videos

    /// 提交各场景视频生成任务
    func submitSoftAdVideos(projectId: Int, sceneImageUrls: [String]) async throws -> SoftAdVideoSubmitResponse {
        let body: [String: Any] = ["sceneImageUrls": sceneImageUrls]
        return try await postJSON("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/videos/submit", body: body)
    }

    /// 轮询视频生成结果
    func pollSoftAdVideo(projectId: Int, taskId: String) async throws -> SoftAdVideoPollResponse {
        try await get("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/videos/poll/\(urlPathComponent(taskId))")
    }

    // MARK: Concat & Export

    /// 拼接最终视频
    func concatSoftAdVideo(projectId: Int) async throws -> SoftAdConcatResponse {
        let body: [String: Any] = [:]
        return try await postJSON("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/concat", body: body)
    }

    /// 导出项目
    func exportSoftAdProject(projectId: Int) async throws -> SoftAdExportResponse {
        try await get("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/export")
    }

    // MARK: Prompt Optimization

    /// 优化图片提示词
    func optimizeSoftAdImagePrompt(projectId: Int, prompt: String) async throws -> SoftAdOptimizePromptResponse {
        let body: [String: Any] = ["prompt": prompt]
        return try await postJSON("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/prompts/optimize-image", body: body)
    }

    /// 优化视频提示词
    func optimizeSoftAdVideoPrompt(projectId: Int, prompt: String) async throws -> SoftAdOptimizePromptResponse {
        let body: [String: Any] = ["prompt": prompt]
        return try await postJSON("/api/soft-ad-workflow/projects/\(urlPathComponent(String(projectId)))/prompts/optimize-video", body: body)
    }
}
