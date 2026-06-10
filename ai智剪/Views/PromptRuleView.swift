import SwiftUI

// MARK: - Prompt Rule View

struct PromptRuleView: View {
    @EnvironmentObject var api: APIService

    @State private var rules: [PromptRule] = []
    @State private var analyses: [PromptCaseAnalysis] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab = RuleTab.list
    @State private var showEditSheet = false
    @State private var editingRule: PromptRule?
    @State private var showGenerateCandidateSheet = false
    @State private var showAnalysisDetail: PromptCaseAnalysis?

    enum RuleTab: String, CaseIterable {
        case list = "规则列表"
        case analysis = "案例分析"

        var icon: String {
            switch self {
            case .list: return "list.bullet.rectangle"
            case .analysis: return "chart.bar.doc.horizontal"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("视图", selection: $selectedTab) {
                ForEach(RuleTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            switch selectedTab {
            case .list:
                ruleListView
            case .analysis:
                analysisView
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: { loadRules() }) {
            if let rule = editingRule {
                PromptRuleEditView(rule: rule) { id, name, ruleText, category, triggerConditions in
                    try await api.promptRuleUpdate(id: id, name: name, ruleText: ruleText,
                                                     category: category, triggerConditions: triggerConditions)
                }
            }
        }
        .sheet(isPresented: $showGenerateCandidateSheet, onDismiss: { loadRules() }) {
            PromptRuleGenerateCandidateView { analysisIds, ruleGoal, baseRuleId, ruleCategory in
                try await api.promptRuleGenerateCandidate(analysisIds: analysisIds, ruleGoal: ruleGoal,
                                                           baseRuleId: baseRuleId, ruleCategory: ruleCategory)
            }
        }
        .sheet(item: $showAnalysisDetail) { analysis in
            PromptAnalysisDetailView(analysis: analysis)
        }
        .task { loadData() }
    }

    // MARK: - Rule List

    private var ruleListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("规则管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showGenerateCandidateSheet = true }) {
                    Label("AI 生成规则", systemImage: "sparkle")
                }
                .buttonStyle(.borderedProminent)
                Button(action: { loadRules() }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            if isLoading {
                Spacer()
                ProgressView("加载中…")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                Button("重试") { loadRules() }
                    .buttonStyle(.bordered)
                Spacer()
            } else if rules.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "暂无规则",
                    systemImage: "doc.text",
                    description: Text("点击「AI 生成规则」基于案例分析创建第一条规则")
                )
                Spacer()
            } else {
                Table(rules) {
                    TableColumn("名称") { rule in
                        Text(rule.name)
                            .fontWeight(.medium)
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn("分类") { rule in
                        Text(rule.category ?? "-")
                            .font(.caption)
                    }
                    .width(80)

                    TableColumn("状态") { rule in
                        statusBadge(rule.status)
                    }
                    .width(90)

                    TableColumn("生效时间") { rule in
                        Text(rule.updatedAt ?? rule.createdAt ?? "-")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    TableColumn("操作") { rule in
                        HStack(spacing: 8) {
                            Button("编辑") {
                                editingRule = rule
                                showEditSheet = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            if rule.status == "DRAFT" {
                                Button("生效") {
                                    activateRule(rule)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.green)
                            } else if rule.status == "ACTIVE" {
                                Button("停用") {
                                    deactivateRule(rule)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.orange)
                            }
                        }
                    }
                    .width(150)
                }
                .tableStyle(.bordered)
                .alternatingRowBackgrounds()
            }
        }
    }

    // MARK: - Analysis View

    private var analysisView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("案例分析")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: generateAnalysis) {
                    Label("生成新分析", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            if analyses.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "暂无分析",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("点击「生成新分析」基于调用日志生成案例分析")
                )
                Spacer()
            } else {
                List {
                    ForEach(analyses) { analysis in
                        Button(action: { showAnalysisDetail = analysis }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(analysis.title ?? "分析 #\(analysis.id)")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    if let summary = analysis.summary {
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if let createdAt = analysis.createdAt {
                                    Text(createdAt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Data

    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                async let rulesResp = api.promptRuleList()
                async let analysesResp = api.promptCaseAnalysisList()
                let (r, a) = try await (rulesResp, analysesResp)

                var errors: [String] = []
                if r.success {
                    rules = r.rules ?? []
                } else {
                    errors.append(r.message ?? "加载规则失败")
                }
                if a.success {
                    analyses = a.analyses ?? []
                } else {
                    errors.append(a.message ?? "加载分析失败")
                }
                if !errors.isEmpty {
                    errorMessage = errors.joined(separator: "\n")
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func loadRules() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp = try await api.promptRuleList()
                if resp.success {
                    rules = resp.rules ?? []
                } else {
                    errorMessage = resp.message ?? "加载失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func activateRule(_ rule: PromptRule) {
        Task {
            if let resp = try? await api.promptRuleUpdateStatus(id: rule.id, status: "ACTIVE"),
               resp.success {
                loadRules()
            } else {
                errorMessage = "状态切换失败"
                loadRules()
            }
        }
    }

    private func deactivateRule(_ rule: PromptRule) {
        Task {
            if let resp = try? await api.promptRuleUpdateStatus(id: rule.id, status: "DEPRECATED"),
               resp.success {
                loadRules()
            } else {
                errorMessage = "状态切换失败"
                loadRules()
            }
        }
    }

    private func generateAnalysis() {
        Task {
            do {
                let resp = try await api.promptCaseAnalysisGenerate()
                if resp.success {
                    loadData()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: String?) -> some View {
        switch status?.uppercased() {
        case "ACTIVE":
            Text("生效")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(4)
        case "DRAFT":
            Text("草稿")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
        case "DEPRECATED":
            Text("已废弃")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.gray)
                .cornerRadius(4)
        default:
            Text(status ?? "-")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - PromptRule Edit View

struct PromptRuleEditView: View {
    @Environment(\.dismiss) private var dismiss
    let rule: PromptRule
    let onSave: (Int, String?, String?, String?, String?) async throws -> PromptRuleUpdateResponse

    @State private var name: String
    @State private var ruleText: String
    @State private var category: String
    @State private var triggerConditions: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(rule: PromptRule, onSave: @escaping (Int, String?, String?, String?, String?) async throws -> PromptRuleUpdateResponse) {
        self.rule = rule
        self.onSave = onSave
        _name = State(initialValue: rule.name)
        _ruleText = State(initialValue: rule.ruleText ?? "")
        _category = State(initialValue: rule.category ?? "")
        _triggerConditions = State(initialValue: rule.triggerConditions ?? "")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("编辑规则")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                Section {
                    TextField("规则名称", text: $name)
                        .textFieldStyle(.roundedBorder)

                    TextField("分类", text: $category)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading) {
                        Text("规则文本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $ruleText)
                            .font(.body)
                            .frame(minHeight: 150)
                    }

                    VStack(alignment: .leading) {
                        Text("触发条件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $triggerConditions)
                            .font(.body)
                            .frame(minHeight: 80)
                    }
                }
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .padding()
        .frame(width: 500, height: 500)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let resp = try await onSave(
                    rule.id,
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name,
                    ruleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ruleText,
                    category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category,
                    triggerConditions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : triggerConditions
                )
                if resp.success {
                    dismiss()
                } else {
                    errorMessage = resp.message ?? "保存失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

// MARK: - Generate Candidate View

struct PromptRuleGenerateCandidateView: View {
    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss
    let onSubmit: ([Int], String, Int?, String?) async throws -> PromptRuleCandidateResponse

    @State private var selectedAnalysisIds: Set<Int> = []
    @State private var availableAnalyses: [PromptCaseAnalysis] = []
    @State private var ruleGoal = ""
    @State private var ruleCategory = ""
    @State private var isLoading = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var generatedRule: PromptRule?

    var body: some View {
        VStack(spacing: 16) {
            Text("AI 生成规则候选")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                Section("选择案例分析") {
                    if availableAnalyses.isEmpty {
                        Text("暂无可用分析")
                            .foregroundColor(.secondary)
                    } else {
                        List(availableAnalyses) { analysis in
                            HStack {
                                Image(systemName: selectedAnalysisIds.contains(analysis.id)
                                    ? "checkmark.circle.fill"
                                    : "circle")
                                    .foregroundColor(selectedAnalysisIds.contains(analysis.id) ? .accentColor : .secondary)
                                Text(analysis.title ?? "分析 #\(analysis.id)")
                                    .font(.body)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedAnalysisIds.contains(analysis.id) {
                                    selectedAnalysisIds.remove(analysis.id)
                                } else {
                                    selectedAnalysisIds.insert(analysis.id)
                                }
                            }
                        }
                        .frame(height: 150)
                    }
                }

                Section("规则配置") {
                    TextField("规则目标", text: $ruleGoal, prompt: Text("例如：优化文案风格"))
                        .textFieldStyle(.roundedBorder)
                    TextField("规则分类", text: $ruleCategory, prompt: Text("例如：style, safety, format"))
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)

            if let rule = generatedRule {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("生成的规则")
                        .font(.headline)
                    Text(rule.name)
                        .font(.subheadline)
                    if let text = rule.ruleText {
                        Text(text)
                            .font(.body)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button(generatedRule != nil ? "完成" : "生成") {
                    if generatedRule != nil {
                        dismiss()
                    } else {
                        generate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled((selectedAnalysisIds.isEmpty || ruleGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && generatedRule == nil)
                .disabled(isGenerating)
            }
        }
        .padding()
        .frame(width: 500, height: 500)
        .task {
            isLoading = true
            do {
                let resp = try await api.promptCaseAnalysisList()
                if resp.success {
                    availableAnalyses = resp.analyses ?? []
                }
            } catch {}
            isLoading = false
        }
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let resp = try await api.promptRuleGenerateCandidate(
                    analysisIds: Array(selectedAnalysisIds),
                    ruleGoal: ruleGoal,
                    baseRuleId: nil,
                    ruleCategory: ruleCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ruleCategory
                )
                if resp.success, let candidate = resp.candidateRule {
                    generatedRule = candidate
                } else {
                    errorMessage = resp.message ?? "生成失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

// MARK: - Analysis Detail View

struct PromptAnalysisDetailView: View {
    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss
    let analysis: PromptCaseAnalysis
    @State private var detail: PromptCaseAnalysis?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("分析详情")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("加载中…")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                Spacer()
            } else if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(detail.title ?? "分析 #\(detail.id)")
                            .font(.title3)
                            .fontWeight(.medium)

                        if let summary = detail.summary {
                            Text(summary)
                                .font(.body)
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                ContentUnavailableView(
                    "暂无详情",
                    systemImage: "doc.text",
                    description: Text("无法加载分析详情")
                )
                Spacer()
            }
        }
        .frame(width: 450, height: 400)
        .task {
            isLoading = true
            do {
                let resp = try await api.promptCaseAnalysisDetail(id: analysis.id)
                if resp.success {
                    detail = resp.analysis
                } else {
                    errorMessage = resp.message ?? "加载失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
