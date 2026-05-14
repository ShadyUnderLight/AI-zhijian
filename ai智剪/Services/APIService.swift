import Foundation
import AppKit

// MARK: - Data Models

struct LoginResponse: Codable {
    let success: Bool
    let role: String?
    let username: String?
    let message: String?
}

struct CheckResponse: Codable {
    let authenticated: Bool
    let username: String?
    let role: String?
    let userId: Int?
    let contentAuditPermission: Bool?
}

struct TaskSubmitResponse: Codable {
    let success: Bool
    let ourTaskId: String?
    let rhTaskId: String?
    let tasks: [TaskInfo]?
    let taskId: String?
    let priceUsd: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success, ourTaskId, rhTaskId, tasks, taskId, priceUsd, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        ourTaskId = try container.decodeIfPresent(String.self, forKey: .ourTaskId)
        rhTaskId = try container.decodeIfPresent(String.self, forKey: .rhTaskId)
        tasks = try container.decodeIfPresent([TaskInfo].self, forKey: .tasks)
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        message = try container.decodeIfPresent(String.self, forKey: .message)

        if let stringVal = try? container.decodeIfPresent(String.self, forKey: .priceUsd) {
            priceUsd = stringVal
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .priceUsd) {
            priceUsd = String(describing: doubleVal)
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .priceUsd) {
            priceUsd = String(intVal)
        } else {
            priceUsd = nil
        }
    }
}

struct TaskInfo: Codable {
    let ourTaskId: String
    let rhTaskId: String?
}

struct TaskPollResponse: Codable {
    let success: Bool
    let dbStatus: String?
    let rhStatus: String?
    let status: String?
    let taskStatus: String?
    let resultUrls: [String]?
    let videoUrl: String?
    let outputUrl: String?
    let resultData: String?
    let errorMessage: String?
    let detailMessage: String?
    let ourTaskId: String?
    let rhTaskId: String?
    let message: String?
}

struct HistoryResponse: Codable {
    let data: [HistoryItem]?
    let success: Bool
}

struct HistoryItem: Codable, Identifiable {
    let serverId: Int?
    let ourTaskId: String?
    let prompt: String?
    let resultUrl: String?
    let videoUrl: String?
    let dbStatus: String?
    let createdAt: String?

    var id: String {
        if let ourTaskId { return "task-\(ourTaskId)" }
        if let serverId { return "server-\(serverId)" }
        if let resultUrl { return "result-\(resultUrl)" }
        if let videoUrl { return "video-\(videoUrl)" }
        return "created-\(createdAt ?? "unknown")-\(prompt ?? "")"
    }

    private enum CodingKeys: String, CodingKey {
        case serverId = "id"
        case ourTaskId
        case prompt
        case resultUrl
        case videoUrl
        case dbStatus
        case createdAt
    }
}

struct ApiKeyInfo: Codable {
    let id: Int
    let name: String
}

struct ApiKeyResponse: Codable {
    let success: Bool
    let apiKey: ApiKeyInfo?
    let apiKeys: [ApiKeyInfo]?
    let message: String?
}

struct SeedanceVirtualAssetConfigResponse: Codable {
    let assetApiConfigured: Bool?
    let assetAccessKeyPresent: Bool?
    let assetSecretKeyPresent: Bool?
    let cosConfigured: Bool?
}

struct SeedanceVirtualAssetGroup: Codable, Identifiable, Hashable {
    let id: Int
    let arkGroupId: String?
    let displayName: String
    let description: String?
}

struct SeedanceVirtualAssetItem: Codable, Identifiable, Hashable {
    let id: Int
    let arkAssetId: String?
    let assetUri: String?
    let displayName: String?
    let sourcePublicUrl: String?
    let lastStatus: String?

    var isActive: Bool {
        lastStatus?.lowercased() == "active"
    }
}

