import Foundation

// MARK: - Admin Response Types

// ——— 用户管理 ———

struct AdminUser: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let role: String?
    let contentAuditPermission: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, role
        case contentAuditPermission
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        contentAuditPermission = try container.decodeIfPresent(Bool.self, forKey: .contentAuditPermission)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct AdminUserListResponse: Codable {
    let success: Bool
    let users: [AdminUser]?
    let message: String?
}

struct AdminUserDetailResponse: Codable {
    let success: Bool
    let user: AdminUser?
    let message: String?
}

struct AdminCreateUserResponse: Codable {
    let success: Bool
    let message: String?
}

struct AdminDeleteUserResponse: Codable {
    let success: Bool
    let message: String?
}

// ——— API Key 管理 ———

struct AdminApiKey: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let keyValue: String?
    let workflowConfig: String?
    let maxTasks: Int?
    let activeTaskCount: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case keyValue
        case workflowConfig
        case maxTasks
        case activeTaskCount
        case createdAt
    }
}

struct AdminApiKeyListResponse: Codable {
    let success: Bool
    let keys: [AdminApiKey]?
    let message: String?
}

struct AdminApiKeyCreateResponse: Codable {
    let success: Bool
    let apiKey: AdminApiKey?
    let message: String?
}

struct AdminApiKeyDeleteResponse: Codable {
    let success: Bool
    let message: String?
}

struct AdminAuthorizedUser: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
}

struct AdminAuthorizedUserListResponse: Codable {
    let success: Bool
    let users: [AdminAuthorizedUser]?
    let message: String?
}

struct AdminGrantRevokeResponse: Codable {
    let success: Bool
    let message: String?
}

// ——— 调用日志 ———

struct AdminCallLog: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int?
    let username: String?
    let function: String?
    let status: String?
    let durationMs: Double?
    let cost: Double?
    let mediaType: String?
    let generationMode: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case username, function, status
        case durationMs
        case cost
        case mediaType
        case generationMode
        case createdAt
    }

    var durationSeconds: Double {
        guard let ms = durationMs else { return 0 }
        return ms / 1000.0
    }
}

struct AdminCallLogListResponse: Codable {
    let success: Bool
    let logs: [AdminCallLog]?
    let total: Int?
    let message: String?
}

struct AdminCallLogStats: Codable {
    let totalCalls: Int?
    let totalCost: Double?
    let averageDuration: Double?

    enum CodingKeys: String, CodingKey {
        case totalCalls
        case totalCost
        case averageDuration
    }
}

struct AdminCallLogStatsResponse: Codable {
    let success: Bool
    let stats: AdminCallLogStats?
    let message: String?
}

// ——— 线路检测 ———

struct HealthCheckResult: Codable, Identifiable, Hashable {
    var id: String { serviceName }
    let serviceName: String
    let status: String
    let latency: String?
    let lastCheckAt: String?

    enum CodingKeys: String, CodingKey {
        case serviceName
        case status
        case latency
        case lastCheckAt
    }

    enum HealthStatus: String {
        case healthy = "healthy"
        case reachable = "reachable"
        case unhealthy = "unhealthy"
        case unknown = "unknown"
    }

    var healthStatus: HealthStatus {
        HealthStatus(rawValue: status.lowercased()) ?? .unknown
    }

    var isHealthy: Bool { healthStatus == .healthy }
}

struct HealthCheckResponse: Codable {
    let success: Bool
    let status: String?
    let latency: String?
    let message: String?
}

// MARK: - Admin API Extension

extension APIService {

    // MARK: 👥 用户管理

    func adminGetUsers() async throws -> AdminUserListResponse {
        try await get("/api/users")
    }

    func adminGetUser(id: Int) async throws -> AdminUserDetailResponse {
        try await get("/api/users/\(id)")
    }

    func adminCreateUser(username: String, password: String, role: String?) async throws -> AdminCreateUserResponse {
        var body: [String: Any] = [
            "username": username,
            "password": password
        ]
        if let role { body["role"] = role }
        return try await postJSON("/api/users", body: body)
    }

    func adminUpdateUser(id: Int, password: String?, role: String?, contentAuditPermission: Bool?) async throws -> AdminCreateUserResponse {
        var body: [String: Any] = [:]
        if let password { body["password"] = password }
        if let role { body["role"] = role }
        if let contentAuditPermission { body["contentAuditPermission"] = contentAuditPermission }
        return try await postJSON("/api/users/\(id)", body: body) as AdminCreateUserResponse
    }

    func adminDeleteUser(id: Int) async throws -> AdminDeleteUserResponse {
        // DELETE request — use postJSON with empty body as workaround
        try await postJSON("/api/users/\(id)", body: ["_method": "DELETE"] as [String: Any])
    }

    // MARK: 🔑 API Key 管理

    func adminGetApiKeys() async throws -> AdminApiKeyListResponse {
        try await get("/api/apikey/all")
    }

    func adminCreateApiKey(name: String, keyValue: String?, workflowConfig: String?, maxTasks: Int?) async throws -> AdminApiKeyCreateResponse {
        var body: [String: Any] = [
            "name": name
        ]
        if let keyValue { body["key"] = keyValue }
        if let workflowConfig { body["workflowConfig"] = workflowConfig }
        if let maxTasks { body["maxTasks"] = maxTasks }
        return try await postJSON("/api/apikey/create", body: body)
    }

