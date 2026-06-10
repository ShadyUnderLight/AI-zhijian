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

struct PreflightResponse: Decodable {
    let success: Bool
    let estimatedPriceUsd: String?
    let estimatedDurationSeconds: Int?
    let balanceSufficient: Bool?
    let blockingReasons: [String]?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success, estimatedPriceUsd, estimatedDurationSeconds, balanceSufficient, blockingReasons, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        balanceSufficient = try container.decodeIfPresent(Bool.self, forKey: .balanceSufficient)
        blockingReasons = try container.decodeIfPresent([String].self, forKey: .blockingReasons)
        message = try container.decodeIfPresent(String.self, forKey: .message)

        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .estimatedDurationSeconds) {
            estimatedDurationSeconds = intVal
        } else if let stringVal = try? container.decodeIfPresent(String.self, forKey: .estimatedDurationSeconds) {
            estimatedDurationSeconds = Int(stringVal)
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .estimatedDurationSeconds) {
            estimatedDurationSeconds = Int(doubleVal)
        } else {
            estimatedDurationSeconds = nil
        }

        if let stringVal = try? container.decodeIfPresent(String.self, forKey: .estimatedPriceUsd) {
            estimatedPriceUsd = stringVal
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .estimatedPriceUsd) {
            estimatedPriceUsd = String(intVal)
        } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .estimatedPriceUsd) {
            estimatedPriceUsd = String(doubleVal)
        } else {
            estimatedPriceUsd = nil
        }
    }
}

struct TaskInfo: Codable {
    let ourTaskId: String
    let rhTaskId: String?
}

enum ActiveTaskPollKind: String, Hashable {
    case image
    case seedance
    case veo
    case grok
    case wan
    case media
}

struct TaskPollResponse: Decodable {
    let success: Bool
    let dbStatus: String?
    let rhStatus: String?
    let status: String?
    let taskStatus: String?
    let resultUrls: [String]?
    let imageUrl: String?
    let resultUrl: String?
    let url: String?
    let videoUrl: String?
    let outputUrl: String?
    let resultData: String?
    let errorMessage: String?
    let detailMessage: String?
    let ourTaskId: String?
    let rhTaskId: String?
    let message: String?
    private let extraImageUrls: [String]
    private let extraVideoUrls: [String]

    enum CodingKeys: String, CodingKey {
        case success
        case dbStatus
        case rhStatus
        case status
        case taskStatus
        case resultUrls
        case imageUrls
        case imageUrl
        case resultUrl
        case url
        case urls
        case images
        case videoUrl
        case outputUrl
        case fileUrl
        case downloadUrl
        case mediaUrl
        case resultData
        case errorMessage
        case detailMessage
        case ourTaskId
        case rhTaskId
        case message
        case result
        case data
        case output
        case db_status
        case rh_status
        case task_status
        case result_urls
        case image_urls
        case image_url
        case result_url
        case video_url
        case output_url
        case file_url
        case download_url
        case media_url
        case result_data
        case error_message
        case detail_message
        case our_task_id
        case rh_task_id
    }

