import SwiftUI

struct BananaView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore

    @State private var prompt = ""
    @State private var provider = "third_party"
    @State private var referenceImages: [FileRef] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultImage: NSImage?
    @State private var resultImageData: Data?
    @State private var submittedPriceUsd: String?
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
        }
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

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("提供商").font(.caption2).foregroundColor(.secondary)
                    Picker("", selection: $provider) {
                        Text("官方 Gemini").tag("official")
                        Text("第三方 RunningHub").tag("third_party")
                    }.pickerStyle(.segmented)
                }
            }

            MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 3)

            bananaEstimateBanner

            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8); Text("生成中...")
                    } else {
                        Label("生成", systemImage: "paintbrush")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }

            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }

            if let img = resultImage {
                Divider().padding(.vertical, 4)
                LocalImageResultView(
                    image: img,
                    data: resultImageData,
                    suggestedFilename: "banana-result.png",
                    maxHeight: 400
                )
            }
        }
    }

    private var batchModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("批量提示词").font(.headline)
                    Spacer()
                    Text("\(validBananaBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(validBananaBatchPrompts.isEmpty ? .secondary : .accentColor)
                }
                TextEditor(text: $batchPrompts)
                    .font(.body).frame(height: 160)
                    .scrollContentBackground(.hidden).padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Text("每行一条提示词，共享当前提供商配置")
                    .font(.caption2).foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("提供商").font(.caption2).foregroundColor(.secondary)
                    Picker("", selection: $provider) {
                        Text("官方 Gemini").tag("official")
                        Text("第三方 RunningHub").tag("third_party")
                    }.pickerStyle(.segmented)
                }
            }

            bananaEstimateBanner

            HStack {
                Button(action: enqueueBananaBatch) {
                    Label("加入批量队列 (\(validBananaBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validBananaBatchPrompts.isEmpty)

                if !queueStore.items.isEmpty {
                    Text("队列: \(queueStore.pendingCount) 待提交")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let msg = batchMessage { Text(msg).font(.caption).foregroundColor(msg.contains("失败") ? .red : .green) }
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
        }
    }

    private var validBananaBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private var invalidBananaBatchLines: [Int] {
        let lines = batchPrompts.components(separatedBy: "\n")
        return lines.indices.compactMap { i in
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count > 8000 { return i + 1 }
            return nil
        }
    }

    private var bananaEstimateBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            let providerName = provider == "official" ? "官方 Gemini" : "第三方 RunningHub"
            let batchPrefix: String = {
                guard isBatchMode else { return "" }
                let count = validBananaBatchPrompts.count
                return count > 0 ? "\(count) 条 · " : ""
            }()
            Text("\(batchPrefix)提供商: \(providerName)")
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

    private func enqueueBananaBatch() {
        let invalidLines = invalidBananaBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validBananaBatchPrompts
        guard !prompts.isEmpty else { return }
        errorMessage = nil; batchMessage = nil

        let items = prompts.map { prompt in
            GenerationQueueItem(
                kind: .banana,
                createdAt: Date(),
                params: .banana(BananaJobParams(
                    prompt: prompt, provider: provider,
                    referenceImages: referenceImages
                ))
            )
        }
        queueStore.enqueueBatch(items)
        batchMessage = "已加入 \(items.count) 条 Banana 任务到队列"
    }

    private func startGeneration() {
        isGenerating = true; errorMessage = nil; resultImage = nil; resultImageData = nil
        Task {
            do {
                if let data = try await api.generateBanana(
                    prompt: prompt, provider: provider,
                    referenceImages: referenceImages
                ) {
                    resultImageData = data
                    resultImage = NSImage(data: data)
                } else {
                    errorMessage = "未返回图片数据"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

// MARK: - Wan Video View

struct WanVideoView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore

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
                Text("提示词").font(.headline)
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

            wanEstimateBanner

            HStack {
                Button(action: enqueueWanBatch) {
                    Label("加入批量队列 (\(validWanBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validWanBatchPrompts.isEmpty)

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
                    api.addTask(id: tid, type: mode == "image" ? "Wan 视频" : "Wan 首尾帧", desc: String(prompt.prefix(30)))
                } else {
                    errorMessage = result.message ?? "提交失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
