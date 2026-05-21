import SwiftUI

struct WanVideoView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var mode = "image"
    @State private var prompt = ""
    @State private var width = 720
    @State private var height = 1280
    @State private var seconds = 5
    @State private var enable48G = false
    @State private var imageData: Data?
    @State private var imageName: String?
    @State private var imageMime: String?
    @State private var firstFrame: FileRef?
    @State private var lastFrame: FileRef?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var taskId: String?
    @State private var submittedPriceUsd: String?
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?
    @State private var showBatchConfirm = false

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
        .onAppear { applyEditIfNeeded(); applyRecordIfNeeded() }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
        .onChange(of: editCoordinator.applyRecord?.id) { _, _ in applyRecordIfNeeded() }
    }

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .wan(let p) = item.params else { return }
        isBatchMode = false
        mode = p.mode
        prompt = p.prompt
        width = p.width
        height = p.height
        seconds = p.seconds
        enable48G = p.enable48G
        imageData = p.imageData
        imageName = p.imageName
        imageMime = p.imageMime
        firstFrame = p.firstFrame
        lastFrame = p.lastFrame
        errorMessage = nil
        taskId = nil
        isGenerating = false
        editCoordinator.editingItem = nil
    }

    private func applyRecordIfNeeded() {
        guard let record = editCoordinator.applyRecord else { return }
        defer { editCoordinator.applyRecord = nil }
        guard let snapshot = record.paramsSnapshot,
              let data = snapshot.data(using: .utf8),
              let params = try? JSONDecoder().decode(WorkRecordParams.self, from: data),
              case .wan(let modeVal, let wVal, let hVal, let sVal, let g48Val) = params
        else { return }
        isBatchMode = false
        mode = modeVal
        prompt = record.prompt
        width = wVal
        height = hVal
        seconds = sVal
        enable48G = g48Val
        imageData = nil
        imageName = nil
        imageMime = nil
        firstFrame = nil
        lastFrame = nil
        errorMessage = nil
        taskId = nil
        isGenerating = false
    }

    private var singleModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $mode) {
                Text("图生视频").tag("image")
                Text("首尾帧").tag("first_last")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            VStack(alignment: .leading, spacing: 6) {
                Text("提示词").font(.headline).accessibilityIdentifier("wan-prompt-heading")
                TextField(mode == "first_last" ? "描述首尾帧之间的变化（可选）" : "描述动作...", text: $prompt)
                    .textFieldStyle(.roundedBorder)
            }

            if mode == "image" {
                HStack(spacing: 12) {
                    intField("宽度", $width)
                    intField("高度", $height)
                    intField("秒数", $seconds)
                }
                FilePickerRow(label: "输入图片", types: [.image], onClear: { imageData = nil; imageName = nil; imageMime = nil }) { data, name, mime in
                    imageData = data; imageName = name; imageMime = mime
                }
            } else {
                HStack(spacing: 12) {
                    intField("秒数", $seconds)
                    Toggle("48G 队列", isOn: $enable48G)
                        .toggleStyle(.checkbox)
                }
                FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstFrame = nil }) { data, name, mime in
                    firstFrame = FileRef(data: data, name: name, mime: mime)
                }
                FilePickerRow(label: "尾帧图片", types: [.image], onClear: { lastFrame = nil }) { data, name, mime in
                    lastFrame = FileRef(data: data, name: name, mime: mime)
                }
            }

            presetRow

            wanEstimateBanner

            HStack {
                Button(action: startGeneration) {
                    Label("生成视频", systemImage: "film")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isGenerating)
            }

            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
            if let tid = taskId {
                TaskPollingView(taskId: tid, pollType: .wan, priceUsd: submittedPriceUsd, api: api)
            }
        }
        .onChange(of: mode) { _, newMode in
            taskId = nil; errorMessage = nil
            if newMode == "image" { firstFrame = nil; lastFrame = nil }
            else { imageData = nil; imageName = nil; imageMime = nil }
        }
    }

    private var batchModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $mode) {
                Text("图生视频").tag("image")
                Text("首尾帧").tag("first_last")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("批量提示词").font(.headline)
                    Spacer()
                    Text("\(validWanBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(validWanBatchPrompts.isEmpty ? .secondary : .accentColor)
                }
                TextEditor(text: $batchPrompts)
                    .font(.body).frame(height: 160)
                    .scrollContentBackground(.hidden).padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Text(mode == "first_last" ? "每行一条提示词（可选），共享首尾帧参数" : "每行一条提示词，共享图片和尺寸参数")
                    .font(.caption2).foregroundColor(.secondary)
            }

            if mode == "image" {
                HStack(spacing: 12) {
                    intField("宽度", $width)
                    intField("高度", $height)
                    intField("秒数", $seconds)
                }
                FilePickerRow(label: "输入图片", types: [.image], onClear: { imageData = nil; imageName = nil; imageMime = nil }) { data, name, mime in
                    imageData = data; imageName = name; imageMime = mime
                }
            } else {
                HStack(spacing: 12) {
                    intField("秒数", $seconds)
                    Toggle("48G 队列", isOn: $enable48G)
                        .toggleStyle(.checkbox)
                }
                FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstFrame = nil }) { data, name, mime in
                    firstFrame = FileRef(data: data, name: name, mime: mime)
                }
                FilePickerRow(label: "尾帧图片", types: [.image], onClear: { lastFrame = nil }) { data, name, mime in
                    lastFrame = FileRef(data: data, name: name, mime: mime)
                }
            }

            presetRow

            wanEstimateBanner

            HStack {
                Button(action: prepareWanBatchConfirm) {
                    Label("加入批量队列 (\(validWanBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validWanBatchPrompts.isEmpty)
                .confirmationDialog(
                    "确认批量提交",
                    isPresented: $showBatchConfirm,
                    titleVisibility: .visible
                ) {
                    Button("确认提交 \(validWanBatchPrompts.count) 条任务") {
                        enqueueWanBatch()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    let modeName = mode == "image" ? "图生视频" : "首尾帧"
                    let sizeInfo = mode == "image" ? " · \(width)×\(height)" : ""
                    Text("Wan 视频 · \(modeName)\(sizeInfo) · \(seconds)s\n并发数: \(queueStore.concurrencyLimit)\n费用以实际扣费为准")
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

    private var validWanBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private var invalidWanBatchLines: [Int] {
        let lines = batchPrompts.components(separatedBy: "\n")
        return lines.indices.compactMap { i in
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count > 8000 { return i + 1 }
            return nil
        }
    }

    private func prepareWanBatchConfirm() {
        let invalidLines = invalidWanBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validWanBatchPrompts
        guard !prompts.isEmpty else { return }
        if let err = wanBatchValidate() { batchMessage = err; return }
        batchMessage = nil
        showBatchConfirm = true
    }

    private func enqueueWanBatch() {
        let invalidLines = invalidWanBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validWanBatchPrompts
        guard !prompts.isEmpty else { return }
        if let err = wanBatchValidate() { batchMessage = err; return }
        errorMessage = nil; batchMessage = nil

        let items = prompts.map { prompt in
            GenerationQueueItem(
                kind: .wan,
                createdAt: Date(),
                params: .wan(WanJobParams(
                    mode: mode, prompt: prompt, width: width, height: height,
                    seconds: seconds, enable48G: enable48G,
                    imageData: imageData, imageName: imageName, imageMime: imageMime,
                    firstFrame: firstFrame, lastFrame: lastFrame
                ))
            )
        }
        queueStore.enqueueBatch(items)
        batchMessage = "已加入 \(items.count) 条 Wan 任务到队列"
    }

    private func wanBatchValidate() -> String? {
        guard width > 0, height > 0, seconds > 0, seconds <= 30 else {
            return "宽高和秒数必须为正数，秒数最大 30"
        }
        if mode == "image" && imageData == nil { return "请先选择输入图片" }
        if mode == "first_last" {
            if firstFrame == nil { return "请先选择首帧图片" }
            if lastFrame == nil { return "请先选择尾帧图片" }
        }
        return nil
    }

    private var parsedWanBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private var wanEstimateBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            let batchPrefix: String = {
                guard isBatchMode else { return "" }
                let count = validWanBatchPrompts.count
                return count > 0 ? "\(count) 条 · " : ""
            }()
            let modeName = mode == "image" ? "图生视频" : "首尾帧"
            Text("\(batchPrefix)模式: \(modeName) · 秒数: \(seconds)s\(mode == "image" ? " · 分辨率: \(width)×\(height)" : "")")
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

    private var canSubmit: Bool {
        if mode == "image" {
            return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData != nil
        }
        return firstFrame != nil && lastFrame != nil
    }

    private func intField(_ label: String, _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            TextField(label, value: value, format: .number).textFieldStyle(.roundedBorder).frame(width: 80)
        }
    }

    private func startGeneration() {
        guard width > 0, height > 0, seconds > 0, seconds <= 30 else {
            errorMessage = "宽高和秒数必须为正数，秒数最大 30"
            return
        }
        guard mode == "image" || (firstFrame != nil && lastFrame != nil) else {
            errorMessage = "请先选择首帧和尾帧图片"
            return
        }
        isGenerating = true; errorMessage = nil; taskId = nil
        Task {
            do {
                let result: TaskSubmitResponse
                if mode == "image" {
                    guard let data = imageData, let name = imageName, let mime = imageMime else { return }
                    result = try await api.generateWanVideo(
                        imageData: data, fileName: name, mimeType: mime,
                        prompt: prompt, width: width, height: height, seconds: seconds
                    )
                } else {
                    guard let firstFrame, let lastFrame else { return }
                    result = try await api.generateWanFirstLastVideo(
                        firstFrame: firstFrame,
                        lastFrame: lastFrame,
                        prompt: prompt,
                        seconds: seconds,
                        enable48G: enable48G
                    )
                }
                submittedPriceUsd = result.priceUsd
                if let tid = result.taskId {
                    taskId = tid
                    let item = GenerationQueueItem(
                        kind: .wan,
                        createdAt: Date(),
                        params: .wan(WanJobParams(
                            mode: mode,
                            prompt: prompt,
                            width: width,
                            height: height,
                            seconds: seconds,
                            enable48G: enable48G,
                            imageData: imageData,
                            imageName: imageName,
                            imageMime: imageMime,
                            firstFrame: firstFrame,
                            lastFrame: lastFrame
                        ))
                    )
                    queueStore.trackSubmittedSingle(item, taskId: tid, priceUsd: result.priceUsd)
                } else {
                    errorMessage = result.message ?? "提交失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    // MARK: - Preset

    private var presetRow: some View {
        let kind = PresetKind.wan
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
                let params = PresetParams.wan(WanPresetParams(
                    mode: mode, prompt: isBatchMode ? "" : prompt,
                    width: width, height: height, seconds: seconds,
                    enable48G: enable48G
                ))
                presetStore.save(name: name, params: params)
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text(isBatchMode ? "仅保存当前参数配置（文件不保存）" : "保存当前的 Prompt 和参数（文件不保存）")
        }
    }

    private func applyPreset(_ preset: Preset) {
        guard case .wan(let p) = preset.params else { return }
        if !isBatchMode { prompt = p.prompt }
        mode = p.mode
        width = p.width
        height = p.height
        seconds = p.seconds
        enable48G = p.enable48G
        errorMessage = nil; taskId = nil; isGenerating = false
    }
}
