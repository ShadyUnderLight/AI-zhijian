import Foundation

// MARK: - PromptRule Models

// ——— 规则管理 ———

struct PromptRule: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let ruleText: String?
    let category: String?
    let status: String?          // DRAFT / ACTIVE / DEPRECATED
    let triggerConditions: String?
    let effectStats: String?
    let createdAt: String?
    let updatedAt: String?
}

struct PromptRuleListResponse: Codable {
    let success: Bool
    let rules: [PromptRule]?
    let message: String?
}

struct PromptRuleDetailResponse: Codable {
    let success: Bool
    let rule: PromptRule?
    let message: String?
}

struct PromptRuleUpdateResponse: Codable {
    let success: Bool
    let rule: PromptRule?
    let message: String?
}

struct PromptRuleStatusResponse: Codable {
    let success: Bool
    let rule: PromptRule?
    let message: String?
}

// ——— 规则候选生成 ———

struct PromptRuleGenerateCandidateRequest: Encodable {
    let analysisIds: [Int]
    let ruleGoal: String
    let baseRuleId: Int?
    let ruleCategory: String?
}

struct PromptRuleCandidateResponse: Codable {
    let success: Bool
    let candidateRule: PromptRule?
    let message: String?
}

struct PromptRuleRevisionResponse: Codable {
    let success: Bool
    let revisedRule: PromptRule?
    let message: String?
}

// ——— 案例分析 ———

struct PromptCaseAnalysis: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let summary: String?
    let createdAt: String?
}

struct PromptCaseAnalysisListResponse: Codable {
    let success: Bool
    let analyses: [PromptCaseAnalysis]?
    let message: String?
}

struct PromptCaseAnalysisDetailResponse: Codable {
    let success: Bool
    let analysis: PromptCaseAnalysis?
    let message: String?
}

struct PromptCaseAnalysisGenerateResponse: Codable {
    let success: Bool
    let analysis: PromptCaseAnalysis?
    let message: String?
}

// MARK: - PromptRule API Extension

extension APIService {

    // MARK: 📝 提示词优化规则管理

    // ——— 规则 CRUD ———

    func promptRuleList() async throws -> PromptRuleListResponse {
        try await get("/api/admin/prompt-rules/")
    }

    func promptRuleDetail(id: Int) async throws -> PromptRuleDetailResponse {
        try await get("/api/admin/prompt-rules/\(id)")
    }

    func promptRuleUpdate(id: Int, name: String?, ruleText: String?,
                          category: String?, triggerConditions: String?) async throws -> PromptRuleUpdateResponse {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let ruleText { body["ruleText"] = ruleText }
        if let category { body["category"] = category }
        if let triggerConditions { body["triggerConditions"] = triggerConditions }
        return try await postJSON("/api/admin/prompt-rules/\(id)", body: body)
    }

    func promptRuleUpdateStatus(id: Int, status: String) async throws -> PromptRuleStatusResponse {
        let body: [String: Any] = ["status": status]
        return try await postJSON("/api/admin/prompt-rules/\(id)/status", body: body)
    }

    // ——— 规则候选/修订 ———

    func promptRuleGenerateCandidate(analysisIds: [Int], ruleGoal: String,
                                      baseRuleId: Int? = nil,
                                      ruleCategory: String? = nil) async throws -> PromptRuleCandidateResponse {
        var body: [String: Any] = [
            "analysisIds": analysisIds,
            "ruleGoal": ruleGoal
        ]
        if let baseRuleId { body["baseRuleId"] = baseRuleId }
        if let ruleCategory { body["ruleCategory"] = ruleCategory }
        return try await postJSON("/api/admin/prompt-rules/generate-candidate", body: body)
    }

    func promptRuleGenerateRevision(id: Int) async throws -> PromptRuleRevisionResponse {
        let body: [String: Any] = [:]
        return try await postJSON("/api/admin/prompt-rules/\(id)/generate-revision-from-effect", body: body)
    }

    // ——— 案例分析 ———

    func promptCaseAnalysisList() async throws -> PromptCaseAnalysisListResponse {
        try await get("/api/admin/call-logs/prompt-case/analysis")
    }

    func promptCaseAnalysisDetail(id: Int) async throws -> PromptCaseAnalysisDetailResponse {
        try await get("/api/admin/call-logs/prompt-case/analysis/\(id)")
    }

    func promptCaseAnalysisGenerate() async throws -> PromptCaseAnalysisGenerateResponse {
        let body: [String: Any] = [:]
        return try await postJSON("/api/admin/call-logs/prompt-case/analysis/generate", body: body)
    }
}
