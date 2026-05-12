import SwiftUI
import UniformTypeIdentifiers

struct ImageGenView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    
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
    @State private var pollTask: Task<Void, Never>?
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?
    
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
    }

    private var singleModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("提示词").font(.headline)
                TextEditor(text: $prompt)
                    .font(.body)
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

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
            Toggle("真实感增强", isOn: $photoReal)
                .disabled(!referenceImages.isEmpty)

            MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 10)

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
                TaskPollingView(taskId: taskId, pollType: .image, api: api)
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
            Toggle("真实感增强", isOn: $photoReal)
                .disabled(!referenceImages.isEmpty)

            MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 10)

            HStack {
                Button(action: enqueueBatch) {
                    Label("加入批量队列 (\(parsedBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedBatchPrompts.isEmpty)

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
                if let taskId = result.ourTaskId {
                    resultTaskId = taskId
                    api.addTask(id: taskId, type: "GPT-Image-2", desc: String(prompt.prefix(30)))
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

    @State private var errorMessage: String?
    @State private var thumbnails: [NSImage?] = []

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
                        errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                Text("\(files.count)/\(maxCount)")
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
        guard fileSize <= 25 * 1024 * 1024 else { throw ImagePickerError.fileTooLarge(maxBytes: 25 * 1024 * 1024) }

        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private func generateThumbnails(for files: [FileRef]) {
        thumbnails = files.map { file in
            guard let source = CGImageSourceCreateWithData(file.data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 120,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return NSImage(cgImage: cgImage, size: NSSize(width: 120, height: 120))
        }
    }

    private func syncThumbnailsWithFiles() {
        if files.isEmpty {
            thumbnails = []
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
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFit()
                                        .frame(maxHeight: 300)
                                        .cornerRadius(8)
                                        .onTapGesture { ExternalURL.open(url) }
                                case .failure:
                                    Color.red.frame(width: 100, height: 100)
                                default:
                                    ProgressView().frame(width: 100, height: 100)
                                }
                            }
                        }
                    }
                }
            }
            
            // Video result
            if let url = videoUrl {
                Button("在浏览器中打开视频") {
                    ExternalURL.open(url)
                }
                .buttonStyle(.borderedProminent)
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
                        let imageStatus = (result.dbStatus ?? "").uppercased()
                        if imageStatus == "SUCCESS" {
                            status = "完成"
                            resultUrls = result.resultUrls ?? []
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else if imageStatus == "FAILED" || imageStatus == "CANCELLED" {
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
                        let grokStatus = (result.status ?? "").uppercased()
                        if grokStatus == "SUCCESS" {
                            status = "完成"
                            videoUrl = result.outputUrl
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else if grokStatus == "FAILED" || grokStatus == "CANCELLED" || grokStatus == "ERROR" {
                            status = result.errorMessage ?? "失败"
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else {
                            status = result.status ?? "处理中"
                        }
                    case .wan:
                        result = try await api.pollMediaTask(taskId)
                        let mediaStatus = (result.status ?? result.taskStatus ?? "").uppercased()
                        if mediaStatus == "SUCCESS" || mediaStatus == "COMPLETED" {
                            status = "完成"
                            videoUrl = [result.videoUrl, result.outputUrl]
                                .compactMap { $0 }
                                .first { ExternalURL.sanitizedURL($0) != nil }
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else if mediaStatus == "FAILED" || mediaStatus == "CANCELLED" || mediaStatus == "ERROR" {
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
        let dbStatus = (result.dbStatus ?? "").uppercased()
        if dbStatus == "SUCCESS" {
            status = "完成"
            videoUrl = result.videoUrl
            isPolling = false
            api.removeTask(id: taskId)
        } else if dbStatus == "FAILED" || dbStatus == "CANCELLED" || dbStatus == "ERROR" {
            status = result.errorMessage ?? "失败"
            isPolling = false
            api.removeTask(id: taskId)
        } else {
            status = result.dbStatus ?? "处理中"
        }
    }
}
