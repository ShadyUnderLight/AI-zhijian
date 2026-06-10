import SwiftUI

struct ScriptLibraryView: View {
    @EnvironmentObject var scriptStore: ScriptStore
    @EnvironmentObject var api: APIService

    @State private var editorRoute: ScriptEditorRoute?
    @State private var searchText = ""
    @State private var confirmDeleteId: Script.ID?

    // MARK: - Server-side
    @State private var selectedSource: ScriptSource = .local
    @State private var serverScripts: [VideoScriptStoreItem] = []
    @State private var isLoadingServer = false
    @State private var serverError: String?
    @State private var confirmDeleteServerId: String?
    @State private var importToken: String = ""
    @State private var showImportSheet = false
    @State private var shareToken: String?
    @State private var showShareToken = false
    @State private var selectedServerScriptDetail: VideoScriptStoreDetail?

    private enum ScriptSource: String, CaseIterable {
        case local = "本地"
        case server = "服务端"
    }

    private var filteredScripts: [Script] {
        let list = scriptStore.scripts
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return list }
        return list.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.product.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        mainContent
            .navigationTitle("脚本库")
            .toolbar { toolbarContent }
            .sheet(item: $editorRoute) { route in
                ScriptEditorView(script: route.scriptId.flatMap(scriptStore.script(with:)))
                    .environmentObject(scriptStore)
                    .environmentObject(api)
            }
            .sheet(isPresented: $showImportSheet) {
                importSheet
            }
            .sheet(item: $selectedServerScriptDetail) { detail in
                serverScriptDetailView(detail)
            }
            .alert("服务端错误", isPresented: Binding(
                get: { serverError != nil },
                set: { if !$0 { serverError = nil } }
            ), actions: {
                Button("确定") { serverError = nil }
            }, message: {
                Text(serverError ?? "")
            })
            .alert("分享链接", isPresented: $showShareToken) {
                Button("复制链接") {
                    if let token = shareToken {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(token, forType: .string)
                    }
                    shareToken = nil
                }
                Button("关闭") {
                    shareToken = nil
                }
            } message: {
                Text(shareToken ?? "")
            }
            .onChange(of: selectedSource) { _, newValue in
                loadOnSourceChange(newValue)
            }
            .confirmationDialog(
                "删除服务端脚本？",
                isPresented: Binding(
                    get: { confirmDeleteServerId != nil },
                    set: { if !$0 { confirmDeleteServerId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let id = confirmDeleteServerId {
                        deleteServerScript(id)
                        confirmDeleteServerId = nil
                    }
                }
                Button("取消", role: .cancel) {
                    confirmDeleteServerId = nil
                }
            } message: {
                Text("删除后无法恢复")
            }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            sourcePicker
            if selectedSource == .local {
                localScriptsContent
            } else {
                serverScriptsContent
            }
        }
    }

