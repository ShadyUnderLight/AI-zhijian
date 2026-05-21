import SwiftUI
import UniformTypeIdentifiers
import AVKit

struct ImageGenView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var prompt = ""
    @State private var channel = "official"
    @State private var ratio = "9:16"
    @State private var resolution = "2k"
    @State private var quality = "medium"
    @State private var photoReal = false
    @State private var referenceImages: [FileRef] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskId: String?
    @State private var submittedPriceUsd: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?
    @State private var showBatchConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Mode picker
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
        .frame(minWidth: 500)
        .onAppear { applyEditIfNeeded(); applyRecordIfNeeded() }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
        .onChange(of: editCoordinator.applyRecord?.id) { _, _ in applyRecordIfNeeded() }
    }

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .gptImage(let p) = item.params else { return }
        isBatchMode = false
        prompt = p.prompt
        channel = p.channel
        ratio = p.aspectRatio
        resolution = p.resolution
        quality = p.quality
        photoReal = p.photoReal
        referenceImages = p.referenceImages
        errorMessage = nil
        resultTaskId = nil
        isGenerating = false
        editCoordinator.editingItem = nil
    }

    private func applyRecordIfNeeded() {
        guard let record = editCoordinator.applyRecord else { return }
        guard let snapshot = record.paramsSnapshot,
              let data = snapshot.data(using: .utf8),
              let params = try? JSONDecoder().decode(WorkRecordParams.self, from: data),
              case .gptImage(let channelVal, let ratioVal, let resVal, let qualityVal, let photoRealVal) = params
        else { return }
        isBatchMode = false
        prompt = record.prompt
        channel = channelVal
        ratio = ratioVal
        resolution = resVal
        quality = qualityVal
        photoReal = photoRealVal
        referenceImages = []
        errorMessage = nil
        resultTaskId = nil
        isGenerating = false
        editCoordinator.applyRecord = nil
    }

    private var singleModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("提示词").font(.headline).accessibilityIdentifier("imagegen-prompt-heading")
                TextEditor(text: $prompt)
                    .font(.body)
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    optionPicker("渠道", selection: $channel, options: [
                        ("official", "官方"),
                        ("budget", "低价")
                    ])
                    optionPicker("画幅", selection: $ratio, options: [
                        ("9:16", "9:16"), ("16:9", "16:9"), ("1:1", "1:1"),
                        ("2:3", "2:3"), ("3:2", "3:2"), ("4:3", "4:3"),
                        ("3:4", "3:4"), ("4:5", "4:5"), ("5:4", "5:4"), ("21:9", "21:9")
                    ])
                    optionPicker("分辨率", selection: $resolution, options: [
                        ("1k", "1K"), ("2k", "2K"), ("4k", "4K")
                    ])
                    optionPicker("质量", selection: $quality, options: [
                        ("low", "低"), ("medium", "中"), ("high", "高")
                    ])
                }
                Text(channel == "official" ? "官方 GPT-Image-2，效果稳定" : "低价渠道，价格优惠，适合快速测试")
                    .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Toggle("真实感增强", isOn: $photoReal)
                .disabled(!referenceImages.isEmpty)

            MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 10)

            presetRow

            estimateBanner(channel: channel, resolution: resolution, quality: quality, photoReal: photoReal, batchCount: nil)

            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8)
                        Text("生成中...")
                    } else {
                        Label(referenceImages.isEmpty ? "生成图片" : "图生图", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }

            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption)
            }

            if let taskId = resultTaskId {
                TaskPollingView(taskId: taskId, pollType: .image, priceUsd: submittedPriceUsd, api: api)
            }
        }
        .onChange(of: referenceImages.count) { _, count in
            if count > 0 {
                photoReal = false
            }
        }
    }

    private var batchModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("批量提示词").font(.headline)
                    Spacer()
                    Text("\(parsedBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(parsedBatchPrompts.isEmpty ? .secondary : .accentColor)
                }
                TextEditor(text: $batchPrompts)
                    .font(.body)
                    .frame(height: 160)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Text("每行一条提示词，空行自动忽略")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    optionPicker("渠道", selection: $channel, options: [
                        ("official", "官方"),
                        ("budget", "低价")
                    ])
                    optionPicker("画幅", selection: $ratio, options: [
                        ("9:16", "9:16"), ("16:9", "16:9"), ("1:1", "1:1"),
                        ("2:3", "2:3"), ("3:2", "3:2"), ("4:3", "4:3"),
                        ("3:4", "3:4"), ("4:5", "4:5"), ("5:4", "5:4"), ("21:9", "21:9")
                    ])
                    optionPicker("分辨率", selection: $resolution, options: [
                        ("1k", "1K"), ("2k", "2K"), ("4k", "4K")
                    ])
                    optionPicker("质量", selection: $quality, options: [
                        ("low", "低"), ("medium", "中"), ("high", "高")
                    ])
                }
                Text(channel == "official" ? "官方 GPT-Image-2，效果稳定" : "低价渠道，价格优惠，适合快速测试")
                    .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Toggle("真实感增强", isOn: $photoReal)
                .disabled(!referenceImages.isEmpty)

            MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 10)

            presetRow

            estimateBanner(channel: channel, resolution: resolution, quality: quality, photoReal: photoReal, batchCount: parsedBatchPrompts.count)

            HStack {
                Button(action: prepareBatchConfirm) {
                    Label("加入批量队列 (\(parsedBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedBatchPrompts.isEmpty)
                .confirmationDialog(
                    "确认批量提交",
                    isPresented: $showBatchConfirm,
                    titleVisibility: .visible
                ) {
                    Button("确认提交 \(parsedBatchPrompts.count) 条任务") {
                        enqueueBatch()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    let channelName = channel == "official" ? "官方" : "低价"
                    let qualityName: String = {
                        switch quality { case "low": return "低"; case "high": return "高"; default: return "中" }
                    }()
                    Text("GPT-Image-2 · \(channelName)渠道 · \(resolution) · 质量\(qualityName)\(photoReal ? " · 真实感" : "")\n并发数: \(queueStore.concurrencyLimit)\n费用以实际扣费为准")
                }

                if !queueStore.items.isEmpty {
                    Text("队列: \(queueStore.pendingCount) 待提交")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let msg = batchMessage {
                Text(msg)
                    .foregroundColor(msg.contains("失败") ? .red : .green)
                    .font(.caption)
            }

            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
    }

    private var parsedBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private var invalidBatchLines: [Int] {
        let lines = batchPrompts.components(separatedBy: "\n")
        return lines.indices.compactMap { i in
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count > 8000 { return i + 1 }
            return nil
        }
    }

    private func prepareBatchConfirm() {
        let invalidLines = invalidBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限，请修正后再提交"
            return
        }
        let prompts = parsedBatchPrompts
        guard !prompts.isEmpty else { return }
        if referenceImages.count > 10 {
            batchMessage = "参考图片最多 10 张"
            return
        }
        batchMessage = nil
        showBatchConfirm = true
    }

    private func enqueueBatch() {
        let invalidLines = invalidBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限，请修正后再提交"
            return
        }
        let prompts = parsedBatchPrompts
        guard !prompts.isEmpty else { return }
        if referenceImages.count > 10 {
            batchMessage = "参考图片最多 10 张"
            return
        }
        errorMessage = nil
        batchMessage = nil

        let items: [GenerationQueueItem] = prompts.map { prompt in
            GenerationQueueItem(
                kind: .gptImage,
                createdAt: Date(),
                params: .gptImage(GptImageJobParams(
                    prompt: prompt,
                    channel: channel,
                    aspectRatio: ratio,
                    resolution: resolution,
                    quality: quality,
                    photoReal: referenceImages.isEmpty && photoReal,
                    referenceImages: referenceImages
                ))
            )
        }
        queueStore.enqueueBatch(items)
        batchMessage = "已加入 \(items.count) 条任务到队列"
    }

    private func startGeneration() {
        if let validationError = validate() {
            errorMessage = validationError
            return
        }
        isGenerating = true
        errorMessage = nil
        resultTaskId = nil

        Task {
            do {
                let result: TaskSubmitResponse
                if referenceImages.isEmpty {
                    result = try await api.generateImage(
                        prompt: prompt,
                        channel: channel,
                        aspectRatio: ratio,
                        resolution: resolution,
                        quality: quality,
                        photoReal: photoReal
                    )
                } else {
                    result = try await api.generateImageToImage(
                        prompt: prompt,
                        channel: channel,
                        aspectRatio: ratio,
                        resolution: resolution,
                        quality: quality,
                        referenceImages: referenceImages
                    )
                }
                submittedPriceUsd = result.priceUsd
                if let taskId = result.ourTaskId {
                    resultTaskId = taskId
                    let item = GenerationQueueItem(
                        kind: .gptImage,
                        createdAt: Date(),
                        params: .gptImage(GptImageJobParams(
                            prompt: prompt,
                            channel: channel,
                            aspectRatio: ratio,
                            resolution: resolution,
                            quality: quality,
                            photoReal: referenceImages.isEmpty && photoReal,
                            referenceImages: referenceImages
                        ))
                    )
                    queueStore.trackSubmittedSingle(item, taskId: taskId, priceUsd: result.priceUsd)
                } else {
                    errorMessage = result.message ?? "未能获取任务ID"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func validate() -> String? {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPrompt.isEmpty { return "提示词不能为空" }
        if trimmedPrompt.count > 8_000 { return "提示词过长，最多 8000 个字符" }
        if referenceImages.count > 10 { return "参考图片最多 10 张" }
        return nil
    }

    // MARK: - Preset

    private var presetRow: some View {
        let kind = PresetKind.gptImage
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
                let params = PresetParams.gptImage(GptImagePresetParams(
                    prompt: isBatchMode ? "" : prompt, channel: channel, aspectRatio: ratio,
                    resolution: resolution, quality: quality, photoReal: photoReal
                ))
                presetStore.save(name: name, params: params)
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text(isBatchMode ? "仅保存当前参数配置（不包括 Prompt 和参考图片）" : "保存当前的 Prompt 和参数（不包括参考图片）")
        }
    }

    private func applyPreset(_ preset: Preset) {
        guard case .gptImage(let p) = preset.params else { return }
        if !isBatchMode { prompt = p.prompt }
        channel = p.channel
        ratio = p.aspectRatio
        resolution = p.resolution
        quality = p.quality
        photoReal = p.photoReal
        errorMessage = nil; resultTaskId = nil; isGenerating = false
    }

    private func estimateBanner(channel: String, resolution: String, quality: String, photoReal: Bool, batchCount: Int?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            let channelName = channel == "official" ? "官方" : "低价"
            let qualityName: String = {
                switch quality { case "low": return "低"; case "high": return "高"; default: return "中" }
            }()
            let photoRealText = photoReal ? " · 真实感" : ""
            if let count = batchCount, count > 0 {
                Text("\(count) 条 · 渠道: \(channelName) · 分辨率: \(resolution) · 质量: \(qualityName)\(photoRealText)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("渠道: \(channelName) · 分辨率: \(resolution) · 质量: \(qualityName)\(photoRealText)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("费用以实际扣费为准")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    private func optionPicker(_ label: String, selection: Binding<String>, options: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Picker(label, selection: selection) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 100)
        }
    }
}

struct MultiImagePickerRow: View {
    let label: String
    @Binding var files: [FileRef]
    let maxCount: Int
    var maxFileSizeBytes: Int = 25 * 1024 * 1024
    var helperText: String?

    @State private var errorMessage: String?
    @State private var thumbnails: [NSImage?] = []
    @State private var imageDimensions: [(width: Int, height: Int)?] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary)
                Button("选择图片...") {
                    pickImages()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !files.isEmpty {
                    Button("清除") {
                        files = []
                        thumbnails = []
                        imageDimensions = []
                        errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                Text("\(files.count)/\(maxCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let helperText {
                Text(helperText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !files.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(files.indices, id: \.self) { i in
                            VStack(spacing: 2) {
                                if i < thumbnails.count, let image = thumbnails[i] {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 80, height: 80)
                                }
                                Text(files[i].name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 80)
                                imageMetadataLine(index: i)
                            }
                        }
                    }
                }
                .frame(minHeight: 100)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .onChange(of: fileSignature) { _, _ in
            syncThumbnailsWithFiles()
        }
    }

    @ViewBuilder
    private func imageMetadataLine(index: Int) -> some View {
        let parts: [String] = [
            index < imageDimensions.count ? imageDimensions[index].map { "\($0.width)×\($0.height)" } : nil,
            FileMetadataFormatter.formatFileSize(files[index].data.count)
        ].compactMap { $0 }
        Text(parts.joined(separator: " · "))
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(width: 80)
    }

    private var fileSignature: String {
        files.map { "\($0.name):\($0.data.count)" }.joined(separator: "|")
    }

    private func pickImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            do {
                guard !panel.urls.isEmpty else { return }
                let remainingCount = maxCount - files.count
                guard remainingCount > 0, panel.urls.count <= remainingCount else {
                    throw ImagePickerError.tooManyFiles(maxCount: maxCount)
                }

                var selected: [FileRef] = []
                var failedCount = 0
                var firstError: Error?

                for url in panel.urls {
                    do {
                        let data = try loadValidatedImage(at: url)
                        selected.append(FileRef(data: data, name: url.lastPathComponent, mime: url.mimeType()))
                    } catch {
                        failedCount += 1
                        if firstError == nil { firstError = error }
                    }
                }

                files.append(contentsOf: selected)
                generateThumbnails(for: files)
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

    private func loadValidatedImage(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        guard let contentType = values.contentType, contentType.conforms(to: .image) else {
            throw ImagePickerError.unsupportedType
        }

        let fileSize = values.fileSize ?? 0
        guard fileSize > 0 else { throw ImagePickerError.emptyFile }
        guard fileSize <= maxFileSizeBytes else { throw ImagePickerError.fileTooLarge(maxBytes: maxFileSizeBytes) }

        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private func generateThumbnails(for files: [FileRef]) {
        thumbnails = []
        imageDimensions = []
        for file in files {
            guard let source = CGImageSourceCreateWithData(file.data as CFData, nil) else {
                thumbnails.append(nil)
                imageDimensions.append(nil)
                continue
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 120,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            thumbnails.append(cgImage.map { NSImage(cgImage: $0, size: NSSize(width: 120, height: 120)) })

            if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let w = props[kCGImagePropertyPixelWidth] as? Int,
               let h = props[kCGImagePropertyPixelHeight] as? Int {
                imageDimensions.append((width: w, height: h))
            } else {
                imageDimensions.append(nil)
            }
        }
    }

    private func syncThumbnailsWithFiles() {
        if files.isEmpty {
            thumbnails = []
            imageDimensions = []
        } else if thumbnails.count != files.count {
            generateThumbnails(for: files)
        }
    }
}

enum ImagePickerError: LocalizedError {
    case unsupportedType
    case emptyFile
    case fileTooLarge(maxBytes: Int)
    case tooManyFiles(maxCount: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "文件类型不支持"
        case .emptyFile:
            return "文件为空"
        case .fileTooLarge(let maxBytes):
            return "文件过大，最大支持 \(maxBytes / 1024 / 1024) MB"
        case .tooManyFiles(let maxCount):
            return "最多选择 \(maxCount) 张参考图"
        }
    }
}

// MARK: - Task Polling View

enum PollType { case image, seedance, veo, grok, wan }

struct TaskPollingView: View {
    let taskId: String
    let pollType: PollType
    var priceUsd: String? = nil
    @ObservedObject var api: APIService

    @State private var status = "排队中..."
    @State private var resultUrls: [String] = []
    @State private var videoUrl: String?
    @State private var isPolling = true
    @State private var pollCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.vertical, 4)

            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("任务: \(String(taskId.prefix(12)))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let price = priceUsd, !price.isEmpty {
                    Text(price)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Text(status)
                    .font(.caption)
                    .foregroundColor(isPolling ? .orange : (resultUrls.isEmpty && videoUrl == nil ? .red : .green))
                Text("(\(pollCount)次)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Image results
            if !resultUrls.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(resultUrls, id: \.self) { url in
                            RemoteImageResultView(urlString: url, maxHeight: 300)
                        }
                    }
                }
            }

            // Video result
            if let url = videoUrl {
                RemoteVideoResultView(urlString: url)
            }
        }
        .onAppear { startPolling() }
        .onDisappear { isPolling = false }
    }

    private func startPolling() {
        Task {
            while isPolling {
                pollCount += 1
                do {
                    let result: TaskPollResponse
                    switch pollType {
                    case .image:
                        result = try await api.pollImageTask(taskId)
                        if result.isTerminalSuccess(for: .image) {
                            status = "完成"
                            resultUrls = result.imageResultUrls
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else if result.isTerminalFailure(for: .image) {
                            status = result.errorMessage ?? "失败"
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else {
                            status = result.dbStatus ?? "处理中"
                        }
                    case .seedance:
                        result = try await api.pollSeedanceTask(taskId)
                        handleVideoResult(result)
                    case .veo:
                        result = try await api.pollVeoTask(taskId)
                        handleVideoResult(result)
                    case .grok:
                        result = try await api.pollGrokTask(taskId)
                        if result.isTerminalSuccess(for: .grok) {
                            status = "完成"
                            videoUrl = result.videoResultUrl
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else if result.isTerminalFailure(for: .grok) {
                            status = result.errorMessage ?? "失败"
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else {
                            status = result.status ?? "处理中"
                        }
                    case .wan:
                        result = try await api.pollMediaTask(taskId)
                        if result.isTerminalSuccess(for: .wan) {
                            status = "完成"
                            videoUrl = result.videoResultUrl
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else if result.isTerminalFailure(for: .wan) {
                            status = result.errorMessage ?? result.detailMessage ?? result.message ?? "失败"
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else {
                            status = result.status ?? result.taskStatus ?? "处理中"
                        }
                    }
                } catch {
                    status = "轮询错误"
                }
                if isPolling {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }

    private func handleVideoResult(_ result: TaskPollResponse) {
        let pollKind: ActiveTaskPollKind = pollType == .seedance ? .seedance : .veo
        if result.isTerminalSuccess(for: pollKind) {
            status = "完成"
            videoUrl = result.videoResultUrl
            isPolling = false
            api.removeTask(id: taskId)
        } else if result.isTerminalFailure(for: pollKind) {
            status = result.errorMessage ?? "失败"
            isPolling = false
            api.removeTask(id: taskId)
        } else {
            status = result.dbStatus ?? "处理中"
        }
    }
}

struct RemoteImageResultView: View {
    let urlString: String
    var maxHeight: CGFloat = 220
    var onPreview: ((URL) -> Void)?

    @State private var previewItem: MediaPreviewItem?
    @State private var isDownloading = false
    @State private var downloadMessage: String?

    private var url: URL? {
        ExternalURL.sanitizedURL(urlString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .scaledToFit()
                            .frame(maxHeight: maxHeight)
                            .cornerRadius(8)
                            .onTapGesture { showPreview(url) }
                    case .failure:
                        unavailableView
                    default:
                        ProgressView()
                            .frame(width: 100, height: 100)
                    }
                }

                mediaActions(
                    preview: { showPreview(url) },
                    open: { ExternalURL.open(urlString) },
                    download: { downloadRemote(url: url) }
                )
            } else {
                unavailableView
            }

            if let downloadMessage {
                Text(downloadMessage)
                    .font(.caption2)
                    .foregroundColor(downloadMessage.contains("失败") ? .red : .secondary)
                    .lineLimit(2)
            }
        }
        .sheet(item: $previewItem) { item in
            RemoteImagePreviewSheet(url: item.url)
        }
    }

    private var unavailableView: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Image(systemName: "photo")
                .foregroundColor(.secondary)
        }
        .frame(width: 120, height: 100)
        .cornerRadius(8)
    }

    private func mediaActions(preview: @escaping () -> Void, open: @escaping () -> Void, download: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: preview) {
                Label("预览", systemImage: "eye")
            }
            Button(action: open) {
                Label("打开", systemImage: "safari")
            }
            Button(action: download) {
                if isDownloading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Label("下载", systemImage: "arrow.down.circle")
                }
            }
            .disabled(isDownloading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(.caption)
    }

    private func showPreview(_ url: URL) {
        if let onPreview {
            onPreview(url)
        } else {
            previewItem = MediaPreviewItem(url: url)
        }
    }

    private func downloadRemote(url: URL) {
        isDownloading = true
        downloadMessage = nil
        Task {
            do {
                if let savedURL = try await MediaDownloadService.download(
                    from: url,
                    suggestedFilename: MediaDownloadService.suggestedFilename(for: url, fallback: "image.png"),
                    kind: .image
                ) {
                    downloadMessage = "已保存到 \(savedURL.lastPathComponent)"
                }
            } catch {
                downloadMessage = "下载失败：\(error.localizedDescription)"
            }
            isDownloading = false
        }
    }
}

struct RemoteVideoResultView: View {
    let urlString: String
    var height: CGFloat = 260
    var inlinePreview = true
    var onPreview: ((URL) -> Void)?

    @State private var player: AVPlayer?
    @State private var previewItem: MediaPreviewItem?
    @State private var isDownloading = false
    @State private var downloadMessage: String?

    private var url: URL? {
        ExternalURL.sanitizedURL(urlString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url {
                if inlinePreview {
                    AppKitVideoPlayerView(player: player)
                        .frame(minHeight: height)
                        .cornerRadius(8)
                        .onAppear {
                            if player == nil {
                                player = AVPlayer(url: url)
                            }
                        }
                        .onDisappear {
                            player?.pause()
                        }
                } else {
                    Button {
                        showPreview(url)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.accentColor)
                        }
                        .frame(height: height)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Button {
                        if inlinePreview {
                            player?.seek(to: .zero)
                            player?.play()
                        } else {
                            showPreview(url)
                        }
                    } label: {
                        Label("预览", systemImage: "play.circle")
                    }
                    Button {
                        ExternalURL.open(urlString)
                    } label: {
                        Label("打开", systemImage: "safari")
                    }
                    Button {
                        downloadRemote(url: url)
                    } label: {
                        if isDownloading {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("下载", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isDownloading)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.caption)
            } else {
                Text("视频链接不可用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let downloadMessage {
                Text(downloadMessage)
                    .font(.caption2)
                    .foregroundColor(downloadMessage.contains("失败") ? .red : .secondary)
                    .lineLimit(2)
            }
        }
        .sheet(item: $previewItem) { item in
            RemoteVideoPreviewSheet(url: item.url)
        }
    }

    private func showPreview(_ url: URL) {
        if let onPreview {
            onPreview(url)
        } else {
            previewItem = MediaPreviewItem(url: url)
        }
    }

    private func downloadRemote(url: URL) {
        isDownloading = true
        downloadMessage = nil
        Task {
            do {
                if let savedURL = try await MediaDownloadService.download(
                    from: url,
                    suggestedFilename: MediaDownloadService.suggestedFilename(for: url, fallback: "video.mp4"),
                    kind: .video
                ) {
                    downloadMessage = "已保存到 \(savedURL.lastPathComponent)"
                }
            } catch {
                downloadMessage = "下载失败：\(error.localizedDescription)"
            }
            isDownloading = false
        }
    }
}

struct LocalImageResultView: View {
    let image: NSImage
    let data: Data?
    var suggestedFilename = "image.png"
    var maxHeight: CGFloat = 300

    @State private var isDownloading = false
    @State private var downloadMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .cornerRadius(8)

            if let data {
                HStack(spacing: 8) {
                    Button {
                        saveData(data)
                    } label: {
                        if isDownloading {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("下载", systemImage: "arrow.down.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption)
                    .disabled(isDownloading)
                }
            }

            if let downloadMessage {
                Text(downloadMessage)
                    .font(.caption2)
                    .foregroundColor(downloadMessage.contains("失败") ? .red : .secondary)
                    .lineLimit(2)
            }
        }
    }

    private func saveData(_ data: Data) {
        isDownloading = true
        downloadMessage = nil
        Task {
            do {
                if let savedURL = try await MediaDownloadService.save(data: data, suggestedFilename: suggestedFilename) {
                    downloadMessage = "已保存到 \(savedURL.lastPathComponent)"
                }
            } catch {
                downloadMessage = "保存失败：\(error.localizedDescription)"
            }
            isDownloading = false
        }
    }
}

private struct MediaPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct RemoteImagePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let url: URL

    var body: some View {
        VStack(spacing: 0) {
            PreviewSheetHeader(close: { dismiss() })

            Divider()

            ScrollView([.horizontal, .vertical]) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(minWidth: 520, minHeight: 360)
                            .padding()
                    case .failure:
                        Text("图片加载失败")
                            .foregroundColor(.secondary)
                            .frame(width: 520, height: 360)
                    default:
                        ProgressView()
                            .frame(width: 520, height: 360)
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

struct RemoteVideoPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(url: URL) {
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VStack(spacing: 0) {
            PreviewSheetHeader(close: { dismiss() })

            Divider()

            AppKitVideoPlayerView(player: player)
                .frame(minWidth: 640, minHeight: 420)
        }
        .onAppear {
            player.play()
        }
        .onDisappear {
            player.pause()
        }
    }
}

private struct PreviewSheetHeader: View {
    let close: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button {
                close()
            } label: {
                Label("关闭", systemImage: "xmark.circle.fill")
            }
            .keyboardShortcut(.cancelAction)
            .keyboardShortcut("w", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct AppKitVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.videoGravity = .resizeAspect
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}

enum MediaDownloadService {
    enum MediaKind {
        case image
        case video
    }

    enum DownloadError: LocalizedError {
        case invalidResponse
        case httpStatus(Int)
        case unexpectedContentType(String?)
        case fileTooLarge(Int64)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "下载响应无效"
            case .httpStatus(let status):
                return "下载请求失败 (\(status))"
            case .unexpectedContentType(let contentType):
                return "返回内容不是支持的媒体类型\(contentType.map { "：\($0)" } ?? "")"
            case .fileTooLarge(let maxBytes):
                return "文件过大，最大支持 \(maxBytes / 1024 / 1024) MB"
            }
        }
    }

    private static let maximumDownloadBytes: Int64 = 2 * 1024 * 1024 * 1024

    static func suggestedFilename(for url: URL, fallback: String) -> String {
        let name = url.lastPathComponent
        guard !name.isEmpty, name.contains(".") else { return fallback }
        return sanitizedFilename(name)
    }

    static func download(from url: URL, suggestedFilename: String, kind: MediaKind) async throws -> URL? {
        guard let destination = await chooseDestination(suggestedFilename: suggestedFilename) else {
            return nil
        }
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        try validateDownload(response: response, temporaryURL: temporaryURL, sourceURL: url, kind: kind)
        try replaceItem(at: destination, with: temporaryURL)
        return destination
    }

    static func save(data: Data, suggestedFilename: String) async throws -> URL? {
        guard let destination = await chooseDestination(suggestedFilename: suggestedFilename) else {
            return nil
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try data.write(to: destination, options: .atomic)
        return destination
    }

    @MainActor
    private static func chooseDestination(suggestedFilename: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sanitizedFilename(suggestedFilename)
        panel.title = "保存到本地"
        panel.prompt = "保存"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func replaceItem(at destination: URL, with temporaryURL: URL) throws {
        let fileManager = FileManager.default
        let destinationDirectory = destination.deletingLastPathComponent()
        let stagedURL = destinationDirectory
            .appendingPathComponent(".\(UUID().uuidString)-\(destination.lastPathComponent)")

        try fileManager.copyItem(at: temporaryURL, to: stagedURL)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: stagedURL)
            } else {
                try fileManager.moveItem(at: stagedURL, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: stagedURL)
            throw error
        }
    }

    private static func validateDownload(response: URLResponse, temporaryURL: URL, sourceURL: URL, kind: MediaKind) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.httpStatus(httpResponse.statusCode)
        }

        let expectedLength = httpResponse.expectedContentLength
        if expectedLength > maximumDownloadBytes {
            throw DownloadError.fileTooLarge(maximumDownloadBytes)
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: temporaryURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        if fileSize > maximumDownloadBytes {
            throw DownloadError.fileTooLarge(maximumDownloadBytes)
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased()
        if !isSupported(contentType: contentType, sourceURL: sourceURL, temporaryURL: temporaryURL, kind: kind) {
            throw DownloadError.unexpectedContentType(contentType)
        }
    }

    private static func isSupported(contentType: String?, sourceURL: URL, temporaryURL: URL, kind: MediaKind) -> Bool {
        if contentType == nil || contentType == "application/octet-stream" {
            return hasSupportedExtension(sourceURL.pathExtension, kind: kind) || hasSupportedSignature(at: temporaryURL, kind: kind)
        }

        switch kind {
        case .image:
            return contentType?.hasPrefix("image/") == true
        case .video:
            return contentType?.hasPrefix("video/") == true
        }
    }

    private static func hasSupportedSignature(at url: URL, kind: MediaKind) -> Bool {
        guard let header = try? readHeader(from: url, byteCount: 32), !header.isEmpty else {
            return false
        }

        switch kind {
        case .image:
            return hasPrefix(header, [0xFF, 0xD8, 0xFF]) ||
                hasPrefix(header, [0x89, 0x50, 0x4E, 0x47]) ||
                hasPrefix(header, [0x47, 0x49, 0x46, 0x38]) ||
                hasRIFFBrand(header, brand: "WEBP") ||
                hasISOBaseMediaBrand(header, allowedBrands: ["heic", "heix", "hevc", "hevx", "mif1", "msf1"])
        case .video:
            return hasPrefix(header, [0x1A, 0x45, 0xDF, 0xA3]) ||
                hasISOBaseMediaBrand(header, allowedBrands: ["isom", "iso2", "mp41", "mp42", "avc1", "qt  ", "M4V "])
        }
    }

    private static func readHeader(from url: URL, byteCount: Int) throws -> [UInt8] {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return Array(try handle.read(upToCount: byteCount) ?? Data())
    }

    private static func hasPrefix(_ bytes: [UInt8], _ prefix: [UInt8]) -> Bool {
        bytes.count >= prefix.count && Array(bytes.prefix(prefix.count)) == prefix
    }

    private static func hasRIFFBrand(_ bytes: [UInt8], brand: String) -> Bool {
        guard bytes.count >= 12,
              hasPrefix(bytes, [0x52, 0x49, 0x46, 0x46]),
              let found = String(bytes: bytes[8..<12], encoding: .ascii) else {
            return false
        }
        return found == brand
    }

    private static func hasISOBaseMediaBrand(_ bytes: [UInt8], allowedBrands: Set<String>) -> Bool {
        guard bytes.count >= 12,
              let box = String(bytes: bytes[4..<8], encoding: .ascii),
              box == "ftyp",
              let majorBrand = String(bytes: bytes[8..<12], encoding: .ascii) else {
            return false
        }
        return allowedBrands.contains(majorBrand)
    }

    private static func hasSupportedExtension(_ pathExtension: String, kind: MediaKind) -> Bool {
        let ext = pathExtension.lowercased()
        switch kind {
        case .image:
            return ["jpg", "jpeg", "png", "webp", "gif", "heic", "heif", "tiff"].contains(ext)
        case .video:
            return ["mp4", "mov", "m4v", "webm"].contains(ext)
        }
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = filename
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "download" : cleaned
    }

    // MARK: - Batch Download

    struct BatchDownloadItem {
        let url: URL
        let filename: String
        let kind: MediaKind
        let recordKind: String
        let date: Date
    }

    struct BatchDownloadProgress {
        var completed: Int = 0
        var total: Int
        var currentFile: String = ""
        var errors: [String] = []
    }

    @MainActor
    static func chooseDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.title = "选择下载目录"
        panel.prompt = "选择"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func batchDownload(
        items: [BatchDownloadItem],
        toDirectory baseDirectory: URL,
        maxConcurrency: Int = 3,
        progressHandler: @Sendable @escaping (BatchDownloadProgress) -> Void
    ) async -> BatchDownloadProgress {
        var progress = BatchDownloadProgress(total: items.count)

        await withTaskGroup(of: (String?, String?).self) { group in
            var activeCount = 0
            var itemIterator = items.makeIterator()

            while activeCount < maxConcurrency, let item = itemIterator.next() {
                group.addTask {
                    let result = await downloadSingleItem(item: item, baseDirectory: baseDirectory)
                    return (item.filename, result)
                }
                activeCount += 1
            }

            for await (filename, error) in group {
                if let error {
                    progress.errors.append("\(filename ?? "unknown"): \(error)")
                }
                progress.completed += 1
                progress.currentFile = filename ?? ""
                progressHandler(progress)

                if let nextItem = itemIterator.next() {
                    group.addTask {
                        let result = await downloadSingleItem(item: nextItem, baseDirectory: baseDirectory)
                        return (nextItem.filename, result)
                    }
                }
            }
        }

        return progress
    }

    private static func downloadSingleItem(item: BatchDownloadItem, baseDirectory: URL) async -> String? {
        let subdirectory = buildSubdirectory(recordKind: item.recordKind, date: item.date)
        let targetDir = baseDirectory.appendingPathComponent(subdirectory)

        do {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } catch {
            return "创建目录失败: \(error.localizedDescription)"
        }

        let destination = targetDir.appendingPathComponent(sanitizedFilename(item.filename))

        if item.url.isFileURL {
            return copyLocalFile(from: item.url, to: destination)
        }

        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: item.url)
            try validateDownload(response: response, temporaryURL: temporaryURL, sourceURL: item.url, kind: item.kind)
            try replaceItem(at: destination, with: temporaryURL)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private static func copyLocalFile(from source: URL, to destination: URL) -> String? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else {
            return "本地文件不存在: \(source.lastPathComponent)"
        }
        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
            return nil
        } catch {
            return "复制失败: \(error.localizedDescription)"
        }
    }

    private static func buildSubdirectory(recordKind: String, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)
        let safeKind = sanitizedFilename(recordKind)
        return "\(safeKind)/\(dateStr)"
    }

    static func batchDownloadRecords(
        records: [WorkRecord],
        toDirectory baseDirectory: URL,
        progressHandler: @Sendable @escaping (BatchDownloadProgress) -> Void
    ) async -> BatchDownloadProgress {
        var items: [BatchDownloadItem] = []

        for record in records {
            if let path = record.localImagePath, FileManager.default.fileExists(atPath: path) {
                items.append(BatchDownloadItem(
                    url: URL(fileURLWithPath: path),
                    filename: "banana-\(record.id).png",
                    kind: .image,
                    recordKind: record.displayType,
                    date: record.createdAt
                ))
            } else if let videoUrl = record.videoUrl, let url = ExternalURL.sanitizedURL(videoUrl) {
                let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
                items.append(BatchDownloadItem(
                    url: url,
                    filename: "video-\(record.id).\(ext)",
                    kind: .video,
                    recordKind: record.displayType,
                    date: record.createdAt
                ))
            } else {
                for (index, urlString) in record.resultUrls.enumerated() {
                    if let url = ExternalURL.sanitizedURL(urlString) {
                        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
                        items.append(BatchDownloadItem(
                            url: url,
                            filename: "\(record.id)-\(index).\(ext)",
                            kind: record.isVideo ? .video : .image,
                            recordKind: record.displayType,
                            date: record.createdAt
                        ))
                    }
                }
            }
        }

        return await batchDownload(items: items, toDirectory: baseDirectory, progressHandler: progressHandler)
    }
}
