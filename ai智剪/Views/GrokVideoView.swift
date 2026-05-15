import SwiftUI
import UniformTypeIdentifiers

struct GrokVideoView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var prompt = ""
    @State private var channel = "budget"
    @State private var mode = "text"
    @State private var ratio = "9:16"
    @State private var resolution = "720p"
    @State private var duration = "6"
    @State private var imageFiles: [FileRef] = []
    @State private var videoFile: FileRef?

    var imageMaxCount: Int {
        if mode == "image" && (channel == "official" || channel == "xai") { return 1 }
        return 7
    }
    var showImagePicker: Bool { mode == "image" || mode == "reference" }
    var showVideoPicker: Bool { mode == "extend" || mode == "edit" }
    var showAspectRatio: Bool { mode == "text" || (channel == "budget" && mode == "image") }
    var showResolution: Bool { mode != "extend" }
    var showDuration: Bool { mode != "edit" }

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskId: String?
    @State private var submittedPriceUsd: String?
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?

    private let channelOptions = [
        ("budget", "低价渠道"),
        ("official", "官方稳定渠道"),
        ("xai", "Grok 官方 API")
    ]

    var durationOptions: [(String, String)] {
        if channel == "official" || channel == "xai" {
            return [("6","6s"),("10","10s")]
        }
        return [("6","6s"),("8","8s"),("10","10s"),("12","12s"),("15","15s"),("20","20s"),("30","30s")]
    }

    var modeOptions: [(String, String)] {
        if channel == "budget" {
            return [("text","文生视频"),("image","图生视频")]
        }
        return [
            ("text","文生视频"),("image","图生视频"),("reference","多图参考"),
            ("extend","视频续写"),("edit","视频编辑")
        ]
    }

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
        }
        .onChange(of: mode) { _, newMode in
            if newMode == "image" {
                imageFiles = Array(imageFiles.prefix(imageMaxCount))
            } else if newMode == "text" || newMode == "extend" || newMode == "edit" {
                imageFiles = []
            }
            if newMode != "extend" && newMode != "edit" {
                videoFile = nil
            }
            if !durationOptions.contains(where: { $0.0 == duration }) {
                duration = durationOptions.first?.0 ?? "6"
            }
        }
        .onChange(of: channel) { _, _ in
            if !modeOptions.contains(where: { $0.0 == mode }) {
                mode = modeOptions.first?.0 ?? "text"
            }
            if !durationOptions.contains(where: { $0.0 == duration }) {
                duration = durationOptions.first?.0 ?? "6"
            }
            if imageFiles.count > imageMaxCount {
                imageFiles = Array(imageFiles.prefix(imageMaxCount))
            }
        }
        .onAppear { applyEditIfNeeded() }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
    }

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .grok(let p) = item.params else { return }
        isBatchMode = false
        prompt = p.prompt
        channel = p.channel
        mode = p.mode
        ratio = p.aspectRatio
        resolution = p.resolution
        duration = p.duration
        imageFiles = p.imageFiles.map { FileRef(data: $0.0, name: $0.1, mime: $0.2) }
        videoFile = p.videoData.flatMap { d in
            FileRef(data: d, name: p.videoName ?? "", mime: p.videoMime ?? "")
        }
        errorMessage = nil
        resultTaskId = nil
        isGenerating = false
        editCoordinator.editingItem = nil
    }

    private var singleModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("提示词").font(.headline)
                TextEditor(text: $prompt)
                    .font(.body).frame(height: 60)
                    .scrollContentBackground(.hidden).padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    opt("渠道", $channel, channelOptions)
                    opt("模式", $mode, modeOptions)
                    if showAspectRatio {
                        opt("画幅", $ratio, [("9:16","9:16"),("16:9","16:9"),("1:1","1:1"),("2:3","2:3"),("3:2","3:2")])
                    }
                    if showResolution {
                        opt("分辨率", $resolution, [("720p","720p"),("480p","480p")])
                    }
                    if showDuration {
                        opt("时长", $duration, durationOptions)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(channelDescription(channel))
                        .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(modeDescription(mode))
                        .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }

            if showImagePicker {
                MultiImagePickerRow(label: "参考图片", files: $imageFiles, maxCount: imageMaxCount)
            }

            if showVideoPicker {
                FilePickerRow(label: "视频素材", types: [.movie, .video], onClear: { videoFile = nil }) { data, name, mime in
                    videoFile = FileRef(data: data, name: name, mime: mime)
                }
            }

            presetRow

            grokEstimateBanner

            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8); Text("提交中...")
                    } else {
                        Label("生成 Grok 视频", systemImage: "brain")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }

            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
            if let tid = resultTaskId {
                TaskPollingView(taskId: tid, pollType: .grok, priceUsd: submittedPriceUsd, api: api)
            }
        }
    }

    private var batchModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("批量提示词").font(.headline)
                    Spacer()
                    Text("\(validGrokBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(validGrokBatchPrompts.isEmpty ? .secondary : .accentColor)
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    opt("渠道", $channel, channelOptions)
                    opt("模式", $mode, modeOptions)
                    if showAspectRatio {
                        opt("画幅", $ratio, [("9:16","9:16"),("16:9","16:9"),("1:1","1:1"),("2:3","2:3"),("3:2","3:2")])
                    }
                    if showResolution {
                        opt("分辨率", $resolution, [("720p","720p"),("480p","480p")])
                    }
                    if showDuration {
                        opt("时长", $duration, durationOptions)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(channelDescription(channel))
                        .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(modeDescription(mode))
                        .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }

            if showImagePicker {
                MultiImagePickerRow(label: "参考图片", files: $imageFiles, maxCount: imageMaxCount)
            }

            if showVideoPicker {
                FilePickerRow(label: "视频素材", types: [.movie, .video], onClear: { videoFile = nil }) { data, name, mime in
                    videoFile = FileRef(data: data, name: name, mime: mime)
                }
            }

            presetRow

            grokEstimateBanner

            HStack {
                Button(action: enqueueGrokBatch) {
                    Label("加入批量队列 (\(validGrokBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validGrokBatchPrompts.isEmpty)

                if !queueStore.items.isEmpty {
                    Text("队列: \(queueStore.pendingCount) 待提交")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let msg = batchMessage { Text(msg).font(.caption).foregroundColor(msg.contains("失败") ? .red : .green) }
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
        }
    }

    private var validGrokBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private var invalidGrokBatchLines: [Int] {
        let lines = batchPrompts.components(separatedBy: "\n")
        return lines.indices.compactMap { i in
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count > 8000 { return i + 1 }
            return nil
        }
    }

    private func enqueueGrokBatch() {
        let invalidLines = invalidGrokBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validGrokBatchPrompts
        guard !prompts.isEmpty else { return }
        for p in prompts {
            if let err = validatePromptLine(p) { batchMessage = err; return }
        }
        if let err = validateSharedInputs() { batchMessage = err; return }
        errorMessage = nil; batchMessage = nil

        let images: [(Data, String, String)] = (mode == "image" || mode == "reference")
            ? imageFiles.map { ($0.data, $0.name, $0.mime) }
            : []
        let vid: (Data, String, String)? = (mode == "extend" || mode == "edit")
            ? videoFile.map { ($0.data, $0.name, $0.mime) }
            : nil

        let items = prompts.map { prompt in
            GenerationQueueItem(
                kind: .grok,
                createdAt: Date(),
                params: .grok(GrokJobParams(
                    prompt: prompt, channel: channel, mode: mode,
                    aspectRatio: ratio, resolution: resolution, duration: duration,
                    imageFiles: images,
                    videoData: vid?.0, videoName: vid?.1, videoMime: vid?.2
                ))
            )
        }
        queueStore.enqueueBatch(items)
        batchMessage = "已加入 \(items.count) 条 Grok 任务到队列"
    }

    private var grokEstimateBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            let channelName = channelDisplayName(channel)
            let modeName = modeOptions.first(where: { $0.0 == mode })?.1 ?? mode
            let batchPrefix: String = {
                guard isBatchMode else { return "" }
                let count = validGrokBatchPrompts.count
                return count > 0 ? "\(count) 条 · " : ""
            }()
            let resolutionText = showResolution ? resolution : ""
            let durationText = showDuration ? " · 时长: \(duration)s" : ""
            Text("\(batchPrefix)渠道: \(channelName) · \(modeName)\(resolutionText.isEmpty ? "" : " · 分辨率: \(resolutionText)")\(durationText)")
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
        let kind = PresetKind.grok
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
                let params = PresetParams.grok(GrokPresetParams(
                    prompt: isBatchMode ? "" : prompt, channel: channel, mode: mode,
                    aspectRatio: ratio, resolution: resolution, duration: duration
                ))
                presetStore.save(name: name, params: params)
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text(isBatchMode ? "仅保存当前参数配置（不包括 Prompt 和素材）" : "保存当前的 Prompt 和参数（不包括素材文件）")
        }
    }

    private func applyPreset(_ preset: Preset) {
        guard case .grok(let p) = preset.params else { return }
        if !isBatchMode { prompt = p.prompt }
        channel = p.channel
        mode = p.mode
        ratio = p.aspectRatio
        resolution = p.resolution
        duration = p.duration
        errorMessage = nil; resultTaskId = nil; isGenerating = false
    }

    private func startGeneration() {
        if let validationError = validate() {
            errorMessage = validationError
            return
        }
        isGenerating = true; errorMessage = nil; resultTaskId = nil
        Task {
            do {
                let images: [(Data, String, String)] = (mode == "image" || mode == "reference")
                    ? imageFiles.map { ($0.data, $0.name, $0.mime) }
                    : []
                let vid: (Data, String, String)? = (mode == "extend" || mode == "edit")
                    ? videoFile.map { ($0.data, $0.name, $0.mime) }
                    : nil
                let result = try await api.generateGrokVideo(
                    prompt: prompt, channel: channel, mode: mode,
                    aspectRatio: ratio, resolution: resolution, duration: duration,
                    imageFiles: images,
                    videoData: vid?.0, videoName: vid?.1, videoMime: vid?.2
                )
                submittedPriceUsd = result.priceUsd
                if let tid = result.taskId {
                    resultTaskId = tid
                    api.addTask(id: tid, type: "Grok 视频", desc: String(prompt.prefix(30)))
                } else {
                    errorMessage = result.message ?? "提交失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func validate() -> String? {
        if let err = validatePromptLine(prompt) { return err }
        return validateSharedInputs()
    }

    private func validatePromptLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 5 { return "提示词至少 5 个字符" }
        if channel == "official" && trimmed.count > 800 { return "官方稳定版提示词不能超过 800 字" }
        if channel == "xai" && trimmed.count > 8_000 { return "Grok 官方 API 提示词不能超过 8000 字" }
        if channel == "budget" && trimmed.count > 20_000 { return "低价渠道提示词不能超过 20000 字" }
        return nil
    }

    private func validateSharedInputs() -> String? {
        if mode == "image" {
            if imageFiles.isEmpty { return "图生视频需上传参考图" }
            if (channel == "official" || channel == "xai") && imageFiles.count > 1 { return "官方图生视频只支持 1 张图片" }
            if imageFiles.count > 7 { return "图片最多 7 张" }
        }
        if mode == "reference" {
            if imageFiles.isEmpty { return "多图参考生视频至少 1 张图片" }
            if imageFiles.count > 7 { return "参考图最多 7 张" }
        }
        if showVideoPicker && videoFile == nil {
            return mode == "extend" ? "视频续写需上传视频" : "编辑视频需上传视频"
        }
        return nil
    }

    private func channelDescription(_ channel: String) -> String {
        switch channel {
        case "official":
            return "官方渠道，支持多图参考、续写、编辑等高级模式"
        case "xai":
            return "Grok 官方 API（xAI），经网站后端提交，支持官方稳定渠道同模式"
        default:
            return "低价渠道，价格优惠，支持更多时长选项（6-30s）"
        }
    }

    private func channelDisplayName(_ channel: String) -> String {
        switch channel {
        case "official": return "官方"
        case "xai": return "Grok 官方 API"
        default: return "低价"
        }
    }

    private func modeDescription(_ mode: String) -> String {
        switch mode {
        case "text":      return "文生视频 — 仅用文字描述生成视频"
        case "image":     return "图生视频 — 输入参考图生成视频"
        case "reference": return "多图参考 — 最多 7 张图片参考生成视频"
        case "extend":    return "视频续写 — 基于已有视频继续生成"
        case "edit":      return "视频编辑 — 编辑已有视频"
        default:          return mode
        }
    }
}
