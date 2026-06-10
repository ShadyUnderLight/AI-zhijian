import Foundation

// MARK: - VideoScript API (AI 脚本生成·提示词生成·图文视频一站式提交)

extension APIService {

    // MARK: Script Generation & Editing

    /// AI 生成完整脚本表格
    func videoScriptGenerateTable(requirement: String) async throws -> VideoScriptGenerateTableResponse {
        let body: [String: Any] = ["requirement": requirement]
        return try await postJSON("/api/video-script/generate-table", body: body)
    }

    /// 基于用户反馈优化脚本表格
    func videoScriptRefine(feedback: String, rows: [VideoScriptTableRow]) async throws -> VideoScriptRefineResponse {
        let encoder = JSONEncoder()
        let rowsData = try encoder.encode(rows)
        let rowsJSON = try JSONSerialization.jsonObject(with: rowsData) as! [[String: Any]]
        let body: [String: Any] = ["feedback": feedback, "rows": rowsJSON]
        return try await postJSON("/api/video-script/refine", body: body)
    }

    /// 批量翻译脚本中的文案为中文
    func videoScriptTranslateCopy(rows: [VideoScriptTableRow]) async throws -> VideoScriptTranslateCopyResponse {
        let encoder = JSONEncoder()
        let rowsData = try encoder.encode(rows)
        let rowsJSON = try JSONSerialization.jsonObject(with: rowsData) as! [[String: Any]]
        let body: [String: Any] = ["rows": rowsJSON]
        return try await postJSON("/api/video-script/translate-copy-zh", body: body)
    }

    // MARK: Prompt Generation

    /// 为某行分镜生成图片提示词
    func videoScriptGenerateImagePrompt(rowId: String, sceneDescription: String, copy: String) async throws -> VideoScriptGeneratePromptResponse {
        let body: [String: Any] = ["rowId": rowId, "sceneDescription": sceneDescription, "copy": copy]
        return try await postJSON("/api/video-script/generate-image-prompt", body: body)
    }

    /// 为某行分镜生成视频提示词
    func videoScriptGenerateVideoPrompt(rowId: String, sceneDescription: String, copy: String) async throws -> VideoScriptGeneratePromptResponse {
        let body: [String: Any] = ["rowId": rowId, "sceneDescription": sceneDescription, "copy": copy]
        return try await postJSON("/api/video-script/generate-video-prompt", body: body)
    }

    // MARK: One-Click Submit

    /// 从脚本行提交文生图
    func videoScriptSubmitImage(rowId: String, imagePrompt: String, aspectRatio: String? = nil, resolution: String? = nil) async throws -> VideoScriptSubmitResponse {
        var body: [String: Any] = ["rowId": rowId, "imagePrompt": imagePrompt]
        if let aspectRatio { body["aspectRatio"] = aspectRatio }
        if let resolution { body["resolution"] = resolution }
        return try await postJSON("/api/video-script/submit-image", body: body)
    }

    /// 从脚本行提交文生视频
    func videoScriptSubmitVideo(rowId: String, videoPrompt: String, aspectRatio: String? = nil, duration: String? = nil) async throws -> VideoScriptSubmitResponse {
        var body: [String: Any] = ["rowId": rowId, "videoPrompt": videoPrompt]
        if let aspectRatio { body["aspectRatio"] = aspectRatio }
        if let duration { body["duration"] = duration }
        return try await postJSON("/api/video-script/submit-video", body: body)
    }

    /// 从脚本行提交图生视频（支持多种模型）
    func videoScriptSubmitImageToVideo(rowId: String, imagePrompt: String, imageUrl: String? = nil, model: String = "grok", audioEnabled: Bool? = nil, realMode: Bool? = nil) async throws -> VideoScriptSubmitResponse {
        var body: [String: Any] = ["rowId": rowId, "imagePrompt": imagePrompt, "model": model]
        if let imageUrl { body["imageUrl"] = imageUrl }
        if let audioEnabled { body["audioEnabled"] = audioEnabled }
        if let realMode { body["realMode"] = realMode }
        return try await postJSON("/api/video-script/submit-image-to-video", body: body)
    }

    // MARK: Query Task

    /// 查询图片/视频任务状态
    func videoScriptQueryTask(channel: String, imageModel: String? = nil) async throws -> VideoScriptQueryResponse {
        var params: [String: String] = ["channel": channel]
        if let imageModel { params["imageModel"] = imageModel }
        return try await get("/api/video-script/query", params: params)
    }

    // MARK: Server-side Storage

    /// 保存脚本到服务端
    func videoScriptSave(requirement: String, title: String, rows: [VideoScriptTableRow]) async throws -> VideoScriptStoreSaveResponse {
        let encoder = JSONEncoder()
        let rowsData = try encoder.encode(rows)
        let rowsJSON = try JSONSerialization.jsonObject(with: rowsData) as! [[String: Any]]
        let body: [String: Any] = ["requirement": requirement, "title": title, "rows": rowsJSON]
        return try await postJSON("/api/video-script/store/save", body: body)
    }

    /// 获取用户脚本列表
    func videoScriptStoreList() async throws -> VideoScriptStoreListResponse {
        try await get("/api/video-script/stores")
    }

    /// 获取脚本详情
    func videoScriptStoreDetail(id: String) async throws -> VideoScriptStoreDetailResponse {
        try await get("/api/video-script/stores/\(id)")
    }

    /// 删除脚本
    func videoScriptDelete(id: String) async throws -> VideoScriptDeleteResponse {
        try await postJSON("/api/video-script/stores/\(id)", body: ["_method": "DELETE"] as [String: Any])
    }

    // MARK: Share

    /// 生成分享链接
    func videoScriptShare(id: String) async throws -> VideoScriptShareResponse {
        let body: [String: String] = ["id": id]
        return try await postJSON("/api/video-script/share", body: body)
    }

    /// 通过 token 导入他人的脚本
    func videoScriptImport(token: String) async throws -> VideoScriptImportResponse {
        let body: [String: String] = ["token": token]
        return try await postJSON("/api/video-script/share/\(token)", body: body)
    }
}
