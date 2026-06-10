import Foundation

// MARK: - ContentAudit Models

// ——— 文案检测 ———

struct ContentAuditCheckRequest: Encodable {
    let text: String
}

struct ContentAuditCheckResult: Codable, Identifiable {
    var id: String { issue }
    let issue: String
    let severity: String?
    let suggestion: String?
}

struct ContentAuditCheckResponse: Codable {
    let success: Bool
    let riskScore: Double?
    let issues: [ContentAuditCheckResult]?
    let summary: String?
    let message: String?
}

// ——— 文案优化 ———

struct ContentAuditOptimizeRequest: Encodable {
    let text: String
}

struct ContentAuditOptimizeResponse: Codable {
    let success: Bool
    let optimizedText: String?
    let changes: [String]?
    let message: String?
}

// ——— 文案生成 ———

struct ContentAuditGenerateRequest: Encodable {
    let prompt: String
}

struct ContentAuditGenerateResponse: Codable {
    let success: Bool
    let generatedText: String?
    let message: String?
}

// ——— 样本管理 ———

struct ContentAuditSample: Codable, Identifiable, Hashable {
    let id: Int
    let type: String?       // "SAFE" or "DANGEROUS"
    let content: String
    let createdAt: String?
}

struct ContentAuditSampleListResponse: Codable {
    let success: Bool
    let samples: [ContentAuditSample]?
    let message: String?
}

struct ContentAuditSampleCreateResponse: Codable {
    let success: Bool
    let sample: ContentAuditSample?
    let message: String?
}

struct ContentAuditSampleDeleteResponse: Codable {
    let success: Bool
    let message: String?
}

// ——— 知识库文件 ———

struct KnowledgeFile: Codable, Identifiable, Hashable {
    let id: Int
    let fileName: String
    let fileSize: Int?
    let status: String?
    let createdAt: String?
}

struct KnowledgeFileListResponse: Codable {
    let success: Bool
    let files: [KnowledgeFile]?
    let message: String?
}

struct KnowledgeFileUploadResponse: Codable {
    let success: Bool
    let file: KnowledgeFile?
    let message: String?
}

struct KnowledgeFileDeleteResponse: Codable {
    let success: Bool
    let message: String?
}

struct KnowledgeFileChunk: Codable, Identifiable, Hashable {
    let id: Int
    let content: String
    let category: String?
    let annotation: String?
}

struct KnowledgeFileChunkListResponse: Codable {
    let success: Bool
    let chunks: [KnowledgeFileChunk]?
    let message: String?
}

struct KnowledgeChunkAnnotationResponse: Codable {
    let success: Bool
    let chunk: KnowledgeFileChunk?
    let message: String?
}

// MARK: - ContentAudit API Extension

extension APIService {

    // MARK: 🛡️ 内容审核

    // ——— 文案检测 ———

    func auditCheck(text: String) async throws -> ContentAuditCheckResponse {
        let body = ContentAuditCheckRequest(text: text)
        return try await postJSON("/api/audit/check", body: body)
    }

    // ——— 文案优化 ———

    func auditOptimize(text: String) async throws -> ContentAuditOptimizeResponse {
        let body = ContentAuditOptimizeRequest(text: text)
        return try await postJSON("/api/audit/optimize", body: body)
    }

    // ——— 文案生成 ———

    func auditGenerate(prompt: String) async throws -> ContentAuditGenerateResponse {
        let body = ContentAuditGenerateRequest(prompt: prompt)
        return try await postJSON("/api/audit/generate", body: body)
    }

    // ——— 样本管理 ———

    func auditGetSamples(type: String? = nil) async throws -> ContentAuditSampleListResponse {
        if let type {
            return try await get("/api/audit/samples/\(type.lowercased())")
        }
        return try await get("/api/audit/samples/safe")
    }

    func auditGetSafeSamples() async throws -> ContentAuditSampleListResponse {
        try await get("/api/audit/samples/safe")
    }

    func auditGetDangerousSamples() async throws -> ContentAuditSampleListResponse {
        try await get("/api/audit/samples/dangerous")
    }

    func auditAddSample(type: String, content: String) async throws -> ContentAuditSampleCreateResponse {
        let body: [String: Any] = [
            "type": type,
            "content": content
        ]
        return try await postJSON("/api/audit/samples", body: body)
    }

    func auditDeleteSample(id: Int) async throws -> ContentAuditSampleDeleteResponse {
        try await postJSON("/api/audit/samples/\(id)", body: ["_method": "DELETE"] as [String: Any])
    }

    // ——— 知识库管理 ———

    func auditGetKnowledgeFiles() async throws -> KnowledgeFileListResponse {
        try await get("/api/audit/knowledge/files")
    }

    func auditUploadKnowledgeFile(fileURL: URL) async throws -> KnowledgeFileUploadResponse {
        let data = try Data(contentsOf: fileURL)
        guard data.count <= 10_485_760 else {
            throw APIError.requestFailed("文件大小超过 10MB 限制")
        }

        let fileName = fileURL.lastPathComponent
        let mimeType = fileName.hasSuffix(".txt") ? "text/plain" : "application/octet-stream"

        let fields: [(String, String)] = []
        let files: [(String, String, String, Data)] = [("file", fileName, mimeType, data)]
        let (responseData, _) = try await uploadMultipart("/api/audit/knowledge/files", fields: fields, files: files)
        guard let data = responseData,
              let result = try? JSONDecoder().decode(KnowledgeFileUploadResponse.self, from: data) else {
            throw APIError.decodeFailed
        }
        return result
    }

    func auditGetKnowledgeFileChunks(fileId: Int) async throws -> KnowledgeFileChunkListResponse {
        try await get("/api/audit/knowledge/files/\(fileId)/chunks")
    }

    func auditUpdateChunkAnnotation(chunkId: Int, annotation: String) async throws -> KnowledgeChunkAnnotationResponse {
        let body: [String: Any] = ["annotation": annotation]
        return try await postJSON("/api/audit/knowledge/chunks/\(chunkId)", body: body)
    }

    func auditDeleteKnowledgeFile(id: Int) async throws -> KnowledgeFileDeleteResponse {
        try await postJSON("/api/audit/knowledge/files/\(id)", body: ["_method": "DELETE"] as [String: Any])
    }
}
