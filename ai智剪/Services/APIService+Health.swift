import Foundation

// MARK: - Health Action Workflow Response Types

struct HealthActionStartResponse: Codable {
    let success: Bool
    let message: String?
    let taskId: String?
    let modelReferenceTaskId: String?
}

struct HealthActionRegenerateResponse: Codable {
    let success: Bool
    let message: String?
    let retryTaskId: String?
}

struct HealthActionConfirmResponse: Codable {
    let success: Bool
    let message: String?
    let videoTaskId: String?
}

// MARK: - Health Action Workflow API

extension APIService {

    /// 启动健康动作科普工作流
    /// - Parameters:
    ///   - chineseText: 动作描述文本
    ///   - modelImageData: 模型图片数据
    ///   - modelImageName: 模型图片文件名
    ///   - modelImageMime: 模型图片 MIME 类型
    ///   - referenceVideoData: 参考视频数据（可选）
    ///   - referenceVideoName: 参考视频文件名（可选）
    ///   - referenceVideoMime: 参考视频 MIME 类型（可选）
    ///   - referenceFrameData: 参考帧图片数据（可选）
    ///   - referenceFrameName: 参考帧图片文件名（可选）
    ///   - referenceFrameMime: 参考帧图片 MIME 类型（可选）
    func startHealthActionWorkflow(
        chineseText: String,
        modelImageData: Data,
        modelImageName: String,
        modelImageMime: String,
        referenceVideoData: Data? = nil,
        referenceVideoName: String? = nil,
        referenceVideoMime: String? = nil,
        referenceFrameData: Data? = nil,
        referenceFrameName: String? = nil,
        referenceFrameMime: String? = nil
    ) async throws -> HealthActionStartResponse {
        let fields: [(String, String)] = [
            ("chineseText", chineseText)
        ]
        var files: [(String, String, String, Data)] = [
            ("modelImage", modelImageName, modelImageMime, modelImageData)
        ]
        if let referenceVideoData, let referenceVideoName, let referenceVideoMime {
            files.append(("referenceVideo", referenceVideoName, referenceVideoMime, referenceVideoData))
        }
        if let referenceFrameData, let referenceFrameName, let referenceFrameMime {
            files.append(("referenceFrame", referenceFrameName, referenceFrameMime, referenceFrameData))
        }
        let (data, _) = try await uploadMultipart("/api/media/health-action-workflow/start", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(HealthActionStartResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// 重新生成模型参考（Branch B）
    func regenerateHealthActionModelReference() async throws -> HealthActionRegenerateResponse {
        return try await postJSON("/api/media/health-action-workflow/regenerate-model-reference", body: [String: Any]())
    }

    /// 确认动作视频生成（Branch A）
    func confirmHealthActionVideo() async throws -> HealthActionConfirmResponse {
        return try await postJSON("/api/media/health-action-workflow/confirm-action-video", body: [String: Any]())
    }

    /// 查询健康动作任务状态
    func queryHealthActionTaskStatus(taskId: String) async throws -> HealthActionTaskStatusResponse {
        return try await get("/api/media/health-action-workflow/task-status/\(urlPathComponent(taskId))")
    }
}

// MARK: - Health Action Task Status

struct HealthActionTaskStatusResponse: Codable {
    let success: Bool
    let status: String?
    let progress: Double?
    let imageUrl: String?
    let videoUrl: String?
    let message: String?
}
