import SwiftUI

// MARK: - Content Audit View

struct ContentAuditView: View {
    @EnvironmentObject var api: APIService

    @State private var selectedTab = AuditTab.check

    enum AuditTab: String, CaseIterable {
        case check = "文案审核工具"
        case samples = "样本管理"
        case knowledge = "知识库管理"

        var icon: String {
            switch self {
            case .check: return "doc.text.magnifyingglass"
            case .samples: return "list.bullet.clipboard"
            case .knowledge: return "books.vertical"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("功能", selection: $selectedTab) {
                ForEach(AuditTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            switch selectedTab {
            case .check:
                AuditCheckView()
            case .samples:
                AuditSampleManageView()
            case .knowledge:
                AuditKnowledgeManageView()
            }
        }
    }
}

// MARK: - 文案审核工具

struct AuditCheckView: View {
    @EnvironmentObject var api: APIService

    @State private var inputText = ""
    @State private var resultText = ""
    @State private var generationPrompt = ""

    @State private var isChecking = false
    @State private var isOptimizing = false
    @State private var isGenerating = false

    @State private var checkResult: ContentAuditCheckResponse?
    @State private var optimizeResult: ContentAuditOptimizeResponse?
    @State private var generateResult: ContentAuditGenerateResponse?

    @State private var errorMessage: String?
    @State private var activeMode = AuditMode.check

    enum AuditMode: String, CaseIterable {
        case check = "文案检查"
        case optimize = "文案优化"
        case generate = "文案生成"
    }

    var body: some View {
        HSplitView {
            // Left: Input panel
            VStack(spacing: 12) {
                Picker("模式", selection: $activeMode) {
                    ForEach(AuditMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    if activeMode == .generate {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("输入 Prompt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $generationPrompt)
                                .font(.body)
                                .frame(minHeight: 120)
                                .overlay(
                                    Group {
                                        if generationPrompt.isEmpty {
                                            Text("请输入文案生成需求描述…")
                                                .foregroundColor(.secondary)
                                                .padding(8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("输入文案")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $inputText)
                                .font(.body)
                                .frame(minHeight: 120)
                                .overlay(
                                    Group {
                                        if inputText.isEmpty {
                                            Text("请输入要\(activeMode == .check ? "检测" : "优化")的文案…")
                                                .foregroundColor(.secondary)
                                                .padding(8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        .padding(.horizontal)
                    }
                }

                Button(action: executeAction) {
                    if isChecking || isOptimizing || isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(actionButtonLabel, systemImage: actionButtonIcon)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(actionButtonDisabled)
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .frame(minWidth: 300, maxWidth: 400)

            // Right: Results panel
            VStack(alignment: .leading, spacing: 12) {
                if let checkResult {
                    resultHeader(title: "检测结果", icon: "checkmark.shield")
                    HStack {
                        Text("风险评分")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f", checkResult.riskScore ?? 0))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(riskColor(checkResult.riskScore ?? 0))
                    }
                    .padding(.horizontal)

                    if let summary = checkResult.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("摘要")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(summary)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }

                    if let issues = checkResult.issues, !issues.isEmpty {
                        Text("问题列表（\(issues.count) 项）")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal)

                        List(issues) { issue in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    severityBadge(issue.severity)
                                    Text(issue.issue)
                                        .font(.subheadline)
                                }
                                if let suggestion = issue.suggestion {
                                    Text("建议：\(suggestion)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listStyle(.plain)
                    }
                }

                if let optimizeResult {
                    resultHeader(title: "优化结果", icon: "arrow.up.doc")
                    if let optimizedText = optimizeResult.optimizedText {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("优化后文案")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ScrollView {
                                Text(optimizedText)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    if let changes = optimizeResult.changes, !changes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("修改说明")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(changes, id: \.self) { change in
                                Label(change, systemImage: "smallcircle.filled.circle")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if let generateResult {
                    resultHeader(title: "生成结果", icon: "sparkle")
                    if let text = generateResult.generatedText {
                        ScrollView {
                            Text(text)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }

                if checkResult == nil && optimizeResult == nil && generateResult == nil {
                    Spacer()
                    ContentUnavailableView(
                        activeMode == .generate ? "输入 Prompt 生成文案" : "输入文案开始\(activeMode == .check ? "检测" : "优化")",
                        systemImage: activeMode == .generate ? "sparkle" : "doc.text.magnifyingglass",
                        description: Text("结果将显示在此处")
                    )
                    Spacer()
                }
            }
            .frame(minWidth: 350)
        }
        .frame(minHeight: 400)
        .onChange(of: activeMode) { _, _ in
            // 切换模式时清除旧结果
            checkResult = nil
            optimizeResult = nil
            generateResult = nil
            errorMessage = nil
        }
    }

    private var actionButtonLabel: String {
        switch activeMode {
        case .check: return "开始检测"
        case .optimize: return "开始优化"
        case .generate: return "生成文案"
        }
    }

    private var actionButtonIcon: String {
        switch activeMode {
        case .check: return "magnifyingglass"
        case .optimize: return "wand.and.stars"
        case .generate: return "sparkle"
        }
    }

    private var actionButtonDisabled: Bool {
        switch activeMode {
        case .check: return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking
        case .optimize: return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isOptimizing
        case .generate: return generationPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating
        }
    }

    private func executeAction() {
        errorMessage = nil
        switch activeMode {
        case .check:
            checkResult = nil
            isChecking = true
            Task {
                do {
                    let resp = try await api.auditCheck(text: inputText)
                    if resp.success {
                        checkResult = resp
                    } else {
                        errorMessage = resp.message ?? "检测失败"
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
                isChecking = false
            }
        case .optimize:
            optimizeResult = nil
            isOptimizing = true
            Task {
                do {
                    let resp = try await api.auditOptimize(text: inputText)
                    if resp.success {
                        optimizeResult = resp
                    } else {
                        errorMessage = resp.message ?? "优化失败"
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
                isOptimizing = false
            }
        case .generate:
            generateResult = nil
            isGenerating = true
            Task {
                do {
                    let resp = try await api.auditGenerate(prompt: generationPrompt)
                    if resp.success {
                        generateResult = resp
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

    private func resultHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private func riskColor(_ score: Double) -> Color {
        if score >= 0.7 { return .red }
        if score >= 0.4 { return .orange }
        return .green
    }

    @ViewBuilder
    private func severityBadge(_ severity: String?) -> some View {
        switch severity?.lowercased() {
        case "high", "critical":
            Text("高")
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(4)
        case "medium":
            Text("中")
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .cornerRadius(4)
        default:
            Text("低")
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.15))
                .foregroundColor(.yellow)
                .cornerRadius(4)
        }
    }
}

// MARK: - 样本管理

struct AuditSampleManageView: View {
    @EnvironmentObject var api: APIService

    @State private var samples: [ContentAuditSample] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedType = "SAFE"
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("样本管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Label("添加样本", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Type picker
            Picker("类型", selection: $selectedType) {
                Text("安全样本").tag("SAFE")
                Text("危险样本").tag("DANGEROUS")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: selectedType) { _, _ in loadSamples() }

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
                Button("重试") { loadSamples() }
                    .buttonStyle(.bordered)
                Spacer()
            } else if samples.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "暂无样本",
                    systemImage: "tray",
                    description: Text("点击「添加样本」添加第一个\(selectedType == "SAFE" ? "安全" : "危险")样本")
                )
                Spacer()
            } else {
                List {
                    ForEach(samples) { sample in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sample.content)
                                .font(.body)
                                .lineLimit(3)
                            if let createdAt = sample.createdAt {
                                Text(createdAt)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteSamples)
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: { loadSamples() }) {
            AuditSampleAddView { type, content in
                try await api.auditAddSample(type: type, content: content)
            }
        }
        .task { loadSamples() }
    }

    private func loadSamples() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp = selectedType == "SAFE"
                    ? try await api.auditGetSafeSamples()
                    : try await api.auditGetDangerousSamples()
                if resp.success {
                    samples = resp.samples ?? []
                } else {
                    errorMessage = resp.message ?? "加载失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func deleteSamples(at offsets: IndexSet) {
        // 收集要删除的 ID → 顺序调用 API → 统一移除（避免并发数组越界）
        let itemsToDelete = offsets.map { samples[$0] }
        Task {
            for item in itemsToDelete {
                _ = try? await api.auditDeleteSample(id: item.id)
            }
            await MainActor.run {
                samples.remove(atOffsets: offsets)
            }
        }
    }
}

// MARK: - 添加样本 Sheet

struct AuditSampleAddView: View {
    @Environment(\.dismiss) private var dismiss

    let onSubmit: (String, String) async throws -> ContentAuditSampleCreateResponse

    @State private var selectedType = "SAFE"
    @State private var content = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("添加样本")
                .font(.title2)
                .fontWeight(.semibold)

            Picker("类型", selection: $selectedType) {
                Text("安全").tag("SAFE")
                Text("危险").tag("DANGEROUS")
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                Text("内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $content)
                    .font(.body)
                    .frame(minHeight: 120)
                    .overlay(
                        Group {
                            if content.isEmpty {
                                Text("输入样本内容…")
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
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
                Button("保存") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .padding()
        .frame(width: 400, height: 320)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let resp = try await onSubmit(selectedType, content)
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

// MARK: - 知识库管理

struct AuditKnowledgeManageView: View {
    @EnvironmentObject var api: APIService

    @State private var files: [KnowledgeFile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showFilePicker = false
    @State private var isUploading = false
    @State private var selectedFile: KnowledgeFile?
    @State private var showChunks = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("知识库管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showFilePicker = true }) {
                    Label(isUploading ? "上传中…" : "上传文件", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUploading)
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
                Button("重试") { loadFiles() }
                    .buttonStyle(.bordered)
                Spacer()
            } else if files.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "暂无文件",
                    systemImage: "tray",
                    description: Text("点击「上传文件」上传知识库文档（仅支持文本，≤10MB）")
                )
                Spacer()
            } else {
                List {
                    ForEach(files) { file in
                        Button(action: { selectFile(file) }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.fileName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    HStack(spacing: 12) {
                                        if let size = file.fileSize {
                                            Text(formatFileSize(size))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let status = file.status {
                                            Text(status)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let createdAt = file.createdAt {
                                            Text(createdAt)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteFiles)
                }
                .listStyle(.plain)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                uploadFile(url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showChunks, onDismiss: { loadFiles() }) {
            if let file = selectedFile {
                AuditChunksView(file: file)
            }
        }
        .task { loadFiles() }
    }

    private func loadFiles() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp = try await api.auditGetKnowledgeFiles()
                if resp.success {
                    files = resp.files ?? []
                } else {
                    errorMessage = resp.message ?? "加载失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func selectFile(_ file: KnowledgeFile) {
        selectedFile = file
        showChunks = true
    }

    private func uploadFile(_ url: URL) {
        isUploading = true
        errorMessage = nil
        Task {
            do {
                let resp = try await api.auditUploadKnowledgeFile(fileURL: url)
                if resp.success {
                    loadFiles()
                } else {
                    errorMessage = resp.message ?? "上传失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isUploading = false
        }
    }

    private func deleteFiles(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { files[$0] }
        Task {
            for item in itemsToDelete {
                _ = try? await api.auditDeleteKnowledgeFile(id: item.id)
            }
            await MainActor.run {
                files.remove(atOffsets: offsets)
            }
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - 知识库分块查看

struct AuditChunksView: View {
    @EnvironmentObject var api: APIService
    let file: KnowledgeFile
    @Environment(\.dismiss) private var dismiss

    @State private var chunks: [KnowledgeFileChunk] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var editingAnnotation: Int?  // chunk id being edited
    @State private var annotationError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("分块详情")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(file.fileName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("加载分块…")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                Spacer()
            } else if chunks.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "暂无分块",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("该文件尚未被分块处理")
                )
                Spacer()
            } else {
                List {
                    ForEach(chunks) { chunk in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if let category = chunk.category {
                                    Text(category)
                                        .font(.caption)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                                Text("分块 #\(chunk.id)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            Text(chunk.content)
                                .font(.body)
                                .lineLimit(4)

                            Divider()

                            HStack {
                                Text("标注")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if editingAnnotation == chunk.id {
                                    Button("保存") {
                                        saveAnnotation(chunk)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                } else {
                                    Button(chunk.annotation == nil || chunk.annotation?.isEmpty == true ? "添加" : "编辑") {
                                        editingAnnotation = chunk.id
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }

                            if editingAnnotation == chunk.id {
                                TextField("输入标注…", text: Binding(
                                    get: {
                                        chunks.first(where: { $0.id == chunk.id })?.annotation ?? ""
                                    },
                                    set: { newValue in
                                        if let idx = chunks.firstIndex(where: { $0.id == chunk.id }) {
                                            var updated = chunks[idx]
                                            updated = KnowledgeFileChunk(
                                                id: updated.id,
                                                content: updated.content,
                                                category: updated.category,
                                                annotation: newValue
                                            )
                                            chunks[idx] = updated
                                        }
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            } else if let annotation = chunk.annotation, !annotation.isEmpty {
                                Text(annotation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(6)
                                    .background(Color(.textBackgroundColor))
                                    .cornerRadius(4)
                            }

                            if let annErr = annotationError, editingAnnotation == chunk.id {
                                Text(annErr)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 550, height: 500)
        .task { loadChunks() }
    }

    private func loadChunks() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp = try await api.auditGetKnowledgeFileChunks(fileId: file.id)
                if resp.success {
                    chunks = resp.chunks ?? []
                } else {
                    errorMessage = resp.message ?? "加载失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func saveAnnotation(_ chunk: KnowledgeFileChunk) {
        guard let chunkInList = chunks.first(where: { $0.id == chunk.id }),
              let annotation = chunkInList.annotation else {
            editingAnnotation = nil
            return
        }
        annotationError = nil
        Task {
            do {
                let resp = try await api.auditUpdateChunkAnnotation(chunkId: chunk.id, annotation: annotation)
                if resp.success {
                    editingAnnotation = nil
                } else {
                    annotationError = resp.message ?? "保存失败"
                }
            } catch {
                annotationError = error.localizedDescription
            }
        }
    }
}
