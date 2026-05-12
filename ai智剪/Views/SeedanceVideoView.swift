import SwiftUI
import UniformTypeIdentifiers

struct SeedanceVideoView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    
    @State private var prompt = ""
    @State private var mode = "reference"
    @State private var model = "dreamina-seedance-2-0-260128"
    @State private var ratio = "adaptive"
    @State private var resolution = "720p"
    @State private var duration = 5
    @State private var count = 1
    @State private var generateAudio = true
    @State private var referenceImages: [FileRef] = []
    @State private var firstFrame: FileRef?
    @State private var lastFrame: FileRef?
    @State private var assetConfigured = false
    @State private var assetConfigMessage = "素材库未加载"
    @State private var assetGroups: [SeedanceVirtualAssetGroup] = []
    @State private var selectedAssetGroupId: Int?
    @State private var assetItems: [SeedanceVirtualAssetItem] = []
    @State private var selectedVirtualAssets: [SeedanceVirtualAssetItem] = []
    @State private var newGroupName = ""
    @State private var importAssetName = ""
    @State private var importImage: FileRef?
    @State private var assetLoadingCount = 0
    @State private var assetErrorMessage: String?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskIds: [String] = []
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: $isBatchMode) {
                    Text("单条生成").tag(false)
                    Text("批量生成").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .onChange(of: isBatchMode) { _, _ in
                    errorMessage = nil
                    batchMessage = nil
                }

                if isBatchMode {
                    batchModeView
                } else {
                    singleModeView
                }
            }
            .padding(24)
            .task { await loadVirtualAssetGroups() }
        }
    }

    private var singleModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("提示词").font(.headline)
                TextEditor(text: $prompt)
                    .font(.body)
                    .frame(height: 60)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }
            
            HStack(spacing: 12) {
                opt("模式", $mode, [("reference", "全能参考"), ("first_last", "首尾帧")])
                opt("模型", $model, [
                    ("dreamina-seedance-2-0-260128", "标准版"),
                    ("dreamina-seedance-2-0-fast-260128", "快速版")
                ])
                opt("画幅", $ratio, [("adaptive","智能"),("9:16","9:16"),("16:9","16:9"),("4:3","4:3"),("1:1","1:1"),("3:4","3:4"),("21:9","21:9")])
                opt("分辨率", $resolution, [("480p","480p"),("720p","720p"),("1080p","1080p")])
                opt("秒数", Binding(get: { "\(duration)" }, set: { duration = Int($0) ?? 5 }),
                    (4...15).map { ("\($0)", "\($0)s") })
                opt("数量", Binding(get: { "\(count)" }, set: { count = Int($0) ?? 1 }),
                    [("1","1"),("2","2"),("3","3"),("4","4")])
            }
            
            Toggle("生成音频", isOn: $generateAudio)
            
            if mode == "reference" {
                MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 9)
                virtualAssetPanel
            } else {
                FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstFrame = nil }) { data, name, mime in
                    firstFrame = FileRef(data: data, name: name, mime: mime)
                }
                FilePickerRow(label: "尾帧图片（可选）", types: [.image], onClear: { lastFrame = nil }) { data, name, mime in
                    lastFrame = FileRef(data: data, name: name, mime: mime)
                }
            }
            
            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8)
                        Text("提交中...")
                    } else {
                        Label("生成视频", systemImage: "video.badge.plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }
            
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
            
            ForEach(resultTaskIds, id: \.self) { tid in
                TaskPollingView(taskId: tid, pollType: .seedance, api: api)
            }
        }
        .onChange(of: mode) { _, newMode in
            resultTaskIds = []
            errorMessage = nil
            if newMode == "reference" {
                firstFrame = nil; lastFrame = nil
            } else {
                referenceImages = []
                selectedVirtualAssets = []
                newGroupName = ""
                importAssetName = ""
                importImage = nil
            }
        }
    }

    private var batchModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("批量提示词").font(.headline)
                    Spacer()
                    Text("\(parsedSeedanceBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(parsedSeedanceBatchPrompts.isEmpty ? .secondary : .accentColor)
                }
                TextEditor(text: $batchPrompts)
                    .font(.body).frame(height: 160)
                    .scrollContentBackground(.hidden).padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Text("每行一条提示词，共享当前参数配置")
                    .font(.caption2).foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                opt("模式", $mode, [("reference", "全能参考"), ("first_last", "首尾帧")])
                opt("模型", $model, [
                    ("dreamina-seedance-2-0-260128", "标准版"),
                    ("dreamina-seedance-2-0-fast-260128", "快速版")
                ])
                opt("画幅", $ratio, [("adaptive","智能"),("9:16","9:16"),("16:9","16:9"),("4:3","4:3"),("1:1","1:1"),("3:4","3:4"),("21:9","21:9")])
                opt("分辨率", $resolution, [("480p","480p"),("720p","720p"),("1080p","1080p")])
                opt("秒数", Binding(get: { "\(duration)" }, set: { duration = Int($0) ?? 5 }),
                    (4...15).map { ("\($0)", "\($0)s") })
                opt("数量", Binding(get: { "\(count)" }, set: { count = Int($0) ?? 1 }),
                    [("1","1"),("2","2"),("3","3"),("4","4")])
            }
            Toggle("生成音频", isOn: $generateAudio)

            HStack {
                Button(action: enqueueSeedanceBatch) {
                    Label("加入批量队列 (\(parsedSeedanceBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedSeedanceBatchPrompts.isEmpty)

                if !queueStore.items.isEmpty {
                    Text("队列: \(queueStore.pendingCount) 待提交")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let msg = batchMessage { Text(msg).font(.caption).foregroundColor(msg.contains("失败") ? .red : .green) }
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
        }
    }

    private var parsedSeedanceBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private func enqueueSeedanceBatch() {
        let prompts = parsedSeedanceBatchPrompts
        guard !prompts.isEmpty else { return }
        errorMessage = nil; batchMessage = nil

        let items = prompts.map { prompt in
            GenerationQueueItem(
                kind: .seedance,
                createdAt: Date(),
                params: .seedance(SeedanceJobParams(
                    prompt: prompt, mode: mode, model: model,
                    ratio: ratio, resolution: resolution,
                    duration: duration, count: count,
                    generateAudio: generateAudio,
                    assets: seedanceAssets()
                ))
            )
        }
        queueStore.enqueueBatch(items)
        batchMessage = "已加入 \(items.count) 条 Seedance 任务到队列"
    }

    private var isLoadingAssets: Bool { assetLoadingCount > 0 }

    private var virtualAssetPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("虚拟人素材库").font(.headline)
                Spacer()
                Button("刷新") {
                    Task { await loadVirtualAssetGroups() }
                }
                .disabled(isLoadingAssets)
            }

            Text(assetConfigMessage)
                .font(.caption)
                .foregroundColor(assetConfigured ? .secondary : .orange)

            HStack(spacing: 8) {
                Picker("素材组", selection: $selectedAssetGroupId) {
                    Text("选择素材组").tag(nil as Int?)
                    ForEach(assetGroups) { group in
                        Text(group.displayName).tag(Optional(group.id))
                    }
                }
                .frame(maxWidth: 260)
                .disabled(!assetConfigured || isLoadingAssets)
                .onChange(of: selectedAssetGroupId) { _, groupId in
                    Task { await loadVirtualAssetItems(groupId: groupId) }
                }

                TextField("新素材组名称", text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .disabled(!assetConfigured || isLoadingAssets)

                Button("新建") {
                    Task { await createVirtualAssetGroup() }
                }
                .disabled(!assetConfigured || newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingAssets)
            }

            HStack(alignment: .top, spacing: 8) {
                TextField("资产名称", text: $importAssetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .disabled(!assetConfigured || selectedAssetGroupId == nil || isLoadingAssets)

                FilePickerRow(label: "人像图", types: [.image], onClear: { importImage = nil }) { data, name, mime in
                    importImage = FileRef(data: data, name: name, mime: mime)
                    if importAssetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        importAssetName = name.replacingOccurrences(of: ".\(URL(fileURLWithPath: name).pathExtension)", with: "")
                    }
                }
                .disabled(!assetConfigured || selectedAssetGroupId == nil || isLoadingAssets)

                Button("上传") {
                    Task { await importVirtualAssetImage() }
                }
                .disabled(!canImportVirtualAsset || isLoadingAssets)
            }

            if !selectedVirtualAssets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("本次已选素材").font(.caption).foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedVirtualAssets) { item in
                                Button {
                                    selectedVirtualAssets.removeAll { $0.id == item.id }
                                } label: {
                                    Label(item.displayName ?? item.arkAssetId ?? "素材", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }

            if isLoadingAssets {
                ProgressView().controlSize(.small)
            }

            if let assetErrorMessage {
                Text(assetErrorMessage).font(.caption).foregroundColor(.red)
            }

            if !assetItems.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160))], spacing: 10) {
                    ForEach(assetItems) { item in
                        virtualAssetCard(item)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
    }

    private var canImportVirtualAsset: Bool {
        selectedAssetGroupId != nil &&
        importImage != nil &&
        !importAssetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        assetConfigured
    }

    private func virtualAssetCard(_ item: SeedanceVirtualAssetItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: item.sourcePublicUrl.flatMap(URL.init(string:))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.secondary.opacity(0.16)
                            .overlay(Image(systemName: "person.crop.square").foregroundColor(.secondary))
                    }
                }
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Button {
                    Task { await refreshVirtualAssetItem(item) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .padding(4)
            }

            Text(item.displayName ?? item.arkAssetId ?? "未命名")
                .font(.caption)
                .lineLimit(1)

            HStack {
                Text(item.lastStatus ?? "未知")
                    .font(.caption2)
                    .foregroundColor(item.isActive ? .green : .secondary)
                Spacer()
                Button(isVirtualAssetSelected(item) ? "已选" : "加入") {
                    toggleVirtualAsset(item)
                }
                .disabled(!item.isActive || (!isVirtualAssetSelected(item) && totalReferenceCount >= 9))
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isVirtualAssetSelected(item) ? Color.accentColor : Color.secondary.opacity(0.18)))
    }
    
    private func startGeneration() {
        if let validationError = validate() {
            errorMessage = validationError
            return
        }
        isGenerating = true; errorMessage = nil; resultTaskIds = []
        Task {
            do {
                let result = try await api.generateSeedanceVideo(
                    prompt: prompt, mode: mode, model: model,
                    ratio: ratio, resolution: resolution,
                    duration: duration, count: count,
                    generateAudio: generateAudio,
                    assets: seedanceAssets()
                )
                if let tasks = result.tasks {
                    resultTaskIds = tasks.map { $0.ourTaskId }
                    for t in tasks {
                        api.addTask(id: t.ourTaskId, type: "Seedance 2.0", desc: String(prompt.prefix(30)))
                    }
                } else {
                    errorMessage = result.message ?? "提交失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func seedanceAssets() -> [SeedanceAsset] {
        if mode == "first_last" {
            return [firstFrame, lastFrame].compactMap { file in
                guard let file else { return nil }
                return SeedanceAsset(type: "image", data: file.data, name: file.name, mime: file.mime, duration: 0)
            }
        }
        let localAssets = referenceImages.map {
            SeedanceAsset(type: "image", data: $0.data, name: $0.name, mime: $0.mime, duration: 0)
        }
        let virtualAssets = selectedVirtualAssets.compactMap { item -> SeedanceAsset? in
            guard let assetUri = item.assetUri ?? item.arkAssetId else { return nil }
            return SeedanceAsset(
                type: "image",
                name: item.displayName ?? item.arkAssetId ?? "资产",
                mime: "image/png",
                size: 1,
                duration: 0,
                dataUrl: assetUri
            )
        }
        return localAssets + virtualAssets
    }

    private func validate() -> String? {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPrompt.count > 8_000 {
            return "提示词过长，最多 8000 个字符"
        }
        if trimmedPrompt.isEmpty && !hasSeedanceInputs {
            return "请填写提示词，或添加参考素材"
        }
        if mode == "reference" && totalReferenceCount > 9 {
            return "全能参考最多 9 张图片"
        }
        if mode == "first_last" && firstFrame == nil {
            return "首尾帧模式至少需要首帧图片"
        }
        return nil
    }

    private var hasSeedanceInputs: Bool {
        if mode == "first_last" {
            return firstFrame != nil || lastFrame != nil
        }
        return totalReferenceCount > 0
    }

    private var totalReferenceCount: Int {
        referenceImages.count + selectedVirtualAssets.count
    }

    private func isVirtualAssetSelected(_ item: SeedanceVirtualAssetItem) -> Bool {
        selectedVirtualAssets.contains(where: { $0.id == item.id })
    }

    private func toggleVirtualAsset(_ item: SeedanceVirtualAssetItem) {
        if isVirtualAssetSelected(item) {
            selectedVirtualAssets.removeAll { $0.id == item.id }
        } else if item.isActive && totalReferenceCount < 9 {
            selectedVirtualAssets.append(item)
        }
    }

    private func loadVirtualAssetGroups() async {
        beginAssetLoading()
        assetErrorMessage = nil
        defer { endAssetLoading() }

        do {
            let config = try await api.getSeedanceVirtualAssetConfig()
            assetConfigured = config.assetApiConfigured == true
            assetConfigMessage = virtualAssetConfigMessage(config)
            guard assetConfigured else {
                assetGroups = []
                assetItems = []
                return
            }

            let response = try await api.getSeedanceVirtualAssetGroups()
            guard response.success else {
                throw APIError.requestFailed(response.message ?? "素材组加载失败")
            }
            assetGroups = response.items ?? []
            if let selectedAssetGroupId, assetGroups.contains(where: { $0.id == selectedAssetGroupId }) {
                await loadVirtualAssetItems(groupId: selectedAssetGroupId)
            } else {
                selectedAssetGroupId = nil
                assetItems = []
            }
        } catch {
            assetErrorMessage = error.localizedDescription
        }
    }

    private func loadVirtualAssetItems(groupId: Int?) async {
        guard let groupId else {
            assetItems = []
            return
        }
        beginAssetLoading()
        assetErrorMessage = nil
        defer { endAssetLoading() }

        do {
            let response = try await api.getSeedanceVirtualAssetItems(groupId: groupId)
            guard response.success else {
                throw APIError.requestFailed(response.message ?? "素材列表加载失败")
            }
            assetItems = response.items ?? []
        } catch {
            assetErrorMessage = error.localizedDescription
        }
    }

    private func createVirtualAssetGroup() async {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        beginAssetLoading()
        assetErrorMessage = nil
        defer { endAssetLoading() }

        do {
            let response = try await api.createSeedanceVirtualAssetGroup(displayName: name)
            guard response.success else {
                throw APIError.requestFailed(response.message ?? "创建素材组失败")
            }
            newGroupName = ""
            let groups = try await api.getSeedanceVirtualAssetGroups()
            assetGroups = groups.items ?? []
            if let id = response.id {
                selectedAssetGroupId = id
                await loadVirtualAssetItems(groupId: id)
            }
        } catch {
            selectedAssetGroupId = nil
            assetErrorMessage = error.localizedDescription
        }
    }

    private func importVirtualAssetImage() async {
        guard let selectedAssetGroupId, let importImage else { return }
        let name = importAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        beginAssetLoading()
        assetErrorMessage = nil
        defer { endAssetLoading() }

        do {
            let response = try await api.importSeedanceVirtualAssetImage(groupId: selectedAssetGroupId, displayName: name, image: importImage)
            guard response.success else {
                throw APIError.requestFailed(response.message ?? "上传素材失败")
            }
            importAssetName = ""
            self.importImage = nil
            await loadVirtualAssetItems(groupId: selectedAssetGroupId)
        } catch {
            assetErrorMessage = error.localizedDescription
        }
    }

    private func refreshVirtualAssetItem(_ item: SeedanceVirtualAssetItem) async {
        beginAssetLoading()
        assetErrorMessage = nil
        defer { endAssetLoading() }

        do {
            let response = try await api.refreshSeedanceVirtualAssetItem(localId: item.id)
            guard response.success else {
                throw APIError.requestFailed(response.message ?? "刷新素材失败")
            }
            await loadVirtualAssetItems(groupId: selectedAssetGroupId)
        } catch {
            assetErrorMessage = error.localizedDescription
        }
    }

    private func virtualAssetConfigMessage(_ config: SeedanceVirtualAssetConfigResponse) -> String {
        if config.assetApiConfigured != true {
            if config.assetAccessKeyPresent == true && config.assetSecretKeyPresent != true {
                return "素材库缺少 secret-key 配置"
            }
            if config.assetAccessKeyPresent != true && config.assetSecretKeyPresent == true {
                return "素材库缺少 access-key 配置"
            }
            return "素材库未配置 AK/SK"
        }
        if config.cosConfigured != true {
            return "素材库接口已配置，请确认 COS 可用"
        }
        return "素材库可用，Active 素材可加入本次全能参考"
    }

    private func beginAssetLoading() {
        assetLoadingCount += 1
    }

    private func endAssetLoading() {
        assetLoadingCount = max(0, assetLoadingCount - 1)
    }
    
    private func opt(_ label: String, _ sel: Binding<String>, _ opts: [(String,String)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Picker("", selection: sel) {
                ForEach(opts, id: \.0) { Text($0.1).tag($0.0) }
            }.pickerStyle(.menu).labelsHidden()
        }
    }
}

// MARK: - Reusable File Picker

struct FilePickerRow: View {
    let label: String
    let types: [UTType]
    var onClear: (() -> Void)? = nil
    var onPick: (Data, String, String) -> Void

    @State private var fileName: String?
    @State private var previewImage: NSImage?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary)
                Button("选择文件...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = types
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        do {
                            let data = try loadValidatedFile(at: url)
                            let mime = url.mimeType()
                            fileName = url.lastPathComponent
                            previewImage = nil
                            if url.isImageType {
                                previewImage = thumbnail(data: data, maxSize: 140)
                            }
                            errorMessage = nil
                            onPick(data, url.lastPathComponent, mime)
                        } catch {
                            clearState()
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if fileName != nil {
                    Button("清除") {
                        clearState()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundColor(.secondary)
                }
            }

            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            } else if let name = fileName {
                Text(name).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption2).foregroundColor(.red)
            }
        }
    }

    private func clearState() {
        fileName = nil
        previewImage = nil
        errorMessage = nil
        onClear?()
    }

    private func thumbnail(data: Data, maxSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: maxSize, height: maxSize))
    }

    private func loadValidatedFile(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        guard let contentType = values.contentType, types.contains(where: { contentType.conforms(to: $0) }) else {
            throw FilePickerError.unsupportedType
        }

        let maxBytes = maxAllowedBytes(for: contentType)
        let fileSize = values.fileSize ?? 0
        guard fileSize > 0 else { throw FilePickerError.emptyFile }
        guard fileSize <= maxBytes else { throw FilePickerError.fileTooLarge(maxBytes: maxBytes) }

        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private func maxAllowedBytes(for type: UTType) -> Int {
        if type.conforms(to: .image) { return 25 * 1024 * 1024 }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return 300 * 1024 * 1024 }
        return 10 * 1024 * 1024
    }
}

enum FilePickerError: LocalizedError {
    case unsupportedType
    case emptyFile
    case fileTooLarge(maxBytes: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "文件类型不支持"
        case .emptyFile:
            return "文件为空"
        case .fileTooLarge(let maxBytes):
            return "文件过大，最大支持 \(maxBytes / 1024 / 1024) MB"
        }
    }
}

extension URL {
    func mimeType() -> String {
        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }

    var isImageType: Bool {
        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.conforms(to: .image)
        }
        return false
    }
}