struct SeedanceVirtualAssetGroupListResponse: Codable {
    let success: Bool
    let items: [SeedanceVirtualAssetGroup]?
    let message: String?
}

struct SeedanceVirtualAssetItemListResponse: Codable {
    let success: Bool
    let items: [SeedanceVirtualAssetItem]?
    let message: String?
}

struct SeedanceVirtualAssetMutationResponse: Codable {
    let success: Bool
    let id: Int?
    let item: SeedanceVirtualAssetItem?
    let message: String?
}

// MARK: - Active Task

struct ActiveTask: Identifiable, Hashable {
    let id: String
    let type: String
    let desc: String
    let startTime: Date
    
    var elapsed: String {
        let s = Int(Date().timeIntervalSince(startTime))
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m\(s % 60)s"
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case notLoggedIn
    case requestFailed(String)
    case invalidURL
    case decodeFailed
    
    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "未登录"
        case .requestFailed(let m): return m
        case .invalidURL: return "无效请求地址"
        case .decodeFailed: return "数据解析失败"
        }
    }
}

enum AppConfig {
    static var apiBaseURL: URL {
        if let envValue = ProcessInfo.processInfo.environment["AI_ZHIJIAN_API_BASE_URL"],
           let url = URL(string: envValue),
           url.scheme == "https" || url.host == "localhost" || url.host == "127.0.0.1" {
            return url
        }

        return URL(string: "http://43.139.67.8:7777")!
    }
}

enum ExternalURL {
    static func sanitizedURL(_ rawValue: String) -> URL? {
        guard let url = URL(string: rawValue),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || isAllowedHTTP(url) else {
            return nil
        }

        return url
    }

    static func open(_ rawValue: String) {
        guard let url = sanitizedURL(rawValue) else { return }

        NSWorkspace.shared.open(url)
    }

    private static func isAllowedHTTP(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "http" else { return false }
        return url.host == "localhost" || url.host == "127.0.0.1" || url.host == AppConfig.apiBaseURL.host
    }
}

// MARK: - Persistence Keys

private enum CachedKey {
    static let username = "cached_username"
    static let role = "cached_role"
    static let userId = "cached_userId"
    static let rememberLogin = "remember_login"
}