    init(success: Bool, dbStatus: String?, rhStatus: String?, status: String?, taskStatus: String?,
         resultUrls: [String]?, imageUrl: String? = nil, resultUrl: String? = nil, url: String? = nil,
         videoUrl: String?, outputUrl: String?, resultData: String?, errorMessage: String?,
         detailMessage: String?, ourTaskId: String?, rhTaskId: String?, message: String?,
         extraImageUrls: [String] = [], extraVideoUrls: [String] = []) {
        self.success = success
        self.dbStatus = dbStatus
        self.rhStatus = rhStatus
        self.status = status
        self.taskStatus = taskStatus
        self.resultUrls = resultUrls
        self.imageUrl = imageUrl
        self.resultUrl = resultUrl
        self.url = url
        self.videoUrl = videoUrl
        self.outputUrl = outputUrl
        self.resultData = resultData
        self.errorMessage = errorMessage
        self.detailMessage = detailMessage
        self.ourTaskId = ourTaskId
        self.rhTaskId = rhTaskId
        self.message = message
        self.extraImageUrls = extraImageUrls
        self.extraVideoUrls = extraVideoUrls
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? true
        dbStatus = Self.decodeFirstString(c, keys: [.dbStatus, .db_status])
        rhStatus = Self.decodeFirstString(c, keys: [.rhStatus, .rh_status])
        status = Self.decodeFirstString(c, keys: [.status])
        taskStatus = Self.decodeFirstString(c, keys: [.taskStatus, .task_status])
        resultUrls = Self.decodeFirstStringArray(c, keys: [.resultUrls, .result_urls, .imageUrls, .image_urls, .urls, .images])
        imageUrl = Self.decodeFirstString(c, keys: [.imageUrl, .image_url])
        resultUrl = Self.decodeFirstString(c, keys: [.resultUrl, .result_url])
        url = Self.decodeFirstString(c, keys: [.url])
        videoUrl = Self.decodeFirstString(c, keys: [.videoUrl, .video_url])
        outputUrl = Self.decodeFirstString(c, keys: [.outputUrl, .output_url])
        resultData = Self.decodeFirstString(c, keys: [.resultData, .result_data])
        errorMessage = Self.decodeFirstString(c, keys: [.errorMessage, .error_message])
        detailMessage = Self.decodeFirstString(c, keys: [.detailMessage, .detail_message])
        ourTaskId = Self.decodeFirstString(c, keys: [.ourTaskId, .our_task_id])
        rhTaskId = Self.decodeFirstString(c, keys: [.rhTaskId, .rh_task_id])
        message = Self.decodeFirstString(c, keys: [.message])

        var nestedImageUrls: [String] = []
        var nestedVideoUrls: [String] = []
        for key in [CodingKeys.result, .data, .output] {
            if let nested = try? c.nestedContainer(keyedBy: CodingKeys.self, forKey: key) {
                let ambiguousUrls = Self.decodeFirstStringArray(nested, keys: [.resultUrls, .result_urls, .urls]) ?? []
                nestedImageUrls += ambiguousUrls
                nestedVideoUrls += ambiguousUrls
                nestedImageUrls += Self.decodeFirstStringArray(nested, keys: [.imageUrls, .image_urls, .images]) ?? []
                nestedImageUrls += [
                    Self.decodeFirstString(nested, keys: [.imageUrl, .image_url]),
                    Self.decodeFirstString(nested, keys: [.resultUrl, .result_url]),
                    Self.decodeFirstString(nested, keys: [.url])
                ].compactMap { $0 }
                nestedVideoUrls += [
                    Self.decodeFirstString(nested, keys: [.resultUrl, .result_url]),
                    Self.decodeFirstString(nested, keys: [.url]),
                    Self.decodeFirstString(nested, keys: [.videoUrl, .video_url]),
                    Self.decodeFirstString(nested, keys: [.outputUrl, .output_url]),
                    Self.decodeFirstString(nested, keys: [.fileUrl, .file_url]),
                    Self.decodeFirstString(nested, keys: [.downloadUrl, .download_url]),
                    Self.decodeFirstString(nested, keys: [.mediaUrl, .media_url])
                ].compactMap { $0 }
            }
        }
        let topLevelFileUrls = [
            Self.decodeFirstString(c, keys: [.fileUrl, .file_url]),
            Self.decodeFirstString(c, keys: [.downloadUrl, .download_url]),
            Self.decodeFirstString(c, keys: [.mediaUrl, .media_url])
        ].compactMap { $0 }
        extraImageUrls = nestedImageUrls + topLevelFileUrls
        extraVideoUrls = nestedVideoUrls + topLevelFileUrls
    }
}

extension TaskPollResponse {
    private static let successStatuses: Set<String> = ["SUCCESS", "COMPLETED", "COMPLETE", "DONE", "SUCCEEDED"]
    private static let failureStatuses: Set<String> = ["FAILED", "FAILURE", "ERROR", "CANCELED", "CANCELLED", "TIMEOUT", "EXPIRED"]

    var imageResultUrls: [String] {
        let candidates = (resultUrls ?? []) + [imageUrl, resultUrl, url, outputUrl].compactMap { $0 } + extraImageUrls + resultDataURLs
        return Self.uniqueSanitizedStrings(candidates)
    }

    var imageResultData: Data? {
        guard let resultData else { return nil }
        guard let decoded = Self.decodeImageData(resultData) else { return nil }
        guard NSImage(data: decoded) != nil else { return nil }
        return decoded
    }

    var videoResultUrl: String? {
        Self.uniqueSanitizedStrings([videoUrl, outputUrl, resultUrl, url].compactMap { $0 } + extraVideoUrls + resultDataURLs).first
    }

    func normalizedStatus(for pollKind: ActiveTaskPollKind) -> String {
        let candidates: [String?]
        switch pollKind {
        case .image, .seedance, .veo:
            candidates = [dbStatus, status, taskStatus, rhStatus]
        case .grok, .wan, .media:
            candidates = [status, taskStatus, dbStatus, rhStatus]
        }
        return candidates
            .compactMap { Self.normalizedStatusKey($0) }
            .first { !$0.isEmpty } ?? ""
    }