    func adminUpdateApiKey(id: Int, name: String?, workflowConfig: String?, maxTasks: Int?) async throws -> AdminApiKeyCreateResponse {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let workflowConfig { body["workflowConfig"] = workflowConfig }
        if let maxTasks { body["maxTasks"] = maxTasks }
        return try await postJSON("/api/apikey/update/\(id)", body: body)
    }

    func adminDeleteApiKey(id: Int) async throws -> AdminApiKeyDeleteResponse {
        try await postJSON("/api/apikey/delete/\(id)", body: ["_method": "DELETE"] as [String: Any])
    }

    func adminGetAuthorizedUsers(apiKeyId: Int) async throws -> AdminAuthorizedUserListResponse {
        try await get("/api/apikey/authorized-users/\(apiKeyId)")
    }

    func adminGrantApiKey(userId: Int, apiKeyId: Int) async throws -> AdminGrantRevokeResponse {
        let body: [String: Any] = ["userId": userId, "apiKeyId": apiKeyId]
        return try await postJSON("/api/apikey/grant", body: body)
    }

    func adminRevokeApiKey(userId: Int, apiKeyId: Int) async throws -> AdminGrantRevokeResponse {
        let body: [String: Any] = ["userId": userId, "apiKeyId": apiKeyId]
        return try await postJSON("/api/apikey/revoke", body: body)
    }

    // MARK: 📊 调用日志

    func adminGetCallLogs(
        startDate: String? = nil,
        endDate: String? = nil,
        userId: Int? = nil,
        function: String? = nil,
        status: String? = nil,
        mediaType: String? = nil,
        generationMode: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil
    ) async throws -> AdminCallLogListResponse {
        var params: [String: String] = [:]
        if let startDate { params["startDate"] = startDate }
        if let endDate { params["endDate"] = endDate }
        if let userId { params["userId"] = String(userId) }
        if let function { params["function"] = function }
        if let status { params["status"] = status }
        if let mediaType { params["mediaType"] = mediaType }
        if let generationMode { params["generationMode"] = generationMode }
        if let page { params["page"] = String(page) }
        if let pageSize { params["pageSize"] = String(pageSize) }
        return try await get("/api/admin/call-logs", params: params)
    }

    func adminGetCallLogStats(
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> AdminCallLogStatsResponse {
        var params: [String: String] = [:]
        if let startDate { params["startDate"] = startDate }
        if let endDate { params["endDate"] = endDate }
        return try await get("/api/admin/call-logs/stats", params: params)
    }

    func adminExportCallLogsCSV(
        startDate: String? = nil,
        endDate: String? = nil,
        userId: Int? = nil,
        function: String? = nil,
        status: String? = nil
    ) async throws -> Data {
        var params: [String: String] = [:]
        if let startDate { params["startDate"] = startDate }
        if let endDate { params["endDate"] = endDate }
        if let userId { params["userId"] = String(userId) }
        if let function { params["function"] = function }
        if let status { params["status"] = status }

        let baseURL = AppConfig.apiBaseURL
        guard var urlComponents = URLComponents(string: baseURL.absoluteString) else {
            throw APIError.invalidURL
        }
        urlComponents.path = "/api/admin/call-logs/export"
        if !params.isEmpty {
            urlComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = urlComponents.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("text/csv", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed("导出失败")
        }
        return data
    }

    // MARK: 🌐 线路检测

    struct AdminAllHealthResults {
        let results: [HealthCheckResult]
    }

    func adminCheckAllHealth() async throws -> AdminAllHealthResults {
        let services = [
            ("deepseek", "/api/health/deepseek"),
            ("yunwu", "/api/health/yunwu"),
            ("runninghub", "/api/health/runninghub"),
            ("gemini", "/api/health/gemini"),
            ("gemini-pro", "/api/health/gemini-pro"),
            ("gemini-official", "/api/health/gemini-official"),
            ("gemini-official-pro", "/api/health/gemini-official-pro"),
            ("gpt", "/api/health/gpt")
        ]

        var results: [HealthCheckResult] = []

        for (name, path) in services {
            do {
                let resp: HealthCheckResponse = try await get(path)
                results.append(HealthCheckResult(
                    serviceName: name,
                    status: resp.success ? "healthy" : (resp.message != nil ? "unhealthy" : "unknown"),
                    latency: resp.latency,
                    lastCheckAt: ISO8601DateFormatter().string(from: Date())
                ))
            } catch {
                results.append(HealthCheckResult(
                    serviceName: name,
                    status: "unhealthy",
                    latency: nil,
                    lastCheckAt: ISO8601DateFormatter().string(from: Date())
                ))
            }
        }

        return AdminAllHealthResults(results: results)
    }

    func adminCheckSingleHealth(service path: String) async throws -> HealthCheckResult {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        do {
            let resp: HealthCheckResponse = try await get(path)
            return HealthCheckResult(
                serviceName: name,
                status: resp.success ? "healthy" : (resp.message != nil ? "unhealthy" : "unknown"),
                latency: resp.latency,
                lastCheckAt: ISO8601DateFormatter().string(from: Date())
            )
        } catch {
            return HealthCheckResult(
                serviceName: name,
                status: "unhealthy",
                latency: nil,
                lastCheckAt: ISO8601DateFormatter().string(from: Date())
            )
        }
    }
}
