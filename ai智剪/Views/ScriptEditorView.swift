import SwiftUI
import OSLog
import UniformTypeIdentifiers

fileprivate enum ScriptEditorFocusedField: Hashable {
    case title
    case product
    case shotTitle(_ shotId: String)
    case sceneDescription(_ shotId: String)
    case copy(_ shotId: String)
    case duration(_ shotId: String)
    case referencePrompt(_ shotId: String)
    case videoPrompt(_ shotId: String)
}

struct ScriptEditorView: View {
    @EnvironmentObject var scriptStore: ScriptStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss
    private let logger = Logger(subsystem: "AIZhijian", category: "ScriptEditor")

    private let existing: Script?

    @FocusState private var focusedField: ScriptEditorFocusedField?
    @State private var didClearInitialFocus = false

    @State private var title: String = ""
    @State private var product: String = ""
    @State private var shots: [ScriptShot] = []
    @State private var deleteShotId: String?
    @State private var exportError: String?
    @State private var sendValidationError: String?
    @State private var showDeleteConfirm = false
    @State private var expandedIds: Set<String> = []
    @State private var isEditing: Bool

    // MARK: - AI Generation State
    @State private var aiRequirement: String = ""
    @State private var isGeneratingTable = false
    @State private var isRefining = false
    @State private var refineFeedback: String = ""
    @State private var showRefineSheet = false
    @State private var showAiGenSection = false
    @State private var aiError: String?

    // MARK: - Submit State
    @State private var submitError: String?
    @State private var submitSuccessMessage: String?
    @State private var showModelPicker = false
    @State private var selectedSubmitShotId: String?
    @State private var selectedI2VModel: String = "grok"

    private var currentTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var navigationTitle: String {
        if existing == nil { return "新建脚本" }
        return isEditing ? "编辑脚本" : "脚本详情"
    }

