import Foundation

// MARK: - Storyboard Response Types

struct StoryboardSceneResponse: Codable {
    let sceneIndex: Int
    let prompt: String
    let ourTaskId: String
}

struct StoryboardGenerateResponse: Codable {
    let success: Bool
    let taskId: String?
    let scenes: [StoryboardSceneResponse]?
    let message: String?
}

struct StoryboardHDGenerateResponse: Codable {
    let success: Bool
    let taskId: String?
    let scenes: [StoryboardSceneResponse]?
    let message: String?
}

// MARK: - GPT-Image-2 Storyboard API

extension APIService {

    /// 标准故事板：上传产品参考图 → LLM 生成提示词 → 批量图生图
    func generateStoryboard(
        productImage: FileRef,
        prompt: String?,
        productDescription: String?,
        shotCount: Int,
        channel: String,
        resolution: String,
        resolutionLevel: String,
        llmProvider: String,
        imageModel: String
    ) async throws -> StoryboardGenerateResponse {
        var fields: [(String, String)] = [
            ("shotCount", "\(shotCount)"),
            ("mode", "standard"),
            ("channel", channel),
            ("resolution", resolution),
            ("resolutionLevel", resolutionLevel),
            ("llmProvider", llmProvider),
            ("imageModel", imageModel)
        ]
        if let prompt, !prompt.isEmpty {
            fields.append(("prompt", prompt))
        }
        if let productDescription, !productDescription.isEmpty {
            fields.append(("productDescription", productDescription))
        }

        let files: [(String, String, String, Data)] = [
            ("productImage", productImage.name, productImage.mime, productImage.data)
        ]

        let (data, _) = try await uploadMultipart("/api/gpt-image-2/storyboard/generate", fields: fields, files: files)
        guard let data else {
            throw APIError.requestFailed("未返回数据")
        }
        guard let result = try? JSONDecoder().decode(StoryboardGenerateResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// 高密度故事板：仅 Gemini 多模态生成，每段落固定 6 个镜头
    func generateHDStoryboard(
        productImage: FileRef,
        productDescription: String,
        segmentCount: Int,
        channel: String,
        resolution: String,
        imageModel: String
    ) async throws -> StoryboardHDGenerateResponse {
        var fields: [(String, String)] = [
            ("productDescription", productDescription),
            ("segmentCount", "\(segmentCount)"),
            ("mode", "hd"),
            ("channel", channel),
            ("resolution", resolution),
            ("imageModel", imageModel)
        ]

        let files: [(String, String, String, Data)] = [
            ("productImage", productImage.name, productImage.mime, productImage.data)
        ]

        let (data, _) = try await uploadMultipart("/api/gpt-image-2/storyboard/hd-generate", fields: fields, files: files)
        guard let data else {
            throw APIError.requestFailed("未返回数据")
        }
        guard let result = try? JSONDecoder().decode(StoryboardHDGenerateResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }
}