    func isTerminal(for pollKind: ActiveTaskPollKind) -> Bool {
        let status = normalizedStatus(for: pollKind)
        return Self.successStatuses.contains(status) || Self.failureStatuses.contains(status)
    }

    func isTerminalSuccess(for pollKind: ActiveTaskPollKind) -> Bool {
        Self.successStatuses.contains(normalizedStatus(for: pollKind))
    }

    func isTerminalFailure(for pollKind: ActiveTaskPollKind) -> Bool {
        Self.failureStatuses.contains(normalizedStatus(for: pollKind))
    }

    private var resultDataURLs: [String] {
        guard let resultData else { return [] }
        let trimmed = resultData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return [trimmed]
        }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return [] }
        return Self.urlStrings(in: object)
    }

    private static func uniqueSanitizedStrings(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        var urls: [String] = []
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, ExternalURL.sanitizedURL(trimmed) != nil else { continue }
            if seen.insert(trimmed).inserted {
                urls.append(trimmed)
            }
        }
        return urls
    }

    private static func normalizedStatusKey(_ raw: String?) -> String? {
        raw?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func decodeImageData(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comma = trimmed.firstIndex(of: ","),
           trimmed[..<comma].lowercased().contains("base64") {
            return Data(base64Encoded: String(trimmed[trimmed.index(after: comma)...]), options: .ignoreUnknownCharacters)
        }
        guard !trimmed.hasPrefix("{"), !trimmed.hasPrefix("[") else { return nil }
        return Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters)
    }

    private static func decodeFirstString(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> String? {
        for key in keys {
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    private static func decodeFirstStringArray(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> [String]? {
        for key in keys {
            if let array = try? container.decodeIfPresent([String].self, forKey: key) {
                return array
            }
            if let string = try? container.decodeIfPresent(String.self, forKey: key) {
                return [string]
            }
        }
        return nil
    }

    private static func urlStrings(in object: Any) -> [String] {
        if let string = object as? String {
            return [string]
        }
        if let array = object as? [Any] {
            return array.flatMap(urlStrings)
        }
        if let dict = object as? [String: Any] {
            let urlKeys = Set([
                "url", "urls", "imageUrl", "image_url", "imageUrls", "image_urls",
                "resultUrl", "result_url", "resultUrls", "result_urls",
                "videoUrl", "video_url", "outputUrl", "output_url",
                "fileUrl", "file_url", "downloadUrl", "download_url", "mediaUrl", "media_url"
            ])
            return dict.flatMap { key, value -> [String] in
                urlKeys.contains(key) ? urlStrings(in: value) : []
            }
        }
        return []
    }
}

struct BananaGenerateResponse: Codable {
    let success: Bool?
    let message: String?
    let imageUrl: String?
    let resultUrl: String?
    let url: String?
    let resultUrls: [String]?
    let dataUrl: String?
    let imageData: String?
    let resultData: String?
    let base64: String?
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

// MARK: - Media Controller Models

struct EleVoiceListResponse: Codable {
    let success: Bool?
    let voices: [EleVoice]?
    let message: String?
}

struct EleVoice: Codable, Identifiable, Hashable {
    let voiceId: String
    let name: String?
    let previewUrl: String?
    let category: String?
    let labels: [String: String]?

    var id: String { voiceId }
}

struct EleModelListResponse: Codable {
    let success: Bool?
    let models: [EleTTSModel]?
    let message: String?
}

struct EleTTSModel: Codable, Identifiable, Hashable {
    let modelId: String
    let name: String?
    let description: String?

    var id: String { modelId }
}

struct EleCloneResponse: Codable {
    let success: Bool?
    let voiceId: String?
    let message: String?
}

struct EleHistoryResponse: Codable {
    let success: Bool?
    let history: [EleHistoryItem]?
    let message: String?
}

struct EleHistoryItem: Codable, Identifiable {
    let historyItemId: String
    let text: String?
    let dateUnix: Int?
    let characterId: String?
    let voiceId: String?

    var id: String { historyItemId }
}

struct MiniMaxVoiceListResponse: Codable {
    let success: Bool?
    let voices: [MiniMaxVoice]?
    let message: String?
}

struct MiniMaxVoice: Codable, Identifiable, Hashable {
    let voiceId: String
    let name: String?
    let previewAudioPath: String?

    var id: String { voiceId }
}

struct MiniMaxCloneResponse: Codable {
    let success: Bool?
    let voiceId: String?
    let message: String?
}

struct OptimizeTextResponse: Codable {
    let success: Bool?
    let optimizedText: String?
    let message: String?
}

struct SimpleResponse: Codable {
    let success: Bool
    let message: String?

    init(success: Bool, message: String?) {
        self.success = success
        self.message = message
    }
}

// MARK: - HeyGen Response Types

struct HeyGenAccountResponse: Codable {
    let success: Bool
    let message: String?
    let data: HeyGenAccountData?
}

struct HeyGenAccountData: Codable {
    let name: String?
    let email: String?
    let balance: String?
    let credits: Int?
}

struct HeyGenVoicesResponse: Codable {
    let success: Bool
    let message: String?
    let data: [HeyGenVoice]?
}

struct HeyGenVoice: Codable, Identifiable {
    let id: String
    let name: String
    let language: String?
    let gender: String?
    let previewUrl: String?
}

struct HeyGenTemplatesResponse: Codable {
    let success: Bool
    let message: String?
    let data: [HeyGenTemplate]?
}

struct HeyGenTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let previewUrl: String?
}

struct HeyGenVideoResponse: Codable {
    let success: Bool
    let message: String?
    let data: HeyGenVideoData?
}

struct HeyGenVideoData: Codable {
    let videoId: String?
    let status: String?
}

struct HeyGenVideoStatusResponse: Codable {
    let success: Bool
    let message: String?
    let data: HeyGenVideoStatusData?
}

struct HeyGenVideoStatusData: Codable {
    let videoId: String?
    let status: String?
    let videoUrl: String?
    let thumbnailUrl: String?
    let duration: Double?
    let error: String?
}

struct HeyGenDownloadResponse: Codable {
    let success: Bool
    let message: String?
    let data: HeyGenDownloadData?
}

struct HeyGenDownloadData: Codable {
    let downloadUrl: String?
}

// MARK: - Active Task

struct ActiveTask: Identifiable, Hashable {
    let id: String
    let type: String
    let desc: String
    let startTime: Date
    let pollKind: ActiveTaskPollKind?

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
    private static let customURLKey = "api_base_url_override"
    private static let defaultURLString = "http://43.139.67.8:7777"

    static func sanitizedBaseURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw),
              var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        guard comps.user == nil, comps.query == nil, comps.fragment == nil else { return nil }
        let scheme = comps.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { return nil }
        guard let host = comps.host, !host.isEmpty else { return nil }
        comps.scheme = scheme
        if comps.path.hasSuffix("/") { comps.path = String(comps.path.dropLast()) }
        return comps.url
    }

    static func setCustomBaseURL(_ urlString: String) {
        guard let sanitized = sanitizedBaseURL(urlString) else { return }
        UserDefaults.standard.set(sanitized.absoluteString, forKey: customURLKey)
    }

    static func resetCustomBaseURL() {
        UserDefaults.standard.removeObject(forKey: customURLKey)
    }

    static var currentBaseURLString: String {
        if let custom = UserDefaults.standard.string(forKey: customURLKey),
           let sanitized = sanitizedBaseURL(custom) {
            return sanitized.absoluteString
        }
        if let envValue = ProcessInfo.processInfo.environment["AI_ZHIJIAN_API_BASE_URL"],
           let sanitized = sanitizedBaseURL(envValue) {
            return sanitized.absoluteString
        }
        return defaultURLString
    }

    static var apiBaseURL: URL {
        URL(string: currentBaseURLString) ?? URL(string: defaultURLString)!
    }

    static var defaultBaseURLString: String { defaultURLString }

    static func isLoopbackHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "localhost" || host == "localhost." || host == "127.0.0.1" || host == "::1"
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

enum BackendHealthState: Equatable {
    case unknown
    case checking
    case healthy
    case reachable
    case unhealthy
    case unreachable
}

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()

    private var baseURL: URL { AppConfig.apiBaseURL }
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
    @Published var backendHealthState: BackendHealthState = .unknown
    private var healthCheckToken = 0
    private var hasCheckedSession = false
    private var savedLoginCredentialsCache: SavedLoginCredentials?

    var cachedUsername: String {
        savedLoginCredentials?.username ?? UserDefaults.standard.string(forKey: CachedKey.username) ?? ""
    }

    var cachedPassword: String {
        savedLoginCredentials?.password ?? ""
    }

    var serverDisplayOrigin: String {
        let url = AppConfig.apiBaseURL
        let scheme = url.scheme ?? "http"
        let host = url.host ?? "unknown"
        if let port = url.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }
    var serverScheme: String { AppConfig.apiBaseURL.scheme?.lowercased() ?? "http" }
    var isHTTPWithoutLocalhost: Bool {
        serverScheme == "http" && !AppConfig.isLoopbackHost(AppConfig.apiBaseURL.host)
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
#if DEBUG
        if AppRuntime.shouldSkipLoginForUITests {
            hasCheckedSession = true
            isCheckingSession = false
            isLoggedIn = true
            return
        }
        if AppRuntime.isRunningTests {
            hasCheckedSession = true
            isCheckingSession = false
            return
        }
#endif
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

    func checkBackendHealth() async {
        backendHealthState = .checking
        let currentToken = healthCheckToken + 1
        healthCheckToken = currentToken

        guard let url = URL(string: "/api/auth/check", relativeTo: AppConfig.apiBaseURL)?.absoluteURL else {
            backendHealthState = .unreachable
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 5
        do {
            let (_, response) = try await session.data(for: req)
            guard healthCheckToken == currentToken else { return }
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    backendHealthState = .healthy
                case 401, 403:
                    backendHealthState = .reachable
                default:
                    backendHealthState = .unhealthy
                }
            } else {
                backendHealthState = .unreachable
            }
        } catch {
            guard healthCheckToken == currentToken else { return }
            backendHealthState = .unreachable
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
        if let data, let banana = try? JSONDecoder().decode(BananaGenerateResponse.self, from: data) {
            if banana.success == false {
                throw APIError.requestFailed(banana.message ?? "生成失败")
            }
            if let imageData = try await bananaImageData(from: banana) {
                return imageData
            }
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
        if VeoRules.supportsAspectRatio(channel: params.channel, model: params.model, mode: params.mode) {
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
                let partName = index == 0 ? "image" : "image\(index + 1)"
                files.append(uploadFilePart(channel: params.channel, partName: partName, fallbackBaseName: "image-\(index + 1)", fileName: file.name, mime: file.mime, data: file.data))
            }
        } else if let d = params.imageData, let n = params.imageName, let m = params.imageMime {
            files.append(uploadFilePart(channel: params.channel, partName: "image", fallbackBaseName: "image-1", fileName: n, mime: m, data: d))
        }
        if let d = params.firstImageData, let n = params.firstImageName, let m = params.firstImageMime {
            files.append(uploadFilePart(channel: params.channel, partName: "firstImage", fallbackBaseName: "first-image", fileName: n, mime: m, data: d))
        }
        if let d = params.lastImageData, let n = params.lastImageName, let m = params.lastImageMime {
            files.append(uploadFilePart(channel: params.channel, partName: "lastImage", fallbackBaseName: "last-image", fileName: n, mime: m, data: d))
        }
        for (i, ref) in [params.ref1Data, params.ref2Data, params.ref3Data].enumerated() {
            if let d = ref?.data, let n = ref?.name, let m = ref?.mime {
                files.append(uploadFilePart(channel: params.channel, partName: "refImage\(i + 1)", fallbackBaseName: "ref-image-\(i + 1)", fileName: n, mime: m, data: d))
            }
        }
        if let d = params.videoData, let n = params.videoName, let m = params.videoMime {
            files.append(uploadFilePart(channel: params.channel, partName: "video", fallbackBaseName: "video", fileName: n, mime: m, data: d))
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
        for (index, file) in imageFiles.enumerated() {
            files.append(uploadFilePart(channel: channel, partName: "images", fallbackBaseName: "image-\(index + 1)", fileName: file.1, mime: file.2, data: file.0))
        }
        if let vd = videoData, let vn = videoName, let vm = videoMime {
            files.append(uploadFilePart(channel: channel, partName: "video", fallbackBaseName: "video", fileName: vn, mime: vm, data: vd))
        }
        if channel == "apimart", mode == "text", files.isEmpty {
            let body: [String: Any] = [
                "prompt": prompt,
                "channel": channel,
                "mode": mode,
                "aspectRatio": aspectRatio,
                "resolution": resolution,
                "duration": duration
            ]
            return try await postJSON("/api/grok-video/submit", body: body, timeout: 120)
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

    // MARK: - Media Controller: Voice Generation

    /// ElevenLabs / MiniMax 文本转语音提交
    func submitVoiceGen(platform: String, voiceId: String, modelId: String, text: String,
                         speed: Double, stability: Double, similarityBoost: Double, style: Double) async throws -> TaskSubmitResponse {
        let body: [String: Any] = [
            "platform": platform,
            "voiceId": voiceId,
            "modelId": modelId,
            "text": text,
            "speed": speed,
            "stability": stability,
            "similarityBoost": similarityBoost,
            "style": style
        ]
        return try await postJSON("/api/media/voice-clone", body: body)
    }

    /// ElevenLabs 获取声音列表
    func fetchElevenLabsVoices() async throws -> EleVoiceListResponse {
        return try await get("/api/media/elevenlabs/voices")
    }

    /// ElevenLabs 搜索声音
    func searchElevenLabsVoices(query: String) async throws -> EleVoiceListResponse {
        return try await get("/api/media/elevenlabs/voices/search", params: ["query": query])
    }

    /// ElevenLabs 获取 TTS 模型列表
    func fetchElevenLabsModels() async throws -> EleModelListResponse {
        return try await get("/api/media/elevenlabs/models")
    }

    /// ElevenLabs 创建语音克隆
    func createElevenLabsClone(name: String, audioData: Data, audioName: String, audioMime: String) async throws -> EleCloneResponse {
        let fields = [("name", name)]
        let files: [(String, String, String, Data)] = [(audioName.hasSuffix(".mp3") || audioName.hasSuffix(".wav") ? "files" : "files", audioName, audioMime, audioData)]
        let (data, _) = try await uploadMultipart("/api/media/elevenlabs/create-clone", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(EleCloneResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// ElevenLabs 删除声音
    func deleteElevenLabsVoice(_ voiceId: String) async throws -> SimpleResponse {
        var req = try makeRequest(path: "/api/media/elevenlabs/voices/\(urlPathComponent(voiceId))")
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: req)
        if let result = try? JSONDecoder().decode(SimpleResponse.self, from: data) {
            return result
        }
        return SimpleResponse(success: true, message: nil)
    }

    /// ElevenLabs 历史记录
    func fetchElevenLabsHistory() async throws -> EleHistoryResponse {
        return try await get("/api/media/elevenlabs/history")
    }

    /// MiniMax 声音列表
    func fetchMiniMaxVoices() async throws -> MiniMaxVoiceListResponse {
        return try await get("/api/media/minimax/voices")
    }

    /// MiniMax 异步 TTS
    func submitMiniMaxTTS(voiceId: String, text: String, speed: Double) async throws -> TaskSubmitResponse {
        let body: [String: Any] = [
            "voiceId": voiceId,
            "text": text,
            "speed": speed
        ]
        return try await postJSON("/api/media/minimax/tts-async", body: body)
    }

    /// MiniMax 查询任务状态
    func pollMiniMaxTask(_ taskId: String) async throws -> TaskPollResponse {
        return try await get("/api/media/minimax/task-status/\(urlPathComponent(taskId))")
    }

    /// MiniMax 下载音频（直接返回 Data）
    func downloadMiniMaxAudio(_ fileId: String) async throws -> Data {
        let (data, _) = try await session.data(for: makeRequest(path: "/api/media/minimax/download/\(urlPathComponent(fileId))"))
        return data
    }

    /// MiniMax 语音克隆
    func createMiniMaxClone(name: String, audioData: Data, audioName: String, audioMime: String) async throws -> MiniMaxCloneResponse {
        let fields = [("name", name)]
        let files: [(String, String, String, Data)] = [("file", audioName, audioMime, audioData)]
        let (data, _) = try await uploadMultipart("/api/media/minimax/create-clone", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(MiniMaxCloneResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// 文案优化排版
    func optimizeText(_ text: String) async throws -> OptimizeTextResponse {
        let body: [String: Any] = ["text": text]
        return try await postJSON("/api/media/optimize-text", body: body)
    }

    // MARK: - Media Controller: Transcript

    /// 提交视频文案提取任务
    func submitTranscript(videoUrl: String, language: String = "zh") async throws -> TaskSubmitResponse {
        let body: [String: Any] = [
            "videoUrl": videoUrl,
            "language": language
        ]
        return try await postJSON("/api/media/transcript-analysis", body: body)
    }

    // MARK: - Media Controller: Subtitle Remove

    /// 提交视频去字幕任务
    func submitSubtitleRemove(videoData: Data, videoName: String, videoMime: String, region: String = "full") async throws -> TaskSubmitResponse {
        let fields: [(String, String)] = [("region", region)]
        let files: [(String, String, String, Data)] = [("video", videoName, videoMime, videoData)]
        let (data, _) = try await uploadMultipart("/api/media/video-subtitle-remove", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    // MARK: - Media Controller: Background Replace

    /// 提交视频背景替换任务
    func submitBackgroundReplace(videoData: Data, videoName: String, videoMime: String,
                                  bgImageData: Data, bgImageName: String, bgImageMime: String, mode: String = "replace") async throws -> TaskSubmitResponse {
        let fields: [(String, String)] = [("mode", mode)]
        let files: [(String, String, String, Data)] = [
            ("video", videoName, videoMime, videoData),
            ("backgroundImage", bgImageName, bgImageMime, bgImageData)
        ]
        let (data, _) = try await uploadMultipart("/api/media/video-background-replace", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    // MARK: - Media Controller: Character Replace

    func submitCharacterReplace(videoData: Data, videoName: String, videoMime: String,
                                 referenceImageData: Data, referenceImageName: String, referenceImageMime: String,
                                 similarity: Double = 0.8, faceFidelity: Double = 0.9) async throws -> TaskSubmitResponse {
        let fields: [(String, String)] = [
            ("similarity", "\(similarity)"),
            ("faceFidelity", "\(faceFidelity)")
        ]
        let files: [(String, String, String, Data)] = [
            ("video", videoName, videoMime, videoData),
            ("referenceImage", referenceImageName, referenceImageMime, referenceImageData)
        ]
        let (data, _) = try await uploadMultipart("/api/media/character-replace", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    // MARK: - Media Controller: Motion Transfer

    func submitMotionTransfer(videoData: Data, videoName: String, videoMime: String,
                               targetImageData: Data, targetImageName: String, targetImageMime: String,
                               intensity: Double = 0.8, cropMode: String = "fit") async throws -> TaskSubmitResponse {
        let fields: [(String, String)] = [
            ("intensity", "\(intensity)"),
            ("cropMode", cropMode)
        ]
        let files: [(String, String, String, Data)] = [
            ("video", videoName, videoMime, videoData),
            ("targetImage", targetImageName, targetImageMime, targetImageData)
        ]
        let (data, _) = try await uploadMultipart("/api/media/motion-transfer", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    // MARK: - Media Controller: Lip Sync Image

    func submitLipSyncImage(imageData: Data, imageName: String, imageMime: String,
                             audioData: Data, audioName: String, audioMime: String,
                             accuracy: String = "high") async throws -> TaskSubmitResponse {
        let fields: [(String, String)] = [
            ("accuracy", accuracy)
        ]
        let files: [(String, String, String, Data)] = [
            ("image", imageName, imageMime, imageData),
            ("audio", audioName, audioMime, audioData)
        ]
        let (data, _) = try await uploadMultipart("/api/media/lip-sync-image", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    // MARK: - Media Controller: Video Replica

    func submitVideoReplica(videoData: Data, videoName: String, videoMime: String,
                             targetStyle: String = "同风格", duration: Int = 15, resolution: String = "720p") async throws -> TaskSubmitResponse {
        let fields: [(String, String)] = [
            ("targetStyle", targetStyle),
            ("duration", "\(duration)"),
            ("resolution", resolution)
        ]
        let files: [(String, String, String, Data)] = [
            ("video", videoName, videoMime, videoData)
        ]
        let (data, _) = try await uploadMultipart("/api/media/video-replica", fields: fields, files: files)
        guard let data, let result = try? JSONDecoder().decode(TaskSubmitResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    /// 查询视频复刻进度（独立轮询端点）
    func pollVideoReplica(_ taskId: String) async throws -> TaskPollResponse {
        return try await get("/api/media/video-replica/status", params: ["taskId": taskId])
    }

    // MARK: - HeyGen Digital Human

    func fetchHeyGenAccount() async throws -> HeyGenAccountResponse {
        return try await get("/api/heygen/account")
    }

    func fetchHeyGenVoices(search: String? = nil, language: String? = nil, gender: String? = nil) async throws -> HeyGenVoicesResponse {
        var params: [String: String] = [:]
        if let search { params["search"] = search }
        if let language { params["language"] = language }
        if let gender { params["gender"] = gender }
        return try await get("/api/heygen/voices", params: params)
    }

    func fetchHeyGenTemplates() async throws -> HeyGenTemplatesResponse {
        return try await get("/api/heygen/templates")
    }

    func createHeyGenVideo(avatarId: String, voiceId: String, language: String,
                            text: String, title: String = "", speed: Double = 1.0) async throws -> HeyGenVideoResponse {
        var body: [String: Any] = [
            "avatarId": avatarId,
            "voiceId": voiceId,
            "language": language,
            "text": text
        ]
        if !title.isEmpty { body["title"] = title }
        if speed != 1.0 { body["speed"] = speed }
        return try await postJSON("/api/heygen/video", body: body)
    }

    func pollHeyGenVideo(_ videoId: String) async throws -> HeyGenVideoStatusResponse {
        return try await get("/api/heygen/video/\(urlPathComponent(videoId))")
    }

    func downloadHeyGenVideo(_ videoId: String) async throws -> HeyGenDownloadResponse {
        return try await postJSON("/api/heygen/video/\(urlPathComponent(videoId))/download", body: [:])
    }

    private func bananaImageData(from response: BananaGenerateResponse) async throws -> Data? {
        for candidate in [response.dataUrl, response.imageData, response.resultData, response.base64] {
            guard let candidate, !candidate.isEmpty else { continue }
            if let decoded = decodeImageData(candidate) {
                return decoded
            }
        }

        let imageUrl = response.imageUrl ?? response.resultUrl ?? response.url ?? response.resultUrls?.first
        guard let imageUrl, !imageUrl.isEmpty else { return nil }
        return try await downloadImageData(from: imageUrl)
    }

    private func decodeImageData(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comma = trimmed.firstIndex(of: ","),
           trimmed[..<comma].lowercased().contains("base64") {
            return Data(base64Encoded: String(trimmed[trimmed.index(after: comma)...]), options: .ignoreUnknownCharacters)
        }
        return Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters)
    }

    private func downloadImageData(from urlString: String) async throws -> Data {
        guard ExternalURL.sanitizedURL(urlString) != nil, let url = URL(string: urlString) else {
            throw APIError.requestFailed("不安全的图片 URL，仅允许 https 或受信主机")
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed("下载图片失败")
        }
        guard data.count <= 30 * 1024 * 1024 else {
            throw APIError.requestFailed("下载图片超过 30MB 上限")
        }
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        if !contentType.isEmpty, !contentType.hasPrefix("image/") {
            throw APIError.requestFailed("下载内容不是图片类型 (Content-Type: \(contentType))")
        }
        return data
    }

    private func uploadFilePart(channel: String, partName: String, fallbackBaseName: String, fileName: String, mime: String, data: Data) -> (String, String, String, Data) {
        let safeName = channel == "apimart" ? asciiFilename(originalName: fileName, mime: mime, fallbackBaseName: fallbackBaseName) : fileName
        return (partName, safeName, mime, data)
    }

    private func asciiFilename(originalName: String, mime: String, fallbackBaseName: String) -> String {
        let ext = filenameExtension(originalName: originalName, mime: mime)
        return "\(fallbackBaseName).\(ext)"
    }

    private func filenameExtension(originalName: String, mime: String) -> String {
        let ext = (originalName as NSString).pathExtension.lowercased()
        if !ext.isEmpty, ext.range(of: #"^[a-z0-9]{1,8}$"#, options: .regularExpression) != nil {
            return ext
        }
        switch mime.lowercased() {
        case "image/jpeg", "image/jpg": return "jpg"
        case "image/webp": return "webp"
        case "image/gif": return "gif"
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        default:
            if mime.lowercased().hasPrefix("video/") { return "mp4" }
            return "png"
        }
    }

    // MARK: - Preflight

    func preflight(body: [String: Any]) async throws -> PreflightResponse {
        var req = try makeRequest(path: "/api/preflight")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 5
        return try await perform(req)
    }

    // MARK: - Task Management

    func addTask(id: String, type: String, desc: String, pollKind: ActiveTaskPollKind? = nil) {
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            let existing = activeTasks[index]
            activeTasks[index] = ActiveTask(
                id: existing.id,
                type: type,
                desc: desc,
                startTime: existing.startTime,
                pollKind: pollKind ?? existing.pollKind
            )
        } else {
            activeTasks.append(ActiveTask(id: id, type: type, desc: desc, startTime: Date(), pollKind: pollKind))
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

    private func postJSON<T: Decodable>(_ path: String, body: [String: Any], timeout: TimeInterval? = nil) async throws -> T {
        var req = try makeRequest(path: path)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let timeout {
            req.timeoutInterval = timeout
        }
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

    /// 切换 API 服务器后调用：清 Cookie、重置登录态、清除记住的凭据、阻止自动重登录。
    func resetForNewHost() {
        healthCheckToken += 1
        backendHealthState = .unknown
        clearCookies()
        resetAuthState(clearCache: true)
        hasCheckedSession = false
        rememberLogin = false
        savedLoginCredentialsCache = nil
        CredentialStore.delete()
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

    func clearCachedUserInfo() {
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
        VeoRules.shouldSendDurationValue(channel: channel, model: model, mode: mode)
    }

    var generateAudioValue: String? {
        guard VeoRules.supportsAudio(channel: channel, model: model, mode: mode) else { return nil }
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

    var fileRef: FileRef? {
        guard let data else { return nil }
        return FileRef(data: data, name: name, mime: mime)
    }

    var assetUri: String? { dataUrl }

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