// MARK: - APIService

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = AppConfig.apiBaseURL
    private let session: URLSession
    
    @Published var isLoggedIn = false
    @Published var username = ""
    @Published var role = ""
    @Published var userId = 0
    @Published var activeTasks: [ActiveTask] = []
    @Published var isLoggingIn = false
    @Published var loginError: String?
    @Published var isCheckingSession = true
    @Published var rememberLogin = UserDefaults.standard.bool(forKey: CachedKey.rememberLogin) {
        didSet {
            UserDefaults.standard.set(rememberLogin, forKey: CachedKey.rememberLogin)
            if !rememberLogin {
                savedLoginCredentialsCache = nil
                CredentialStore.delete()
            }
        }
    }
    private var hasCheckedSession = false
    private var savedLoginCredentialsCache: SavedLoginCredentials?

    var cachedUsername: String {
        savedLoginCredentials?.username ?? UserDefaults.standard.string(forKey: CachedKey.username) ?? ""
    }

    var cachedPassword: String {
        savedLoginCredentials?.password ?? ""
    }

    var savedLoginCredentials: SavedLoginCredentials? {
        guard rememberLogin else { return nil }
        if let savedLoginCredentialsCache {
            return savedLoginCredentialsCache
        }

        savedLoginCredentialsCache = CredentialStore.load()
        return savedLoginCredentialsCache
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 180
        session = URLSession(configuration: config)

        username = UserDefaults.standard.string(forKey: CachedKey.username) ?? ""
        role = UserDefaults.standard.string(forKey: CachedKey.role) ?? ""
        userId = UserDefaults.standard.integer(forKey: CachedKey.userId)
    }
    
    // MARK: - Auth

    func checkSessionStatus() async {
        guard !hasCheckedSession else { return }
        hasCheckedSession = true
        defer { isCheckingSession = false }

        do {
            let result = try await check(timeout: 5)
            if result.authenticated {
                self.username = result.username ?? ""
                self.role = result.role ?? "USER"
                self.userId = result.userId ?? 0
                self.isLoggedIn = true
                saveUserInfoToCache()
            } else {
                await loginWithSavedCredentialsOrReset()
            }
        } catch APIError.notLoggedIn {
            await loginWithSavedCredentialsOrReset()
        } catch is CancellationError {
            hasCheckedSession = false
        } catch {
            // Network error, decode failure, timeout, etc.
            // Keep cookies/cache; user will see login page and can retry
        }
    }

    func login(username: String, password: String, rememberLogin: Bool? = nil) async {
        isLoggingIn = true
        loginError = nil
        defer { isLoggingIn = false }
        
        let body = ["username": username, "password": password]
        do {
            let result = try await postJSON("/api/auth/login", body: body) as LoginResponse
            if result.success {
                let checkResult = try? await check()
                self.username = checkResult?.username ?? username
                self.role = checkResult?.role ?? result.role ?? "USER"
                self.userId = checkResult?.userId ?? 0
                self.isLoggedIn = true
                saveUserInfoToCache()
                if let rememberLogin {
                    self.rememberLogin = rememberLogin
                }
                updateSavedCredentials(username: username, password: password)
            } else {
                loginError = result.message ?? "登录失败"
            }
        } catch {
            loginError = error.localizedDescription
        }
    }
    
    func logout() async {
        let _ = try? await postJSON("/api/auth/logout", body: [String: String]()) as EmptyResponse
        resetAuthState(clearCache: true)
        rememberLogin = false
    }
    
    @discardableResult
    func check(timeout: TimeInterval = 30) async throws -> CheckResponse {
        var req = URLRequest(url: try makeURL(path: "/api/auth/check"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = timeout
        return try await perform(req)
    }
    
    // MARK: - Image Generation
    
    func generateImage(prompt: String, channel: String, aspectRatio: String,
                       resolution: String, quality: String, photoReal: Bool) async throws -> TaskSubmitResponse {
        let prompt = try normalizedPrompt(prompt)
        var body: [String: Any] = [
            "prompt": prompt,
            "channel": channel,
            "aspectRatio": aspectRatio,
            "photoReal": photoReal
        ]
        if channel == "official" {
            body["resolution"] = resolution
            body["quality"] = quality
        }
        return try await postJSON("/api/gpt-image-2/text-to-image", body: body)
    }

    func generateImageToImage(prompt: String, channel: String, aspectRatio: String,
                              resolution: String, quality: String,
                              referenceImages: [FileRef]) async throws -> TaskSubmitResponse {
        let prompt = try normalizedPrompt(prompt)
        guard !referenceImages.isEmpty else {
            throw APIError.requestFailed("请先选择参考图片")
        }
        guard referenceImages.count <= 10 else {
            throw APIError.requestFailed("参考图片最多 10 张")
        }

        var fields: [(String, String)] = [
            ("prompt", prompt),
            ("channel", channel),
            ("aspectRatio", aspectRatio)
        ]
        if channel == "official" {
            fields.append(("resolution", resolution))
            fields.append(("quality", quality))
        }
        let files = referenceImages.map { ("files", $0.name, $0.mime, $0.data) }
        let (data, _) = try await uploadMultipart("/api/gpt-image-2/image-to-image", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }
    
    func pollImageTask(_ taskId: String) async throws -> TaskPollResponse {
        return try await get("/api/gpt-image-2/poll", params: ["ourTaskId": taskId])
    }
    
    func getImageHistory(page: Int = 0, size: Int = 20) async throws -> HistoryResponse {
        return try await get("/api/gpt-image-2/history", params: ["page": "\(page)", "size": "\(size)"])
    }
    
    // MARK: - Banana Image
    
    func generateBanana(prompt: String, provider: String,
                        referenceImages: [FileRef]) async throws -> Data? {
        let prompt = try normalizedPrompt(prompt)
        guard referenceImages.count <= 3 else {
            throw APIError.requestFailed("Banana 最多支持 3 张参考图")
        }
        let fields: [(String, String)] = [
            ("prompt", prompt),
            ("provider", provider)
        ]
        let files = referenceImages.map { ("image", $0.name, $0.mime, $0.data) }
        let (data, ct) = try await uploadMultipart("/api/media/banana", fields: fields, files: files)
        if ct?.contains("image") == true {
            return data
        }
        if let data, let json = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data), !json.success {
            throw APIError.requestFailed(json.message ?? "生成失败")
        }
        return nil
    }
    
    // MARK: - Seedance Video
    
    func generateSeedanceVideo(prompt: String, mode: String, model: String,
                                ratio: String, resolution: String, duration: Int,
                                count: Int, generateAudio: Bool,
                                assets: [SeedanceAsset]) async throws -> TaskSubmitResponse {
        let prompt = try normalizedOptionalPrompt(prompt, allowEmpty: !assets.isEmpty)
        var payloadAssets: [[String: Any]] = []
        for asset in assets {
            payloadAssets.append([
                "type": asset.type,
                "name": asset.name,
                "mime": asset.mime,
                "size": asset.size,
                "duration": asset.duration,
                "dataUrl": try asset.encodedDataURL()
            ])
        }
        let body: [String: Any] = [
            "prompt": prompt,
            "mode": mode,
            "model": model,
            "ratio": ratio,
            "resolution": resolution,
            "duration": duration,
            "count": count,
            "generateAudio": generateAudio,
            "assets": payloadAssets
        ]
        return try await postJSON("/api/seedance20/submit", body: body)
    }
    
    func pollSeedanceTask(_ taskId: String) async throws -> TaskPollResponse {
        return try await get("/api/seedance20/poll", params: ["ourTaskId": taskId])
    }
    
    func getSeedanceHistory(page: Int = 0, size: Int = 20) async throws -> HistoryResponse {
        return try await get("/api/seedance20/history", params: ["page": "\(page)", "size": "\(size)"])
    }

    func getSeedanceVirtualAssetConfig() async throws -> SeedanceVirtualAssetConfigResponse {
        return try await get("/api/seedance20/virtual-assets/config")
    }

    func getSeedanceVirtualAssetGroups() async throws -> SeedanceVirtualAssetGroupListResponse {
        return try await get("/api/seedance20/virtual-assets/groups")
    }

    func createSeedanceVirtualAssetGroup(displayName: String) async throws -> SeedanceVirtualAssetMutationResponse {
        let body: [String: Any] = [
            "displayName": displayName,
            "description": ""
        ]
        return try await postJSON("/api/seedance20/virtual-assets/groups", body: body)
    }

    func getSeedanceVirtualAssetItems(groupId: Int) async throws -> SeedanceVirtualAssetItemListResponse {
        return try await get("/api/seedance20/virtual-assets/groups/\(groupId)/items")
    }

    func refreshSeedanceVirtualAssetItem(localId: Int) async throws -> SeedanceVirtualAssetMutationResponse {
        return try await postJSON("/api/seedance20/virtual-assets/items/\(localId)/refresh", body: [String: String]())
    }

    func importSeedanceVirtualAssetImage(groupId: Int, displayName: String, image: FileRef) async throws -> SeedanceVirtualAssetMutationResponse {
        let body: [String: Any] = [
            "displayName": displayName,
            "dataUrl": "data:\(image.mime);base64,\(image.data.base64EncodedString())"
        ]
        return try await postJSON("/api/seedance20/virtual-assets/groups/\(groupId)/import-image", body: body)
    }
    
    // MARK: - Wan Video
    
    func generateWanVideo(imageData: Data, fileName: String, mimeType: String,
                          prompt: String, width: Int, height: Int, seconds: Int) async throws -> TaskSubmitResponse {
        let prompt = try normalizedPrompt(prompt)
        let fields: [(String, String)] = [
            ("text", prompt),
            ("width", "\(width)"),
            ("height", "\(height)"),
            ("seconds", "\(seconds)")
        ]
        let files = [("image", fileName, mimeType, imageData)]
        let (data, _) = try await uploadMultipart("/api/media/wan2-image-to-video", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    func generateWanFirstLastVideo(firstFrame: FileRef, lastFrame: FileRef,
                                   prompt: String, seconds: Int, enable48G: Bool) async throws -> TaskSubmitResponse {
        let prompt = try normalizedOptionalPrompt(prompt, allowEmpty: true)
        let fields: [(String, String)] = [
            ("text", prompt),
            ("seconds", "\(seconds)"),
            ("enable48G", enable48G ? "true" : "false")
        ]
        let files = [
            ("firstFrame", firstFrame.name, firstFrame.mime, firstFrame.data),
            ("lastFrame", lastFrame.name, lastFrame.mime, lastFrame.data)
        ]
        let (data, _) = try await uploadMultipart("/api/media/wan2-first-last-frame", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    func pollMediaTask(_ taskId: String) async throws -> TaskPollResponse {
        let fields = [("taskId", taskId)]
        let (data, _) = try await uploadMultipart("/api/media/task-result", fields: fields, files: [])
        guard let data, let result = try? JSONDecoder().decode(TaskPollResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }
    
    // MARK: - Veo Video
    
    func generateVeoVideo(params: VeoParams) async throws -> TaskSubmitResponse {
        let prompt = try normalizedOptionalPrompt(params.prompt, allowEmpty: params.mode == "extend")
        var fields: [(String, String)] = [
            ("channel", params.channel),
            ("model", params.model),
            ("mode", params.mode),
            ("prompt", prompt),
            ("resolution", params.resolution)
        ]
        if params.mode != "reference" && params.mode != "extend" {
            fields.append(("aspectRatio", params.aspectRatio))
        }
        if params.shouldSendDuration {
            fields.append(("duration", params.duration))
        }
        if let np = params.negativePrompt, !np.isEmpty { fields.append(("negativePrompt", np)) }
        if let audioValue = params.generateAudioValue {
            fields.append(("generateAudio", audioValue))
        }
        
        var files: [(String, String, String, Data)] = []
        if !params.imageFiles.isEmpty {
            for (index, file) in params.imageFiles.prefix(3).enumerated() {
                files.append((index == 0 ? "image" : "image\(index + 1)", file.name, file.mime, file.data))
            }
        } else if let d = params.imageData, let n = params.imageName, let m = params.imageMime {
            files.append(("image", n, m, d))
        }
        if let d = params.firstImageData, let n = params.firstImageName, let m = params.firstImageMime {
            files.append(("firstImage", n, m, d))
        }
        if let d = params.lastImageData, let n = params.lastImageName, let m = params.lastImageMime {
            files.append(("lastImage", n, m, d))
        }
        for (i, ref) in [params.ref1Data, params.ref2Data, params.ref3Data].enumerated() {
            if let d = ref?.data, let n = ref?.name, let m = ref?.mime {
                files.append(("refImage\(i + 1)", n, m, d))
            }
        }
        if let d = params.videoData, let n = params.videoName, let m = params.videoMime {
            files.append(("video", n, m, d))
        }
        
        let (data, _) = try await uploadMultipart("/api/veo-video/submit", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }
    
    func pollVeoTask(_ taskId: String) async throws -> TaskPollResponse {
        return try await get("/api/veo-video/poll", params: ["ourTaskId": taskId])
    }
    
    // MARK: - Grok Video
    
    func generateGrokVideo(prompt: String, channel: String, mode: String,
                           aspectRatio: String, resolution: String, duration: String,
                           imageFiles: [(Data, String, String)],
                           videoData: Data?, videoName: String?, videoMime: String?) async throws -> TaskSubmitResponse {
        let prompt = try normalizedPrompt(prompt)
        let fields: [(String, String)] = [
            ("prompt", prompt),
            ("channel", channel),
            ("mode", mode),
            ("aspectRatio", aspectRatio),
            ("resolution", resolution),
            ("duration", duration)
        ]
        var files: [(String, String, String, Data)] = []
        for (data, name, mime) in imageFiles {
            files.append(("images", name, mime, data))
        }
        if let vd = videoData, let vn = videoName, let vm = videoMime {
            files.append(("video", vn, vm, vd))
        }
        let (data, _) = try await uploadMultipart("/api/grok-video/submit", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }
    
    func pollGrokTask(_ taskId: String) async throws -> TaskPollResponse {
        return try await get("/api/grok-video/task/\(urlPathComponent(taskId))")
    }
    
    // MARK: - Task Management
    
    func addTask(id: String, type: String, desc: String) {
        if !activeTasks.contains(where: { $0.id == id }) {
            activeTasks.append(ActiveTask(id: id, type: type, desc: desc, startTime: Date()))
        }
    }
    
    func removeTask(id: String) {
        activeTasks.removeAll { $0.id == id }
    }
    
    // MARK: - HTTP Helpers
    
    private func get<T: Decodable>(_ path: String, params: [String: String] = [:]) async throws -> T {
        guard var components = URLComponents(url: try makeURL(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(req)
    }
    
    private func postJSON<T: Decodable>(_ path: String, body: Encodable) async throws -> T {
        var req = try makeRequest(path: path)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        return try await perform(req)
    }
    
    private func postJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var req = try makeRequest(path: path)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(req)
    }
    
    private func uploadMultipart(_ path: String,
                                  fields: [(String, String)],
                                  files: [(String, String, String, Data)]) async throws -> (Data?, String?) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        for (name, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(multipartHeaderValue(name))\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        for (name, filename, mime, data) in files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(multipartHeaderValue(name))\"; filename=\"\(multipartHeaderValue(filename))\"\r\n")
            body.append("Content-Type: \(multipartHeaderValue(mime))\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        
        var req = try makeRequest(path: path)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 120
        
        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed("无效响应")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed(errorMessage(from: data) ?? "请求失败 (\(httpResponse.statusCode))")
        }
        return (data, httpResponse.value(forHTTPHeaderField: "Content-Type"))
    }
    
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed("无效响应")
        }
        if httpResponse.statusCode == 401 {
            throw APIError.notLoggedIn
        }
        if httpResponse.statusCode == 403 {
            throw APIError.requestFailed("无权限")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed(errorMessage(from: data) ?? "请求失败 (\(httpResponse.statusCode))")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodeFailed
        }
    }

    private func makeRequest(path: String) throws -> URLRequest {
        URLRequest(url: try makeURL(path: path))
    }

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        return url
    }

    private func urlPathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func errorMessage(from data: Data) -> String? {
        if let submit = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) {
            return submit.message
        }
        if let poll = try? JSONDecoder().decode(TaskPollResponse.self, from: data) {
            return poll.message ?? poll.errorMessage
        }
        if let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(text.prefix(300))
        }
        return nil
    }

    private func multipartHeaderValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\"", with: "%22")
    }

    private func normalizedPrompt(_ prompt: String) throws -> String {
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw APIError.requestFailed("提示词不能为空")
        }
        guard normalized.count <= 8_000 else {
            throw APIError.requestFailed("提示词过长，最多 8000 个字符")
        }
        return normalized
    }

    private func normalizedOptionalPrompt(_ prompt: String, allowEmpty: Bool) throws -> String {
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !allowEmpty {
            guard !normalized.isEmpty else {
                throw APIError.requestFailed("提示词不能为空")
            }
        }
        guard normalized.count <= 8_000 else {
            throw APIError.requestFailed("提示词过长，最多 8000 个字符")
        }
        return normalized
    }

    private func resetAuthState(clearCache: Bool = false) {
        clearCookies()
        isLoggedIn = false
        username = ""
        role = ""
        userId = 0
        activeTasks = []
        if clearCache {
            clearCachedUserInfo()
        }
    }

    private func clearCookies() {
        session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
    }

    private func loginWithSavedCredentialsOrReset() async {
        guard let credentials = savedLoginCredentials else {
            resetAuthState(clearCache: true)
            return
        }

        await login(username: credentials.username, password: credentials.password)

        if !isLoggedIn {
            resetAuthState(clearCache: true)
            rememberLogin = false
        }
    }

    private func updateSavedCredentials(username: String, password: String) {
        if rememberLogin {
            let credentials = SavedLoginCredentials(username: username, password: password)
            savedLoginCredentialsCache = CredentialStore.save(credentials) ? credentials : nil
        } else {
            savedLoginCredentialsCache = nil
            CredentialStore.delete()
        }
    }

    private func saveUserInfoToCache() {
        UserDefaults.standard.set(username, forKey: CachedKey.username)
        UserDefaults.standard.set(role, forKey: CachedKey.role)
        UserDefaults.standard.set(userId, forKey: CachedKey.userId)
    }

    private func clearCachedUserInfo() {
        UserDefaults.standard.removeObject(forKey: CachedKey.username)
        UserDefaults.standard.removeObject(forKey: CachedKey.role)
        UserDefaults.standard.removeObject(forKey: CachedKey.userId)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

// MARK: - Veo Params

struct VeoParams {
    var channel = "budget"
    var model = "fast"
    var mode = "text"
    var prompt = ""
    var aspectRatio = "9:16"
    var resolution = "720p"
    var duration = "4"
    var generateAudio = false
    var negativePrompt: String?
    
    var imageData: Data?
    var imageName: String?
    var imageMime: String?
    var imageFiles: [FileRef] = []
    
    var firstImageData: Data?
    var firstImageName: String?
    var firstImageMime: String?
    var lastImageData: Data?
    var lastImageName: String?
    var lastImageMime: String?
    
    var ref1Data: (data: Data, name: String, mime: String)?
    var ref2Data: (data: Data, name: String, mime: String)?
    var ref3Data: (data: Data, name: String, mime: String)?
    
    var videoData: Data?
    var videoName: String?
    var videoMime: String?

    var shouldSendDuration: Bool {
        if channel == "budget" {
            return mode != "reference" && mode != "extend"
        }
        if model == "lite" && mode == "start_end" {
            return false
        }
        return mode != "reference" && mode != "extend"
    }

    var generateAudioValue: String? {
        guard channel == "official", model != "lite", mode != "extend" else { return nil }
        return generateAudio ? "true" : "false"
    }
}

struct SeedanceAsset {
    let type: String
    let name: String
    let mime: String
    let size: Int
    let duration: Double
    private let data: Data?
    private let dataUrl: String?

    init(type: String, data: Data, name: String, mime: String, duration: Double) {
        self.type = type
        self.name = name
        self.mime = mime
        self.size = data.count
        self.duration = duration
        self.data = data
        self.dataUrl = nil
    }

    init(type: String, name: String, mime: String, size: Int, duration: Double, dataUrl: String) {
        self.type = type
        self.name = name
        self.mime = mime
        self.size = size
        self.duration = duration
        self.data = nil
        self.dataUrl = dataUrl
    }

    func encodedDataURL() throws -> String {
        if let dataUrl { return dataUrl }
        guard let data else {
            throw APIError.requestFailed("素材数据为空")
        }
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }
}

// MARK: - Empty types for no-body requests

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}

// MARK: - Data helper

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
