import Foundation

// MARK: - Text→Image→Video Response Types

struct TextImageVideoScriptResponse: Codable {
    let success: Bool
    let script: String?
    let message: String?
}

struct TextImageVideoUploadResponse: Codable {
    let success: Bool
    let url: String?
    let message: String?
}

struct TextImageVideoArchiveResponse: Codable {
    let success: Bool
    let taskId: String?
    let message: String?
}

struct TextImageVideoExportResponse: Codable {
    let success: Bool
    let videoUrl: String?
    let taskId: String?
    let message: String?
}

// MARK: - Text→Image→Video Workflow API

extension APIService {

    /// 生成文→图→视频脚本
    func generateTextImageVideoScript(prompt: String) async throws -> TextImageVideoScriptResponse {
        let body: [String: Any] = ["prompt": prompt]
        return try await postJSON("/api/text-image-video/generate-script", body: body)
    }

    /// 上传图片素材
    func uploadTextImageVideoImage(imageData: Data, imageName: String, imageMime: String) async throws -> TextImageVideoUploadResponse {
        let fields: [(String, String)] = []
        let files: [(String, String, String, Data)] = [
            ("image", imageName, imageMime, imageData)
        ]
        let (data, _) = try await uploadMultipart("/api/text-image-video/upload-image", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TextImageVideoUploadResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// 上传视频素材
    func uploadTextImageVideoVideo(videoData: Data, videoName: String, videoMime: String) async throws -> TextImageVideoUploadResponse {
        let fields: [(String, String)] = []
        let files: [(String, String, String, Data)] = [
            ("video", videoName, videoMime, videoData)
        ]
        let (data, _) = try await uploadMultipart("/api/text-image-video/upload-video", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TextImageVideoUploadResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// 归档视频
    func archiveTextImageVideo(videoUrl: String) async throws -> TextImageVideoArchiveResponse {
        let body: [String: Any] = ["videoUrl": videoUrl]
        return try await postJSON("/api/text-image-video/archive-video", body: body)
    }

    /// 导出最终视频
    func exportTextImageVideo() async throws -> TextImageVideoExportResponse {
        let body: [String: String] = [:]
        return try await postJSON("/api/text-image-video/export", body: body)
    }

    /// 代理拉取图片（返回原始图片数据）
    func proxyTextImageVideoImage(url: String) async throws -> Data {
        guard var components = URLComponents(url: AppConfig.apiBaseURL.appendingPathComponent("/api/text-image-video/proxy-image"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "url", value: url)]
        guard let finalURL = components.url else { throw APIError.invalidURL }
        var req = URLRequest(url: finalURL)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let session = URLSession.shared
        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed("无效响应")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed("代理拉取图片失败 (\(httpResponse.statusCode))")
        }
        return data
    }
}
