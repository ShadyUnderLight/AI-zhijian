import SwiftUI
import UniformTypeIdentifiers

struct SeedanceVideoView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore
    @State private var prompt = ""
    @State private var mode = "reference"
    @State private var model = "dreamina-seedance-2-0-260128"
    @State private var ratio = "adaptive"
    @State private var resolution = "720p"
    @State private var duration = 5
    @State private var count = 1
    @State private var generateAudio = true
    @State private var referenceImages: [FileRef] = []
    @State private var referenceAudios: [FileRef] = []
    @State private var referenceVideos: [FileRef] = []
    @State private var firstFrame: FileRef?
    @State private var lastFrame: FileRef?
    @State private var assetConfigured = false
    @State private var assetConfigMessage = "素材库未加载"
    @State private var assetGroups: [SeedanceVirtualAssetGroup] = []
    @State private var selectedAssetGroupId: Int?
    @State private var assetItems: [SeedanceVirtualAssetItem] = []
    @State private var selectedVirtualAssets: [SeedanceVirtualAssetItem] = []
    @State private var pendingVirtualAssetUrls: [String] = []
    @State private var newGroupName = ""
    @State private var importAssetName = ""
    @State private var importImage: FileRef?
    @State private var assetLoadingCount = 0
    @State private var assetErrorMessage: String?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskIds: [String] = []
    @State private var submittedPriceUsd: String?
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?

    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?
    @State private var showBatchConfirm = false

    private let maxReferenceAssets = 9
    private let maxLocalReferencePayloadBytes = 64 * 1024 * 1024

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
        .onAppear { applyEditIfNeeded() }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
    }

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .seedance(let p) = item.params else { return }
        isBatchMode = false
        prompt = p.prompt
        mode = p.mode
        model = p.model
        ratio = p.ratio
        resolution = p.resolution
        duration = p.duration
        count = p.count
        generateAudio = p.generateAudio
        errorMessage = nil
        resultTaskIds = []
        isGenerating = false
        referenceImages = []
        referenceAudios = []
        referenceVideos = []
        firstFrame = nil
        lastFrame = nil
        selectedVirtualAssets = []
        pendingVirtualAssetUrls = []
        if mode == "first_last" {
            firstFrame = p.assets.first?.fileRef
            lastFrame = p.assets.dropFirst().first?.fileRef
        } else {
            referenceImages = p.assets.filter { $0.type == "image" }.compactMap { $0.fileRef }
            referenceAudios = p.assets.filter { $0.type == "audio" }.compactMap { $0.fileRef }
            referenceVideos = p.assets.filter { $0.type == "video" }.compactMap { $0.fileRef }
        }
        let virtualUrls = p.assets.compactMap { $0.fileRef == nil ? $0.assetUri : nil }
        if !virtualUrls.isEmpty {
            pendingVirtualAssetUrls = virtualUrls
            Task { await resolvePendingVirtualAssets() }
        }
        editCoordinator.editingItem = nil
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
                MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: imageReferenceLimit)
                MultiSeedanceFilePickerRow(
                    label: "参考音频",
                    buttonTitle: "选择音频...",
                    types: [.audio],
                    files: $referenceAudios,
                    maxCount: audioReferenceLimit,
                    otherLocalBytes: otherLocalReferenceBytes(excluding: referenceAudios),
                    maxTotalBytes: maxLocalReferencePayloadBytes
                )
                MultiSeedanceFilePickerRow(
                    label: "参考视频",
                    buttonTitle: "选择视频...",
                    types: [.movie, .video],
                    files: $referenceVideos,
                    maxCount: videoReferenceLimit,
                    otherLocalBytes: otherLocalReferenceBytes(excluding: referenceVideos),
                    maxTotalBytes: maxLocalReferencePayloadBytes
                )
                virtualAssetPanel
            } else {
                FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstFrame = nil }) { data, name, mime in
                    firstFrame = FileRef(data: data, name: name, mime: mime)
                }
                FilePickerRow(label: "尾帧图片（可选）", types: [.image], onClear: { lastFrame = nil }) { data, name, mime in
                    lastFrame = FileRef(data: data, name: name, mime: mime)
                }
            }

            presetRow

            seedanceEstimateBanner

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

            if let price = submittedPriceUsd, !price.isEmpty, !resultTaskIds.isEmpty {
                Text("本次提交费用: \(price)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

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
                referenceAudios = []
                referenceVideos = []
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
                    Text("\(validSeedanceBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(validSeedanceBatchPrompts.isEmpty ? .secondary : .accentColor)
                }
                TextEditor(text: $batchPrompts)
                    .font(.body).frame(height: 160)
                    .scrollContentBackground(.hidden).padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Text("每行一条提示词，共享当前参数和素材")
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

            if mode == "reference" {
                MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: imageReferenceLimit)
                MultiSeedanceFilePickerRow(
                    label: "参考音频",
                    buttonTitle: "选择音频...",
                    types: [.audio],
                    files: $referenceAudios,
                    maxCount: audioReferenceLimit,
                    otherLocalBytes: otherLocalReferenceBytes(excluding: referenceAudios),
                    maxTotalBytes: maxLocalReferencePayloadBytes
                )
                MultiSeedanceFilePickerRow(
                    label: "参考视频",
                    buttonTitle: "选择视频...",
                    types: [.movie, .video],
                    files: $referenceVideos,
                    maxCount: videoReferenceLimit,
                    otherLocalBytes: otherLocalReferenceBytes(excluding: referenceVideos),
                    maxTotalBytes: maxLocalReferencePayloadBytes
                )
                virtualAssetPanel
            } else {
                FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstFrame = nil }) { data, name, mime in
                    firstFrame = FileRef(data: data, name: name, mime: mime)
                }
                FilePickerRow(label: "尾帧图片（可选）", types: [.image], onClear: { lastFrame = nil }) { data, name, mime in
                    lastFrame = FileRef(data: data, name: name, mime: mime)
                }
            }

            presetRow

            seedanceEstimateBanner

            HStack {
                let promptCount = validSeedanceBatchPrompts.count
                let totalResults = promptCount * count
                Button(action: prepareSeedanceBatchConfirm) {
                    Label("加入批量队列（\(promptCount) 条 / \(totalResults) 个结果）", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validSeedanceBatchPrompts.isEmpty)
                .confirmationDialog(
                    "确认批量提交",
                    isPresented: $showBatchConfirm,
                    titleVisibility: .visible
                ) {
                    let totalResults = validSeedanceBatchPrompts.count * count
                    Button("确认提交 \(validSeedanceBatchPrompts.count) 条提示词（共 \(totalResults) 个结果）") {
                        enqueueSeedanceBatch()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    let modelName = model.contains("fast") ? "快速版" : "标准版"
                    let totalResults = validSeedanceBatchPrompts.count * count
                    Text("Seedance · \(modelName) · \(resolution) · \(duration)s\n\(validSeedanceBatchPrompts.count) 条提示词 × 每条 \(count) 个结果 = \(totalResults) 个结果\n并发数: \(queueStore.concurrencyLimit)\n费用以实际扣费为准")
                }

                if !queueStore.items.isEmpty {
                    Text("队列: \(queueStore.pendingCount) 待提交")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let msg = batchMessage { Text(msg).font(.caption).foregroundColor(msg.contains("失败") ? .red : .green) }
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
        }
    }

    private var validSeedanceBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private var invalidSeedanceBatchLines: [Int] {
        let lines = batchPrompts.components(separatedBy: "\n")
        return lines.indices.compactMap { i in
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count > 8000 { return i + 1 }
            return nil
        }
    }

    private var seedanceEstimateBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            let modelName = model.contains("fast") ? "快速版" : "标准版"
            let batchPrefix: String = {
                guard isBatchMode else { return "" }
                let count = validSeedanceBatchPrompts.count
                return count > 0 ? "\(count) 条 · " : ""
            }()
            Text("\(batchPrefix)\(modelName) · 分辨率: \(resolution) · \(duration)s × \(count) 条")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text("费用以实际扣费为准")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    private func prepareSeedanceBatchConfirm() {
        let invalidLines = invalidSeedanceBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validSeedanceBatchPrompts
        guard !prompts.isEmpty else { return }
        for p in prompts {
            if let err = validatePromptLine(p) { batchMessage = err; return }
        }
        if let err = validateSharedInputs() { batchMessage = err; return }
        batchMessage = nil
        showBatchConfirm = true
    }

    private func enqueueSeedanceBatch() {
        let invalidLines = invalidSeedanceBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validSeedanceBatchPrompts
        guard !prompts.isEmpty else { return }
        for p in prompts {
            if let err = validatePromptLine(p) { batchMessage = err; return }
        }
        if let err = validateSharedInputs() { batchMessage = err; return }
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

    private var imageReferenceLimit: Int {
        max(referenceImages.count, maxReferenceAssets - referenceAudios.count - referenceVideos.count - selectedVirtualAssets.count)
    }

    private var audioReferenceLimit: Int {
        max(referenceAudios.count, maxReferenceAssets - referenceImages.count - referenceVideos.count - selectedVirtualAssets.count)
    }

    private var videoReferenceLimit: Int {
        max(referenceVideos.count, maxReferenceAssets - referenceImages.count - referenceAudios.count - selectedVirtualAssets.count)
    }

    private var localReferencePayloadBytes: Int {
        referenceImages.localPayloadBytes + referenceAudios.localPayloadBytes + referenceVideos.localPayloadBytes
    }

    private func otherLocalReferenceBytes(excluding files: [FileRef]) -> Int {
        localReferencePayloadBytes - files.localPayloadBytes
    }

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
                let assets = seedanceAssets()
                let result = try await api.generateSeedanceVideo(
                    prompt: prompt, mode: mode, model: model,
                    ratio: ratio, resolution: resolution,
                    duration: duration, count: count,
                    generateAudio: generateAudio,
                    assets: assets
                )
                submittedPriceUsd = result.priceUsd
                if let tasks = result.tasks {
                    resultTaskIds = tasks.map { $0.ourTaskId }
                    let params = SeedanceJobParams(
                        prompt: prompt,
                        mode: mode,
                        model: model,
                        ratio: ratio,
                        resolution: resolution,
                        duration: duration,
                        count: 1,
                        generateAudio: generateAudio,
                        assets: assets
                    )
                    for t in tasks {
                        queueStore.trackSubmittedSingle(
                            GenerationQueueItem(kind: .seedance, createdAt: Date(), params: .seedance(params)),
                            taskId: t.ourTaskId,
                            priceUsd: result.priceUsd
                        )
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
        let audioAssets = referenceAudios.map {
            SeedanceAsset(type: "audio", data: $0.data, name: $0.name, mime: $0.mime, duration: 0)
        }
        let videoAssets = referenceVideos.map {
            SeedanceAsset(type: "video", data: $0.data, name: $0.name, mime: $0.mime, duration: 0)
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
        return localAssets + audioAssets + videoAssets + virtualAssets
    }

    private func validate() -> String? {
        if let err = validatePromptLine(prompt) { return err }
        return validateSharedInputs()
    }

    private func validatePromptLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 8_000 { return "提示词过长，最多 8000 个字符" }
        if trimmed.isEmpty && !hasSeedanceInputs {
            return "请填写提示词，或添加参考素材"
        }
        return nil
    }

    private func validateSharedInputs() -> String? {
        if mode == "reference" && totalReferenceCount > 9 {
            return "全能参考最多 9 个素材"
        }
        if mode == "reference" && localReferencePayloadBytes > maxLocalReferencePayloadBytes {
            return "本地参考素材合计最多 \(maxLocalReferencePayloadBytes / 1024 / 1024) MB，请减少文件或改用素材库"
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
        referenceImages.count + referenceAudios.count + referenceVideos.count + selectedVirtualAssets.count
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

            // Always try to restore pending virtual assets first
            await resolvePendingVirtualAssets()

            // Then fall back to normal group selection
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

    private func resolvePendingVirtualAssets() async {
        guard !pendingVirtualAssetUrls.isEmpty, !assetGroups.isEmpty else { return }

        var matched: [SeedanceVirtualAssetItem] = []
        var matchedGroupId: Int?

        for group in assetGroups {
            do {
                let response = try await api.getSeedanceVirtualAssetItems(groupId: group.id)
                guard response.success else { continue }
                let items = response.items ?? []
                let groupMatched = items.filter { item in
                    pendingVirtualAssetUrls.contains { url in
                        url == item.assetUri || url == item.arkAssetId
                    }
                }
                if !groupMatched.isEmpty {
                    matched.append(contentsOf: groupMatched)
                    if matchedGroupId == nil { matchedGroupId = group.id }
                }
            } catch {
                continue
            }
            if matched.count >= pendingVirtualAssetUrls.count { break }
        }

        if !matched.isEmpty {
            selectedVirtualAssets = Array(Set(matched))
            pendingVirtualAssetUrls = []
            if let gid = matchedGroupId {
                selectedAssetGroupId = gid
                await loadVirtualAssetItems(groupId: gid)
            }
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

    // MARK: - Preset

    private var presetRow: some View {
        let kind = PresetKind.seedance
        let available = presetStore.presets(for: kind)
        return HStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.caption).foregroundColor(.secondary)
            if available.isEmpty {
                Text("暂无预设").font(.caption).foregroundColor(.secondary)
            } else {
                Picker("", selection: $selectedPresetId) {
                    Text("选择预设...").tag(nil as String?)
                    ForEach(available) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                }
                .pickerStyle(.menu).frame(maxWidth: 200)
                .onChange(of: selectedPresetId) { _, id in
                    guard let id, let preset = available.first(where: { $0.id == id }) else { return }
                    applyPreset(preset)
                }
            }
            Button("保存") { newPresetName = ""; showSavePresetAlert = true }
                .buttonStyle(.bordered).controlSize(.small).font(.caption)
            if let id = selectedPresetId, available.contains(where: { $0.id == id }) {
                Button("删除") { presetStore.delete(id); selectedPresetId = nil }
                    .buttonStyle(.borderless).controlSize(.small).font(.caption).foregroundColor(.red)
            }
        }
        .padding(6).background(Color.secondary.opacity(0.06)).cornerRadius(6)
        .alert("保存预设", isPresented: $showSavePresetAlert) {
            TextField("预设名称", text: $newPresetName)
            Button("取消", role: .cancel) {}
            Button("保存") {
                let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let params = PresetParams.seedance(SeedancePresetParams(
                    prompt: isBatchMode ? "" : prompt, mode: mode, model: model, ratio: ratio,
                    resolution: resolution, duration: duration, count: count,
                    generateAudio: generateAudio
                ))
                presetStore.save(name: name, params: params)
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text(isBatchMode ? "仅保存当前参数配置（不包括 Prompt 和素材）" : "保存当前的 Prompt 和参数（不包括素材文件）")
        }
    }

    private func applyPreset(_ preset: Preset) {
        guard case .seedance(let p) = preset.params else { return }
        if !isBatchMode { prompt = p.prompt }
        mode = p.mode
        model = p.model
        ratio = p.ratio
        resolution = p.resolution
        duration = p.duration
        count = p.count
        generateAudio = p.generateAudio
        errorMessage = nil; resultTaskIds = []; isGenerating = false
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
    @State private var imageWidth: Int?
    @State private var imageHeight: Int?
    @State private var fileSize: Int?
    @State private var formatName: String?
    @State private var mediaDuration: Double?
    @State private var metadataTask: Task<Void, Never>?
    @State private var selectionID = UUID()

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
                            let currentID = UUID()
                            selectionID = currentID

                            metadataTask?.cancel()

                            fileName = url.lastPathComponent
                            fileSize = data.count
                            formatName = formatDisplayName(for: url, mime: mime)
                            previewImage = nil
                            imageWidth = nil
                            imageHeight = nil
                            mediaDuration = nil

                            if url.isImageType {
                                previewImage = thumbnail(data: data, maxSize: 140)
                                let dims = imageDimensions(data: data)
                                imageWidth = dims?.width
                                imageHeight = dims?.height
                            } else if mime.hasPrefix("video/") || mime.hasPrefix("audio/") {
                                metadataTask = Task {
                                    if let meta = await MediaMetadataHelper.extractMetadata(from: url) {
                                        guard !Task.isCancelled, selectionID == currentID else { return }
                                        mediaDuration = meta.duration
                                        if let res = meta.resolution {
                                            let parts = res.split(separator: "×")
                                            if parts.count == 2 {
                                                imageWidth = Int(parts[0])
                                                imageHeight = Int(parts[1])
                                            }
                                        }
                                    }
                                    if mime.hasPrefix("video/") {
                                        if let frame = await MediaMetadataHelper.extractVideoFirstFrame(from: url, maxSize: 140) {
                                            guard !Task.isCancelled, selectionID == currentID else { return }
                                            previewImage = frame
                                        }
                                    }
                                }
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
                VStack(alignment: .leading, spacing: 4) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    metadataLine
                }
            } else if let name = fileName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    metadataLine
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption2).foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var metadataLine: some View {
        let parts: [String] = [
            mediaDuration.map { FileMetadataFormatter.formatDuration($0) },
            imageWidth.flatMap { w in imageHeight.map { h in "\(w)×\(h)" } },
            fileSize.map { FileMetadataFormatter.formatFileSize($0) },
            formatName
        ].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func clearState() {
        metadataTask?.cancel()
        metadataTask = nil
        selectionID = UUID()
        fileName = nil
        previewImage = nil
        errorMessage = nil
        imageWidth = nil
        imageHeight = nil
        fileSize = nil
        formatName = nil
        mediaDuration = nil
        onClear?()
    }

    private func imageDimensions(data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let w = props[kCGImagePropertyPixelWidth] as? Int
        let h = props[kCGImagePropertyPixelHeight] as? Int
        guard let width = w, let height = h else { return nil }
        return (width, height)
    }

    private func formatDisplayName(for url: URL, mime: String) -> String {
        let ext = url.pathExtension.uppercased()
        if !ext.isEmpty { return ext }
        if let utType = UTType(mimeType: mime) {
            return utType.localizedDescription ?? mime
        }
        return mime
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
        if type.conforms(to: .audio) { return 100 * 1024 * 1024 }
        return 10 * 1024 * 1024
    }
}

struct MultiSeedanceFilePickerRow: View {
    let label: String
    let buttonTitle: String
    let types: [UTType]
    @Binding var files: [FileRef]
    let maxCount: Int
    let otherLocalBytes: Int
    let maxTotalBytes: Int

    @State private var errorMessage: String?
    @State private var fileMetadata: [String: MediaMetadata] = [:]
    @State private var metadataTasks: [String: Task<Void, Never>] = [:]

    private var selectedLocalBytes: Int { files.localPayloadBytes }
    private var remainingTotalBytes: Int {
        max(0, maxTotalBytes - otherLocalBytes - selectedLocalBytes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary)
                Button(buttonTitle) {
                    pickFiles()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(files.count >= maxCount || remainingTotalBytes <= 0)

                if !files.isEmpty {
                    Button("清除") {
                        cancelAllMetadataTasks()
                        files = []
                        fileMetadata = [:]
                        errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                Text("\(files.count)/\(maxCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\((otherLocalBytes + selectedLocalBytes) / 1024 / 1024)/\(maxTotalBytes / 1024 / 1024) MB")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !files.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(files.indices, id: \.self) { index in
                            let key = fileKey(files[index])
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: iconName(for: files[index].mime))
                                        .foregroundColor(.secondary)
                                    Text(files[index].name)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                fileMetadataLine(file: files[index], key: key)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .task(id: fileSignature) {
            loadMetadataForCurrentFiles()
        }
    }

    @ViewBuilder
    private func fileMetadataLine(file: FileRef, key: String) -> some View {
        let meta = fileMetadata[key]
        let parts: [String] = [
            meta?.duration.map { FileMetadataFormatter.formatDuration($0) },
            meta?.resolution,
            FileMetadataFormatter.formatFileSize(file.data.count)
        ].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var fileSignature: String {
        files.map { "\($0.name):\($0.mime):\($0.data.count)" }.joined(separator: "|")
    }

    private func fileKey(_ file: FileRef) -> String {
        let prefixBytes = min(file.data.count, 4096)
        let hash = file.data.prefix(prefixBytes).reduce(0) { ($0 &* 31) &+ UInt64($1) }
        return "\(file.name):\(file.mime):\(file.data.count):\(hash)"
    }

    private func loadMetadataForCurrentFiles() {
        let currentKeys = Set(files.map { fileKey($0) })

        for key in metadataTasks.keys where !currentKeys.contains(key) {
            metadataTasks[key]?.cancel()
            metadataTasks.removeValue(forKey: key)
            fileMetadata.removeValue(forKey: key)
        }

        for file in files {
            let key = fileKey(file)
            guard fileMetadata[key] == nil, metadataTasks[key] == nil else { continue }
            let mime = file.mime
            guard mime.hasPrefix("video/") || mime.hasPrefix("audio/") else { continue }

            let task = Task {
                if let meta = await MediaMetadataHelper.extractMetadata(from: file.data, mime: mime) {
                    guard !Task.isCancelled else { return }
                    fileMetadata[key] = meta
                }
                metadataTasks.removeValue(forKey: key)
            }
            metadataTasks[key] = task
        }
    }

    private func cancelAllMetadataTasks() {
        for task in metadataTasks.values { task.cancel() }
        metadataTasks.removeAll()
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            do {
                guard !panel.urls.isEmpty else { return }
                let remainingCount = maxCount - files.count
                guard remainingCount > 0, panel.urls.count <= remainingCount else {
                    throw SeedanceFilePickerError.tooManyFiles(maxCount: maxCount)
                }

                var selected: [FileRef] = []
                var failedCount = 0
                var firstError: Error?
                var pendingBytes = 0

                for url in panel.urls {
                    do {
                        let loaded = try loadValidatedFile(at: url, additionalBytes: pendingBytes)
                        pendingBytes += loaded.data.count
                        selected.append(FileRef(data: loaded.data, name: url.lastPathComponent, mime: loaded.mime))
                    } catch {
                        failedCount += 1
                        if firstError == nil { firstError = error }
                    }
                }

                files.append(contentsOf: selected)
                if let firstError {
                    errorMessage = failedCount == 1
                        ? firstError.localizedDescription
                        : "\(firstError.localizedDescription)，另有 \(failedCount - 1) 个文件未添加"
                } else {
                    errorMessage = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadValidatedFile(at url: URL, additionalBytes: Int) throws -> (data: Data, mime: String) {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        guard let contentType = values.contentType, types.contains(where: { contentType.conforms(to: $0) }) else {
            throw SeedanceFilePickerError.unsupportedType
        }

        let fileSize = values.fileSize ?? 0
        guard fileSize > 0 else { throw SeedanceFilePickerError.emptyFile }
        let maxBytes = min(maxAllowedBytes(for: contentType), max(0, remainingTotalBytes - additionalBytes))
        guard fileSize <= maxBytes else { throw SeedanceFilePickerError.fileTooLarge(maxBytes: maxBytes) }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return (data, contentType.preferredMIMEType ?? url.mimeType())
    }

    private func maxAllowedBytes(for type: UTType) -> Int {
        if type.conforms(to: .audio) { return 100 * 1024 * 1024 }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return 300 * 1024 * 1024 }
        return 25 * 1024 * 1024
    }

    private func iconName(for mime: String) -> String {
        if mime.hasPrefix("audio/") { return "waveform" }
        if mime.hasPrefix("video/") { return "film" }
        return "doc"
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

enum SeedanceFilePickerError: LocalizedError {
    case unsupportedType
    case emptyFile
    case tooManyFiles(maxCount: Int)
    case fileTooLarge(maxBytes: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "文件类型不支持"
        case .emptyFile:
            return "文件为空"
        case .tooManyFiles(let maxCount):
            return "参考素材最多 \(maxCount) 个"
        case .fileTooLarge(let maxBytes):
            if maxBytes <= 0 {
                return "本地参考素材已达到容量上限"
            }
            if maxBytes < 1024 * 1024 {
                return "本地参考素材剩余容量不足 1 MB"
            }
            return "文件过大，剩余最大支持 \(maxBytes / 1024 / 1024) MB"
        }
    }
}

private extension Array where Element == FileRef {
    var localPayloadBytes: Int {
        reduce(0) { $0 + $1.data.count }
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