    private var sourcePicker: some View {
        Picker("数据源", selection: $selectedSource) {
            Text("本地").tag(ScriptSource.local)
            Text("服务端").tag(ScriptSource.server)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func loadOnSourceChange(_ newValue: ScriptSource) {
        if newValue == .server {
            loadServerScripts()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            if selectedSource == .local {
                Button {
                    editorRoute = .new()
                } label: {
                    Label("新建脚本", systemImage: "plus")
                }
            } else {
                Button {
                    loadServerScripts()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(isLoadingServer)

                Button {
                    showImportSheet = true
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    // MARK: - Local Scripts

    private var localScriptsContent: some View {
        Group {
            if scriptStore.scripts.isEmpty {
                emptyLocalState
            } else {
                List {
                    ForEach(filteredScripts) { script in
                        ScriptRow(script: script)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editorRoute = .edit(script.id)
                            }
                            .contextMenu {
                                Button {
                                    scriptStore.duplicate(script.id)
                                } label: {
                                    Label("复制脚本", systemImage: "doc.on.doc")
                                }
                                Button {
                                    saveToServer(script)
                                } label: {
                                    Label("上传到服务端", systemImage: "icloud.and.arrow.up")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    confirmDeleteId = script.id
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { indexSet in
                        if let firstId = indexSet.map({ filteredScripts[$0].id }).first {
                            confirmDeleteId = firstId
                        }
                    }
                }
                .listStyle(.inset)
                .searchable(text: $searchText, prompt: "搜索脚本标题或产品")
                .confirmationDialog(
                    confirmDeleteId.flatMap { id in scriptStore.script(with: id).map { "删除脚本「\($0.title)」" } } ?? "",
                    isPresented: Binding(
                        get: { confirmDeleteId != nil },
                        set: { if !$0 { confirmDeleteId = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("删除", role: .destructive) {
                        if let id = confirmDeleteId {
                            scriptStore.delete(id)
                            confirmDeleteId = nil
                        }
                    }
                    Button("取消", role: .cancel) {
                        confirmDeleteId = nil
                    }
                } message: {
                    Text("删除后无法恢复")
                }
            }
        }
    }

    private var emptyLocalState: some View {
        ContentUnavailableView(
            "暂无本地脚本",
            systemImage: "doc.text",
            description: Text("点击工具栏 + 按钮创建新的带货脚本")
        )
    }

    // MARK: - Server Scripts

    private var serverScriptsContent: some View {
        Group {
            if isLoadingServer {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if serverScripts.isEmpty {
                ContentUnavailableView(
                    "暂无服务端脚本",
                    systemImage: "icloud.slash",
                    description: Text("本地脚本可右键上传到服务端")
                )
            } else {
                List {
                    ForEach(serverScripts) { item in
                        ServerScriptRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                loadServerScriptDetail(item.id)
                            }
                            .contextMenu {
                                Button {
                                    shareToken = item.id
                                    generateShareLink(item.id)
                                } label: {
                                    Label("分享", systemImage: "square.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    confirmDeleteServerId = item.id
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Import Sheet

    private var importSheet: some View {
        NavigationStack {
            Form {
                Section("导入他人脚本") {
                    TextField("输入分享 Token", text: $importToken)
                        .textFieldStyle(.roundedBorder)

                    Button("导入") {
                        importServerScript(token: importToken)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(importToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("导入脚本")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        importToken = ""
                        showImportSheet = false
                    }
                }
            }
        }
        .frame(width: 400, height: 200)
    }

    // MARK: - Server Script Detail View

    private func serverScriptDetailView(_ detail: VideoScriptStoreDetail) -> some View {
        NavigationStack {
            Form {
                Section("脚本信息") {
                    LabeledContent("标题") { Text(detail.title) }
                    if !detail.requirement.isEmpty {
                        LabeledContent("需求") { Text(detail.requirement) }
                    }
                    LabeledContent("分镜数") { Text("\(detail.rows.count)") }
                }

                Section("分镜列表") {
                    ForEach(detail.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("镜头 \(row.shotNumber)")
                                .font(.subheadline.bold())
                            if !row.sceneDescription.isEmpty {
                                Text(row.sceneDescription).font(.caption).foregroundColor(.secondary)
                            }
                            if !row.copy.isEmpty {
                                Text("文案：\(row.copy)").font(.caption).foregroundColor(.secondary)
                            }
                            if !row.duration.isEmpty {
                                Text("时长：\(row.duration)").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("脚本详情")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("关闭") {
                        selectedServerScriptDetail = nil
                    }
                }
            }
        }
        .frame(width: 500, height: 500)
    }

    // MARK: - Actions

    private func loadServerScripts() {
        isLoadingServer = true
        serverError = nil
        Task {
            do {
                let response = try await api.videoScriptStoreList()
                if response.success {
                    await MainActor.run {
                        serverScripts = response.items ?? []
                    }
                } else {
                    await MainActor.run {
                        serverError = response.message ?? "加载失败"
                    }
                }
            } catch {
                await MainActor.run {
                    serverError = error.localizedDescription
                }
            }
            isLoadingServer = false
        }
    }

    private func loadServerScriptDetail(_ id: String) {
        Task {
            do {
                let response = try await api.videoScriptStoreDetail(id: id)
                if response.success, let item = response.item {
                    await MainActor.run {
                        selectedServerScriptDetail = item
                    }
                } else {
                    await MainActor.run {
                        serverError = response.message ?? "加载详情失败"
                    }
                }
            } catch {
                await MainActor.run {
                    serverError = error.localizedDescription
                }
            }
        }
    }

    private func deleteServerScript(_ id: String) {
        Task {
            do {
                let response = try await api.videoScriptDelete(id: id)
                if response.success {
                    await MainActor.run {
                        serverScripts.removeAll { $0.id == id }
                    }
                } else {
                    await MainActor.run {
                        serverError = response.message ?? "删除失败"
                    }
                }
            } catch {
                await MainActor.run {
                    serverError = error.localizedDescription
                }
            }
        }
    }

    private func saveToServer(_ script: Script) {
        let rows = script.shots.enumerated().map { i, shot -> VideoScriptTableRow in
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
        Task {
            do {
                let response = try await api.videoScriptSave(
                    requirement: "\(script.title) - \(script.product)",
                    title: script.title,
                    rows: rows
                )
                if response.success {
                    await MainActor.run {
                        serverError = nil
                    }
                } else {
                    await MainActor.run {
                        serverError = response.message ?? "上传失败"
                    }
                }
            } catch {
                await MainActor.run {
                    serverError = error.localizedDescription
                }
            }
        }
    }

    private func generateShareLink(_ id: String) {
        Task {
            do {
                let response = try await api.videoScriptShare(id: id)
                if response.success {
                    await MainActor.run {
                        shareToken = response.url ?? response.token ?? id
                        showShareToken = true
                    }
                } else {
                    await MainActor.run {
                        serverError = response.message ?? "生成分享链接失败"
                    }
                }
            } catch {
                await MainActor.run {
                    serverError = error.localizedDescription
                }
            }
        }
    }

    private func importServerScript(token: String) {
        showImportSheet = false
        Task {
            do {
                let response = try await api.videoScriptImport(token: token)
                if response.success, let item = response.item {
                    await MainActor.run {
                        selectedServerScriptDetail = item
                        // Auto-save to local
                        let shots = item.rows.enumerated().map { i, row -> ScriptShot in
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
                        let script = Script(title: item.title, product: "", shots: shots)
                        scriptStore.save(script: script)
                    }
                } else {
                    await MainActor.run {
                        serverError = response.message ?? "导入失败"
                    }
                }
            } catch {
                await MainActor.run {
                    serverError = error.localizedDescription
                }
            }
        }
    }
}

private struct ScriptEditorRoute: Identifiable, Equatable {
    let id: String
    let scriptId: Script.ID?

    static func new() -> ScriptEditorRoute {
        ScriptEditorRoute(id: "new-\(UUID().uuidString)", scriptId: nil)
    }

    static func edit(_ scriptId: Script.ID) -> ScriptEditorRoute {
        ScriptEditorRoute(id: "edit-\(scriptId)", scriptId: scriptId)
    }
}

private struct ScriptRow: View {
    var script: Script

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(script.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(script.product)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("· \(script.shots.count) 个镜头")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(script.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct ServerScriptRow: View {
    var item: VideoScriptStoreItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
            if !item.requirement.isEmpty {
                Text(item.requirement)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text("\(item.rowCount) 个镜头")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("更新: \(item.updatedAt)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