    private var validationErrorMessage: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写脚本标题"
        }
        if product.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写带货产品"
        }
        return nil
    }

    init(script: Script?) {
        existing = script
        _isEditing = State(initialValue: script == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("脚本信息") {
                    if isEditing {
                        TextField("脚本标题", text: $title)
                            .focused($focusedField, equals: .title)
                        TextField("带货产品", text: $product)
                            .focused($focusedField, equals: .product)
                    } else {
                        LabeledContent("脚本标题") {
                            Text(title.isEmpty ? "未命名脚本" : title)
                                .foregroundColor(title.isEmpty ? .secondary : .primary)
                        }
                        LabeledContent("带货产品") {
                            Text(product.isEmpty ? "未填写" : product)
                                .foregroundColor(product.isEmpty ? .secondary : .primary)
                        }
                    }
                }

                // MARK: - AI 脚本生成（新建或编辑时可用）
                if isEditing && showAiGenSection {
                    Section("AI 脚本生成") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("输入视频需求，AI 将自动生成结构化脚本表格")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextEditor(text: $aiRequirement)
                                .font(.body)
                                .frame(minHeight: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )

                            HStack {
                                Button {
                                    generateTable()
                                } label: {
                                    HStack(spacing: 4) {
                                        if isGeneratingTable { ProgressView().scaleEffect(0.7) }
                                        Text(isGeneratingTable ? "生成中..." : "AI 生成")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isGeneratingTable || aiRequirement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("取消") {
                                    showAiGenSection = false
                                    aiRequirement = ""
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                if !shots.isEmpty {
                                    Button("AI 优化") {
                                        showRefineSheet = true
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isRefining)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("镜头列表") {
                    ForEach($shots) { $shot in
                        let shotId = shot.id
                        let expandedBinding = Binding(
                            get: { expandedIds.contains(shotId) },
                            set: { if $0 { expandedIds.insert(shotId) } else { expandedIds.remove(shotId) } }
                        )
                        ShotEditorView(
                            index: (shots.firstIndex(where: { $0.id == shot.id }) ?? 0) + 1,
                            shot: $shot,
                            isExpanded: expandedBinding,
                            isEditing: isEditing,
                            focusedField: $focusedField,
                            onSendToGen: { prompt, kind in
                                sendToGeneration(prompt: prompt, kind: kind)
                            },
                            onGenerateImagePrompt: { shotId in
                                generateImagePrompt(for: shotId)
                            },
                            onGenerateVideoPrompt: { shotId in
                                generateVideoPrompt(for: shotId)
                            },
                            onSubmitImage: { shotId in
                                submitImage(for: shotId)
                            },
                            onSubmitVideo: { shotId in
                                submitVideo(for: shotId)
                            },
                            onSubmitImageToVideo: { shotId in
                                selectedSubmitShotId = shotId
                                showModelPicker = true
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            if isEditing {
                                Button("删除", role: .destructive) {
                                    deleteShotId = shot.id
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if isEditing {
                                let idx = shots.firstIndex(where: { $0.id == shot.id }) ?? 0
                                if idx > 0 {
                                    Button("上移") {
                                        shots.move(fromOffsets: IndexSet(integer: idx), toOffset: idx - 1)
                                    }
                                }
                                if idx < shots.count - 1 {
                                    Button("下移") {
                                        shots.move(fromOffsets: IndexSet(integer: idx), toOffset: idx + 2)
                                    }
                                }
                            }
                        }
                        .moveDisabled(!isEditing)
                    }
                    .onMove { from, to in
                        guard isEditing else { return }
                        shots.move(fromOffsets: from, toOffset: to)
                    }

                    if isEditing {
                        Button {
                            let newShot = ScriptShot(sortOrder: shots.count)
                            expandedIds.insert(newShot.id)
                            shots.append(newShot)
                        } label: {
                            Label("添加镜头", systemImage: "plus.circle")
                        }
                    }
                }

                if shots.isEmpty {
                    Section {
                        Text(isEditing ? "点击「添加镜头」开始构建脚本" : "这个脚本还没有镜头")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(existing == nil ? "取消" : (isEditing ? "取消编辑" : "关闭")) {
                        if let existing, isEditing {
                            load(existing)
                            isEditing = false
                            clearInitialFocus()
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("保存") {
                            save()
                            dismiss()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || product.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button {
                            isEditing = true
                            clearInitialFocus()
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                    }
                }

                if isEditing {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showAiGenSection.toggle()
                        } label: {
                            Label("AI 生成", systemImage: "sparkles")
                        }
                        .help("AI 生成脚本表格")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        exportMarkdown()
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .help("导出为 Markdown")
                }

                if existing != nil && isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除脚本", systemImage: "trash")
                        }
                        .help("删除当前脚本")
                    }
                }
            }
            .onAppear {
                if let s = existing {
                    load(s)
                }

                guard !didClearInitialFocus else { return }
                didClearInitialFocus = true
                clearInitialFocus()
            }
        }
        .confirmationDialog("确认删除镜头", isPresented: Binding(
            get: { deleteShotId != nil },
            set: { if !$0 { deleteShotId = nil } }
        ), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let id = deleteShotId, let idx = shots.firstIndex(where: { $0.id == id }) {
                    shots.remove(at: idx)
                    expandedIds.remove(id)
                    deleteShotId = nil
                }
            }
            Button("取消", role: .cancel) {
                deleteShotId = nil
            }
        } message: {
            Text("删除后镜头内容无法恢复")
        }
        .confirmationDialog(
            (currentTitle.isEmpty ? existing?.title : currentTitle).map { "删除脚本「\($0)」" } ?? "",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let id = existing?.id {
                    scriptStore.delete(id)
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后脚本内容无法恢复")
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        ), actions: {
            Button("确定") { exportError = nil }
        }, message: {
            Text(exportError ?? "")
        })
        .alert("提示", isPresented: Binding(
            get: { sendValidationError != nil },
            set: { if !$0 { sendValidationError = nil } }
        ), actions: {
            Button("确定") { sendValidationError = nil }
        }, message: {
            Text(sendValidationError ?? "")
        })
        .alert("AI 生成错误", isPresented: Binding(
            get: { aiError != nil },
            set: { if !$0 { aiError = nil } }
        ), actions: {
            Button("确定") { aiError = nil }
        }, message: {
            Text(aiError ?? "")
        })
        .alert("提交成功", isPresented: Binding(
            get: { submitSuccessMessage != nil },
            set: { if !$0 { submitSuccessMessage = nil } }
        ), actions: {
            Button("确定") { submitSuccessMessage = nil }
        }, message: {
            Text(submitSuccessMessage ?? "")
        })
        .alert("提交失败", isPresented: Binding(
            get: { submitError != nil },
            set: { if !$0 { submitError = nil } }
        ), actions: {
            Button("确定") { submitError = nil }
        }, message: {
            Text(submitError ?? "")
        })
        .sheet(isPresented: $showRefineSheet) {
            refineSheet
        }
        .sheet(isPresented: $showModelPicker) {
            i2VModelPicker
        }
    }

    // MARK: - Refine Sheet

    private var refineSheet: some View {
        NavigationStack {
            Form {
                Section("优化反馈") {
                    TextEditor(text: $refineFeedback)
                        .font(.body)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                Section {
                    Text("AI 将根据你的反馈修改脚本表格内容，包括调整分镜、文案、时长等。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("AI 优化脚本")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        refineFeedback = ""
                        showRefineSheet = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("优化") {
                        refineTable()
                    }
                    .disabled(refineFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRefining)
                }
            }
        }
        .frame(width: 450, height: 300)
    }

    // MARK: - I2V Model Picker

    private var i2VModelPicker: some View {
        NavigationStack {
            Form {
                Section("选择图生视频模型") {
                    Picker("模型", selection: $selectedI2VModel) {
                        Text("Grok RunningHub").tag("grok")
                        Text("Seedance 2.0").tag("seedance20")
                        Text("Veo V3.1 Lite").tag("v31lite")
                        Text("Veo V3.1 Pro Reference").tag("v31pro_ref")
                        Text("Kling 1.6").tag("kling26")
                        Text("Video S Pro").tag("s_pro")
                    }
                    .pickerStyle(.menu)

                    if selectedI2VModel == "seedance20" {
                        Toggle("生成音频", isOn: .constant(false))
                            .disabled(true)
                            .help("即将支持")
                        Toggle("真人模式", isOn: .constant(false))
                            .disabled(true)
                            .help("即将支持")
                    }
                }

                Section {
                    Text("从脚本行「\(shots.first(where: { $0.id == selectedSubmitShotId })?.title ?? "")」提交图生视频任务")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("图生视频")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showModelPicker = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("提交") {
                        submitImageToVideo()
                        showModelPicker = false
                    }
                }
            }
        }
        .frame(width: 400, height: 280)
    }

    private func clearInitialFocus() {
        focusedField = nil
        DispatchQueue.main.async {
            focusedField = nil
        }
    }

    private func load(_ script: Script) {
        title = script.title
        product = script.product
        shots = normalizeShotIDs(script.shots)
        expandedIds.removeAll()
        focusedField = nil
    }

    private func save() {
        var s: Script
        if let existing {
            s = existing
            s.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            s.product = product.trimmingCharacters(in: .whitespacesAndNewlines)
            s.shots = shots
        } else {
            s = Script(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                product: product.trimmingCharacters(in: .whitespacesAndNewlines),
                shots: shots
            )
        }
        for i in s.shots.indices {
            s.shots[i].sortOrder = i
        }
        scriptStore.save(script: s)
    }

    private func exportMarkdown() {
        let md = Self.makeMarkdown(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            product: product.trimmingCharacters(in: .whitespacesAndNewlines),
            shots: shots
        )
        let filename = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let panel = NSSavePanel()
        panel.title = "导出脚本"
        panel.nameFieldStringValue = filename.isEmpty ? "未命名脚本.md" : "\(filename).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try md.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportError = "写入文件失败：\(error.localizedDescription)"
        }
    }

    static func makeMarkdown(title: String, product: String, shots: [ScriptShot]) -> String {
        var md = "# \(title)\n\n"
        if !product.isEmpty {
            md += "**带货产品**: \(product)\n\n"
        }
        for (i, shot) in shots.enumerated() {
            md += "## 镜头 \(i + 1)"
            if !shot.title.isEmpty { md += "：\(shot.title)" }
            md += "\n\n"
            if !shot.sceneDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += "### 画面描述\n\n\(shot.sceneDescription)\n\n"
            }
            if !shot.copy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += "### 文案\n\n\(shot.copy)\n\n"
            }
            if !shot.duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += "**时长**：\(shot.duration)\n\n"
            }
            if !shot.referencePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += "### 图片提示词\n\n\(shot.referencePrompt)\n\n"
            }
            if !shot.videoPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += "### 视频提示词\n\n\(shot.videoPrompt)\n\n"
            }
        }
        return md
    }

    private func sendToGeneration(prompt: String, kind: GenerationJobKind) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let msg = validationErrorMessage {
            sendValidationError = msg
            return
        }
        if isEditing {
            save()
        }
        let shotTitle = shots.first { $0.referencePrompt == prompt || $0.videoPrompt == prompt }?.title ?? ""
        editCoordinator.prefillPrompt = EditTaskCoordinator.PrefillPrompt(
            text: prompt, kind: kind, sourceShotTitle: shotTitle
        )
        editCoordinator.navigateToKind = kind
        dismiss()
    }

    // MARK: - AI Script Generation

    private func generateTable() {
        isGeneratingTable = true
        aiError = nil
        let requirement = aiRequirement.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let response = try await api.videoScriptGenerateTable(requirement: requirement)
                if response.success, let rows = response.rows {
                    await MainActor.run {
                        // Convert VideoScriptTableRow rows to ScriptShot
                        let newShots = rows.enumerated().map { i, row -> ScriptShot in
                            ScriptShot(
                                title: "镜头 \(i + 1)",
                                referencePrompt: row.imagePrompt,
                                videoPrompt: row.videoPrompt,
                                sortOrder: i,
                                sceneDescription: row.sceneDescription,
                                copy: row.copy,
                                duration: row.duration,
                                notes: row.notes
                            )
                        }
                        shots = newShots
                        newShots.forEach { expandedIds.insert($0.id) }
                        if title.isEmpty {
                            title = requirement.prefix(30).description
                        }
                        showAiGenSection = false
                        aiRequirement = ""
                    }
                } else {
                    await MainActor.run {
                        aiError = response.message ?? "AI 生成失败，请重试"
                    }
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                }
            }
            isGeneratingTable = false
        }
    }

    private func refineTable() {
        isRefining = true
        aiError = nil
        let feedback = refineFeedback.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                // Convert ScriptShot to VideoScriptTableRow for the API
                let rows = shots.enumerated().map { i, shot -> VideoScriptTableRow in
                    VideoScriptTableRow(
                        shotNumber: i + 1,
                        sceneDescription: shot.sceneDescription,
                        copy: shot.copy,
                        duration: shot.duration,
                        imagePrompt: shot.referencePrompt,
                        videoPrompt: shot.videoPrompt,
                        notes: shot.notes
                    )
                }
                let response = try await api.videoScriptRefine(feedback: feedback, rows: rows)
                if response.success, let refinedRows = response.rows {
                    await MainActor.run {
                        let newShots = refinedRows.enumerated().map { i, row -> ScriptShot in
                            ScriptShot(
                                title: "镜头 \(i + 1)",
                                referencePrompt: row.imagePrompt,
                                videoPrompt: row.videoPrompt,
                                sortOrder: i,
                                sceneDescription: row.sceneDescription,
                                copy: row.copy,
                                duration: row.duration,
                                notes: row.notes
                            )
                        }
                        shots = newShots
                        newShots.forEach { expandedIds.insert($0.id) }
                        refineFeedback = ""
                        showRefineSheet = false
                    }
                } else {
                    await MainActor.run {
                        aiError = response.message ?? "AI 优化失败，请重试"
                    }
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                }
            }
            isRefining = false
        }
    }

    // MARK: - Prompt Generation

    private func generateImagePrompt(for shotId: String) {
        guard let idx = shots.firstIndex(where: { $0.id == shotId }) else { return }
        let shot = shots[idx]
        Task {
            do {
                let response = try await api.videoScriptGenerateImagePrompt(
                    rowId: shotId,
                    sceneDescription: shot.sceneDescription,
                    copy: shot.copy
                )
                if response.success, let prompt = response.prompt {
                    await MainActor.run {
                        shots[idx].referencePrompt = prompt
                    }
                } else {
                    await MainActor.run {
                        aiError = response.message ?? "生成图片提示词失败"
                    }
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                }
            }
        }
    }

    private func generateVideoPrompt(for shotId: String) {
        guard let idx = shots.firstIndex(where: { $0.id == shotId }) else { return }
        let shot = shots[idx]
        Task {
            do {
                let response = try await api.videoScriptGenerateVideoPrompt(
                    rowId: shotId,
                    sceneDescription: shot.sceneDescription,
                    copy: shot.copy
                )
                if response.success, let prompt = response.prompt {
                    await MainActor.run {
                        shots[idx].videoPrompt = prompt
                    }
                } else {
                    await MainActor.run {
                        aiError = response.message ?? "生成视频提示词失败"
                    }
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - One-Click Submit

    private func submitImage(for shotId: String) {
        guard let idx = shots.firstIndex(where: { $0.id == shotId }) else { return }
        let prompt = shots[idx].referencePrompt
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            submitError = "请先生成或填写图片提示词"
            return
        }
        Task {
            do {
                let response = try await api.videoScriptSubmitImage(rowId: shotId, imagePrompt: prompt)
                if response.success {
                    await MainActor.run {
                        submitSuccessMessage = "文生图任务已提交\(response.taskId.map { "（ID: \($0)）" } ?? "")，请在任务队列查看进度"
                    }
                } else {
                    await MainActor.run {
                        submitError = response.message ?? "提交失败"
                    }
                }
            } catch {
                await MainActor.run {
                    submitError = error.localizedDescription
                }
            }
        }
    }

    private func submitVideo(for shotId: String) {
        guard let idx = shots.firstIndex(where: { $0.id == shotId }) else { return }
        let prompt = shots[idx].videoPrompt
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            submitError = "请先生成或填写视频提示词"
            return
        }
        Task {
            do {
                let response = try await api.videoScriptSubmitVideo(rowId: shotId, videoPrompt: prompt)
                if response.success {
                    await MainActor.run {
                        submitSuccessMessage = "文生视频任务已提交\(response.taskId.map { "（ID: \($0)）" } ?? "")，请在任务队列查看进度"
                    }
                } else {
                    await MainActor.run {
                        submitError = response.message ?? "提交失败"
                    }
                }
            } catch {
                await MainActor.run {
                    submitError = error.localizedDescription
                }
            }
        }
    }

    private func submitImageToVideo() {
        guard let shotId = selectedSubmitShotId, let idx = shots.firstIndex(where: { $0.id == shotId }) else { return }
        let prompt = shots[idx].referencePrompt
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            submitError = "请先生成或填写图片提示词"
            return
        }
        let model = selectedI2VModel
        Task {
            do {
                let response = try await api.videoScriptSubmitImageToVideo(rowId: shotId, imagePrompt: prompt, model: model)
                if response.success {
                    await MainActor.run {
                        submitSuccessMessage = "图生视频任务已提交（模型: \(model)）\(response.taskId.map { "（ID: \($0)）" } ?? "")，请在任务队列查看进度"
                    }
                } else {
                    await MainActor.run {
                        submitError = response.message ?? "提交失败"
                    }
                }
            } catch {
                await MainActor.run {
                    submitError = error.localizedDescription
                }
            }
        }
    }

    private func normalizeShotIDs(_ shots: [ScriptShot]) -> [ScriptShot] {
        var seen = Set<String>()
        return shots.map { s in
            var shot = s
            if shot.id.isEmpty || seen.contains(shot.id) {
                shot.id = UUID().uuidString
            }
            seen.insert(shot.id)
            return shot
        }
    }
}

private struct ShotEditorView: View {
    let index: Int
    @Binding var shot: ScriptShot
    let isExpanded: Binding<Bool>
    let isEditing: Bool
    var focusedField: FocusState<ScriptEditorFocusedField?>.Binding
    var onSendToGen: ((String, GenerationJobKind) -> Void)?
    var onGenerateImagePrompt: ((String) -> Void)?
    var onGenerateVideoPrompt: ((String) -> Void)?
    var onSubmitImage: ((String) -> Void)?
    var onSubmitVideo: ((String) -> Void)?
    var onSubmitImageToVideo: ((String) -> Void)?

    @State private var refPromptCopied = false
    @State private var vidPromptCopied = false
    @State private var refCopyGen = 0
    @State private var vidCopyGen = 0
    @State private var promptToClear: PromptKind?

    private enum PromptKind {
        case reference, video
    }

    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    TextField("镜头标题", text: $shot.title)
                        .textFieldStyle(.roundedBorder)
                        .focused(focusedField, equals: .shotTitle(shot.id))
                } else {
                    let trimmedTitle = shot.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    LabeledContent("镜头标题") {
                        Text(trimmedTitle.isEmpty ? "未命名镜头" : trimmedTitle)
                            .foregroundColor(trimmedTitle.isEmpty ? .secondary : .primary)
                    }
                }

                // 画面描述
                labeledField(title: "画面描述", text: $shot.sceneDescription, field: .sceneDescription(shot.id))

                // 文案
                labeledField(title: "文案", text: $shot.copy, field: .copy(shot.id))

                // 时长
                if isEditing {
                    TextField("时长（如：5秒）", text: $shot.duration)
                        .textFieldStyle(.roundedBorder)
                        .focused(focusedField, equals: .duration(shot.id))
                } else {
                    let trimmed = shot.duration.trimmingCharacters(in: .whitespacesAndNewlines)
                    LabeledContent("时长") {
                        Text(trimmed.isEmpty ? "未填写" : trimmed)
                            .foregroundColor(trimmed.isEmpty ? .secondary : .primary)
                    }
                }

                // 备注
                if isEditing {
                    TextField("备注", text: $shot.notes)
                        .textFieldStyle(.roundedBorder)
                } else {
                    let trimmed = shot.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        LabeledContent("备注") {
                            Text(trimmed)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // AI 提示词生成按钮
                if isEditing {
                    HStack(spacing: 8) {
                        Button {
                            onGenerateImagePrompt?(shot.id)
                        } label: {
                            Label("生成图片提示词", systemImage: "sparkle.magnifyingglass")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            onGenerateVideoPrompt?(shot.id)
                        } label: {
                            Label("生成视频提示词", systemImage: "sparkle.video")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                promptSection(
                    title: "图片提示词",
                    text: $shot.referencePrompt,
                    copied: $refPromptCopied,
                    generation: $refCopyGen,
                    promptKind: .reference,
                    shotId: shot.id,
                    genButton: referenceGenButton
                )

                promptSection(
                    title: "视频提示词",
                    text: $shot.videoPrompt,
                    copied: $vidPromptCopied,
                    generation: $vidCopyGen,
                    promptKind: .video,
                    shotId: shot.id,
                    genButton: videoGenButton
                )

                // 一键提交按钮
                if isEditing {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("一键提交")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button {
                                onSubmitImage?(shot.id)
                            } label: {
                                Label("文生图", systemImage: "photo.badge.plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(shot.referencePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                onSubmitVideo?(shot.id)
                            } label: {
                                Label("文生视频", systemImage: "video.badge.plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(shot.videoPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                onSubmitImageToVideo?(shot.id)
                            } label: {
                                Label("图生视频", systemImage: "rectangle.on.rectangle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(shot.referencePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Text("镜头 \(index)")
                    .font(.subheadline.bold())
                let trimmedTitle = shot.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTitle.isEmpty {
                    Text("：\(trimmedTitle)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 6) {
                    let refFilled = !shot.referencePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let vidFilled = !shot.videoPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    HStack(spacing: 2) {
                        Image(systemName: refFilled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(refFilled ? .green : .secondary.opacity(0.4))
                            .font(.caption)
                        Text("图")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(refFilled ? "参考图已填写" : "参考图未填写")
                    HStack(spacing: 2) {
                        Image(systemName: vidFilled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(vidFilled ? .green : .secondary.opacity(0.4))
                            .font(.caption)
                        Text("视")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(vidFilled ? "视频已填写" : "视频未填写")
                }
            }
        }
        .onChange(of: isExpanded.wrappedValue) { _, expanded in
            if !expanded {
                focusedField.wrappedValue = nil
            }
        }
        .confirmationDialog("确认清空 Prompt", isPresented: Binding(
            get: { promptToClear != nil },
            set: { if !$0 { promptToClear = nil } }
        ), titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                switch promptToClear {
                case .reference: shot.referencePrompt = ""
                case .video: shot.videoPrompt = ""
                case nil: break
                }
                promptToClear = nil
            }
            Button("取消", role: .cancel) {
                promptToClear = nil
            }
        } message: {
            Text("清空后内容无法恢复，确定要清空吗？")
        }
    }

    @ViewBuilder
    private func labeledField(title: String, text: Binding<String>, field: ScriptEditorFocusedField) -> some View {
        if isEditing {
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .focused(focusedField, equals: field)
        } else {
            let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            LabeledContent(title) {
                Text(trimmed.isEmpty ? "未填写" : trimmed)
                    .foregroundColor(trimmed.isEmpty ? .secondary : .primary)
            }
        }
    }

    @ViewBuilder
    private var referenceGenButton: some View {
        let trimmed = shot.referencePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        Button {
            onSendToGen?(shot.referencePrompt, .gptImage)
        } label: {
            Label("用作参考图", systemImage: "photo.badge.plus")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(trimmed.isEmpty)
    }

    @ViewBuilder
    private var videoGenButton: some View {
        let trimmed = shot.videoPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        Menu {
            Button("Seedance 视频", systemImage: "video") {
                onSendToGen?(shot.videoPrompt, .seedance)
            }
            Button("Wan 视频", systemImage: "film") {
                onSendToGen?(shot.videoPrompt, .wan)
            }
            Button("Veo 视频", systemImage: "globe") {
                onSendToGen?(shot.videoPrompt, .veo)
            }
            Button("Grok 视频", systemImage: "brain") {
                onSendToGen?(shot.videoPrompt, .grok)
            }
        } label: {
            Label("用作视频", systemImage: "video.badge.plus")
                .font(.caption)
        }
        .disabled(trimmed.isEmpty)
    }

    @ViewBuilder
    private func promptSection(
        title: String,
        text: Binding<String>,
        copied: Binding<Bool>,
        generation: Binding<Int>,
        promptKind: PromptKind,
        shotId: String,
        genButton: some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(text.wrappedValue.count) 字符")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if isEditing {
                TextEditor(text: text)
                    .focused(focusedField, equals: promptKind == .reference ? .referencePrompt(shotId) : .videoPrompt(shotId))
                    .font(.body)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else {
                readOnlyPrompt(text.wrappedValue)
            }
            HStack {
                genButton
                Spacer()
                copyButton(text: text.wrappedValue, copied: copied, generation: generation)
                if isEditing {
                    Button("清空", role: .destructive) {
                        promptToClear = promptKind
                    }
                    .disabled(text.wrappedValue.isEmpty)
                    .controlSize(.small)
                }
            }
        }
    }

    private func readOnlyPrompt(_ value: String) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return Group {
            if trimmed.isEmpty {
                Text("未填写")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(value)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.body)
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func copyButton(text: String, copied: Binding<Bool>, generation: Binding<Int>) -> some View {
        Button {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(text, forType: .string) else { return }
            copied.wrappedValue = true
            let myGen = generation.wrappedValue + 1
            generation.wrappedValue = myGen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard generation.wrappedValue == myGen else { return }
                copied.wrappedValue = false
            }
        } label: {
            Label(copied.wrappedValue ? "已复制" : "复制",
                  systemImage: copied.wrappedValue ? "checkmark" : "doc.on.doc")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
