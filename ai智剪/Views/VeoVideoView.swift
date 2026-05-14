import SwiftUI
import UniformTypeIdentifiers

struct VeoVideoView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore

    @State private var prompt = ""
    @State private var channel = "budget"
    @State private var model = "fast"
    @State private var mode = "text"
    @State private var ratio = "9:16"
    @State private var resolution = "720p"
    @State private var duration = "8"
    @State private var generateAudio = false
    @State private var negativePrompt = ""
    @State private var isSyncingOptions = false

    // File refs
    @State private var imageFiles: [FileRef] = []
    @State private var firstImageFile: FileRef?
    @State private var lastImageFile: FileRef?
    @State private var ref1: FileRef?
    @State private var ref2: FileRef?
    @State private var ref3: FileRef?
    @State private var videoFile: FileRef?

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskId: String?
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?

    var modelOptions: [(String, String)] {
        channel == "budget"
            ? [("fast","Fast"),("pro","Pro")]
            : [("lite","Lite"),("fast","Fast"),("pro","Pro")]
    }

    var modeOptions: [(String, String)] {
        if channel == "budget" && model == "fast" {
            return [("text","文生视频"),("image","图生视频"),("start_end","首尾帧")]
        }
        if channel == "budget" && model == "pro" {
            return [("text","文生视频"),("start_end","首尾帧")]
        }
        if channel == "official" && model == "lite" {
            return [("text","文生视频"),("image","图生视频"),("start_end","首尾帧")]
        }
        if channel == "official" && model == "fast" {
            return [("text","文生视频"),("image","图生视频"),("start_end","首尾帧"),("extend","视频扩展")]
        }
        return [("text","文生视频"),("image","图生视频"),("start_end","首尾帧"),("reference","参考生视频"),("extend","视频扩展")]
    }

    var supportsDuration: Bool {
        if channel == "budget" { return false }
        if model == "lite" && mode == "start_end" { return false }
        return mode != "reference" && mode != "extend"
    }

    var supportsAudio: Bool {
        channel == "official" && model != "lite" && mode != "extend"
    }

    var supportsAspectRatio: Bool {
        mode != "reference" && mode != "extend"
    }

    var lastFrameRequired: Bool {
        mode == "start_end" && channel == "official" && model == "lite"
    }

    var supportsMultiImageReferences: Bool {
        channel == "budget" && model == "fast" && mode == "image"
    }

    var imageReferenceLimit: Int {
        supportsMultiImageReferences ? 3 : 1
    }

    var imageReferenceMaxBytes: Int {
        if channel == "budget" { return 30 * 1024 * 1024 }
        if model == "lite" && mode == "image" { return 20 * 1024 * 1024 }
        return 10 * 1024 * 1024
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
            if newMode != "image" { imageFiles = [] }
            if newMode != "start_end" { firstImageFile = nil; lastImageFile = nil }
            if newMode != "reference" { ref1 = nil; ref2 = nil; ref3 = nil }
            if newMode != "extend" { videoFile = nil }
        }
        .onChange(of: channel) { _, _ in syncOptions() }
        .onChange(of: model) { _, _ in syncOptions() }
        .onChange(of: imageReferenceLimit) { _, limit in
            if imageFiles.count > limit {
                imageFiles = Array(imageFiles.prefix(limit))
            }
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
                opt("渠道", $channel, [("budget","低价"),("official","官方")])
                opt("模型", $model, modelOptions)
                opt("模式", $mode, modeOptions)
                if supportsAspectRatio {
                    opt("画幅", $ratio, [("9:16","9:16"),("16:9","16:9"),("1:1","1:1")])
                }
                opt("分辨率", $resolution, [("720p","720p"),("1080p","1080p"),("4k","4K")])
                if supportsDuration {
                    opt("时长", $duration, [("4","4s"),("6","6s"),("8","8s")])
                } else if channel == "budget" && mode != "reference" && mode != "extend" {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("时长").font(.caption2).foregroundColor(.secondary)
                        Text("固定 8s").font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            if supportsAudio {
                Toggle("生成音频", isOn: $generateAudio)
            }

            if channel == "official" {
                VStack(alignment: .leading, spacing: 2) {
                    Text("反向提示词").font(.caption).foregroundColor(.secondary)
                    TextField("不希望出现的内容...", text: $negativePrompt).textFieldStyle(.roundedBorder)
                }
            }

            if mode == "image" {
                MultiImagePickerRow(
                    label: "参考图片",
                    files: $imageFiles,
                    maxCount: imageReferenceLimit,
                    maxFileSizeBytes: imageReferenceMaxBytes,
                    helperText: supportsMultiImageReferences ? "低价 Fast 图生视频最多 3 张参考图" : nil
                )
            }
            if mode == "start_end" {
                FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstImageFile = nil }) { d, n, m in firstImageFile = FileRef(data: d, name: n, mime: m) }
                FilePickerRow(label: lastFrameRequired ? "尾帧图片（必填）" : "尾帧图片（可选）", types: [.image], onClear: { lastImageFile = nil }) { d, n, m in lastImageFile = FileRef(data: d, name: n, mime: m) }
            }
            if mode == "reference" {
                FilePickerRow(label: "参考图1", types: [.image], onClear: { ref1 = nil }) { d, n, m in ref1 = FileRef(data: d, name: n, mime: m) }
                FilePickerRow(label: "参考图2", types: [.image], onClear: { ref2 = nil }) { d, n, m in ref2 = FileRef(data: d, name: n, mime: m) }
                FilePickerRow(label: "参考图3", types: [.image], onClear: { ref3 = nil }) { d, n, m in ref3 = FileRef(data: d, name: n, mime: m) }
            }
            if mode == "extend" {
                FilePickerRow(label: "视频素材", types: [.movie, .video], onClear: { videoFile = nil }) { d, n, m in videoFile = FileRef(data: d, name: n, mime: m) }
            }

            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8); Text("提交中...")
                    } else {
                        Label("生成 Veo 视频", systemImage: "globe")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }

            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
            if let tid = resultTaskId {
                TaskPollingView(taskId: tid, pollType: .veo, api: api)
            }
        }
    }

    private var batchModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("批量提示词").font(.headline)
                    Spacer()
                    Text("\(validVeoBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(validVeoBatchPrompts.isEmpty ? .secondary : .accentColor)
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
                opt("渠道", $channel, [("budget","低价"),("official","官方")])
                opt("模型", $model, modelOptions)
                opt("模式", $mode, modeOptions)
                if supportsAspectRatio {
                    opt("画幅", $ratio, [("9:16","9:16"),("16:9","16:9"),("1:1","1:1")])
                }
                opt("分辨率", $resolution, [("720p","720p"),("1080p","1080p"),("4k","4K")])
                if supportsDuration {
                    opt("时长", $duration, [("4","4s"),("6","6s"),("8","8s")])
                } else if channel == "budget" && mode != "reference" && mode != "extend" {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("时长").font(.caption2).foregroundColor(.secondary)
                        Text("固定 8s").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            if supportsAudio {
                Toggle("生成音频", isOn: $generateAudio)
            }
            if channel == "official" {
                VStack(alignment: .leading, spacing: 2) {
                    Text("反向提示词（所有提示词共享）").font(.caption).foregroundColor(.secondary)
                    TextField("不希望出现的内容...", text: $negativePrompt).textFieldStyle(.roundedBorder)
                }
            }

            if mode == "image" {
                MultiImagePickerRow(
                    label: "参考图片",
                    files: $imageFiles,
                    maxCount: imageReferenceLimit,
                    maxFileSizeBytes: imageReferenceMaxBytes,
                    helperText: supportsMultiImageReferences ? "低价 Fast 图生视频最多 3 张参考图" : nil
                )
            }
            if mode == "start_end" {
                FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstImageFile = nil }) { d, n, m in firstImageFile = FileRef(data: d, name: n, mime: m) }
                FilePickerRow(label: lastFrameRequired ? "尾帧图片（必填）" : "尾帧图片（可选）", types: [.image], onClear: { lastImageFile = nil }) { d, n, m in lastImageFile = FileRef(data: d, name: n, mime: m) }
            }
            if mode == "reference" {
                FilePickerRow(label: "参考图1", types: [.image], onClear: { ref1 = nil }) { d, n, m in ref1 = FileRef(data: d, name: n, mime: m) }
                FilePickerRow(label: "参考图2", types: [.image], onClear: { ref2 = nil }) { d, n, m in ref2 = FileRef(data: d, name: n, mime: m) }
                FilePickerRow(label: "参考图3", types: [.image], onClear: { ref3 = nil }) { d, n, m in ref3 = FileRef(data: d, name: n, mime: m) }
            }
            if mode == "extend" {
                FilePickerRow(label: "视频素材", types: [.movie, .video], onClear: { videoFile = nil }) { d, n, m in videoFile = FileRef(data: d, name: n, mime: m) }
            }

            HStack {
                Button(action: enqueueVeoBatch) {
                    Label("加入批量队列 (\(validVeoBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validVeoBatchPrompts.isEmpty)

                if !queueStore.items.isEmpty {
                    Text("队列: \(queueStore.pendingCount) 待提交")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let msg = batchMessage { Text(msg).font(.caption).foregroundColor(msg.contains("失败") ? .red : .green) }
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
        }
    }

    private var validVeoBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private var invalidVeoBatchLines: [Int] {
        let lines = batchPrompts.components(separatedBy: "\n")
        return lines.indices.compactMap { i in
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count > 8000 { return i + 1 }
            return nil
        }
    }

    private func enqueueVeoBatch() {
        let invalidLines = invalidVeoBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validVeoBatchPrompts
        guard !prompts.isEmpty else { return }
        for p in prompts {
            if let err = validatePromptLine(p) { batchMessage = err; return }
        }
        if let err = validateSharedInputs() { batchMessage = err; return }
        errorMessage = nil; batchMessage = nil

        let negPrompt = channel == "official" && !negativePrompt.isEmpty ? negativePrompt : nil
        let items = prompts.map { prompt in
            var p = VeoJobParams(
                channel: channel, model: model, mode: mode,
                prompt: prompt, aspectRatio: ratio,
                resolution: resolution, duration: duration,
                generateAudio: supportsAudio && generateAudio,
                negativePrompt: negPrompt
            )
            p.imageFiles = imageFiles
            if let f = firstImageFile { p.firstImageData = f.data; p.firstImageName = f.name; p.firstImageMime = f.mime }
            if let f = lastImageFile { p.lastImageData = f.data; p.lastImageName = f.name; p.lastImageMime = f.mime }
            if let f = ref1 { p.ref1Data = (f.data, f.name, f.mime) }
            if let f = ref2 { p.ref2Data = (f.data, f.name, f.mime) }
            if let f = ref3 { p.ref3Data = (f.data, f.name, f.mime) }
            if let f = videoFile { p.videoData = f.data; p.videoName = f.name; p.videoMime = f.mime }
            return GenerationQueueItem(kind: .veo, createdAt: Date(), params: .veo(p))
        }
        queueStore.enqueueBatch(items)
        batchMessage = "已加入 \(items.count) 条 Veo 任务到队列"
    }

    private func opt(_ label: String, _ sel: Binding<String>, _ opts: [(String,String)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Picker("", selection: sel) {
                ForEach(opts, id: \.0) { Text($0.1).tag($0.0) }
            }.pickerStyle(.menu).labelsHidden()
        }
    }

    private func startGeneration() {
        if let validationError = validate() {
            errorMessage = validationError
            return
        }
        isGenerating = true; errorMessage = nil; resultTaskId = nil
        Task {
            do {
                var params = VeoParams()
                params.channel = channel; params.model = model; params.mode = mode
                params.prompt = prompt; params.aspectRatio = ratio
                params.resolution = resolution
                params.duration = channel == "budget" && mode != "reference" && mode != "extend" ? "8" : duration
                params.generateAudio = supportsAudio && generateAudio
                params.negativePrompt = channel == "official" && !negativePrompt.isEmpty ? negativePrompt : nil
                params.imageFiles = imageFiles
                if let f = firstImageFile { params.firstImageData = f.data; params.firstImageName = f.name; params.firstImageMime = f.mime }
                if let f = lastImageFile { params.lastImageData = f.data; params.lastImageName = f.name; params.lastImageMime = f.mime }
                if let f = ref1 { params.ref1Data = (f.data, f.name, f.mime) }
                if let f = ref2 { params.ref2Data = (f.data, f.name, f.mime) }
                if let f = ref3 { params.ref3Data = (f.data, f.name, f.mime) }
                if let f = videoFile { params.videoData = f.data; params.videoName = f.name; params.videoMime = f.mime }

                let result = try await api.generateVeoVideo(params: params)
                if let tid = result.ourTaskId {
                    resultTaskId = tid
                    api.addTask(id: tid, type: "Veo 视频", desc: String(prompt.prefix(30)))
                } else {
                    errorMessage = result.message ?? "提交失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func syncOptions() {
        if isSyncingOptions { return }
        isSyncingOptions = true
        defer { isSyncingOptions = false }
        if !modelOptions.contains(where: { $0.0 == model }) {
            model = modelOptions.first?.0 ?? "fast"
        }
        if !modeOptions.contains(where: { $0.0 == mode }) {
            mode = modeOptions.first?.0 ?? "text"
        }
        if !supportsAudio {
            generateAudio = false
        }
        if channel == "budget" && mode != "reference" && mode != "extend" {
            duration = "8"
        } else if supportsDuration && !["4", "6", "8"].contains(duration) {
            duration = "8"
        }
        if imageFiles.count > imageReferenceLimit {
            imageFiles = Array(imageFiles.prefix(imageReferenceLimit))
        }
    }

    private func validate() -> String? {
        if let err = validatePromptLine(prompt) { return err }
        return validateSharedInputs()
    }

    private func validatePromptLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode != "extend" && trimmed.isEmpty { return "请输入提示词" }
        if mode != "extend" && channel == "budget" && trimmed.count < 5 {
            return "低价渠道提示词至少 5 个字符"
        }
        return nil
    }

    private func validateSharedInputs() -> String? {
        if mode == "image" {
            if imageFiles.isEmpty { return "请上传参考图" }
            if imageFiles.count > imageReferenceLimit { return "参考图最多 \(imageReferenceLimit) 张" }
            if imageFiles.contains(where: { $0.data.count > imageReferenceMaxBytes }) {
                return "参考图不能超过 \(imageReferenceMaxBytes / 1024 / 1024)MB"
            }
        }
        if mode == "start_end" {
            if firstImageFile == nil { return "请上传首帧图片" }
            if lastFrameRequired && lastImageFile == nil { return "官方 Lite 首尾帧须上传尾帧" }
        }
        if mode == "reference" && ref1 == nil && ref2 == nil && ref3 == nil {
            return "请至少上传 1 张参考图"
        }
        if mode == "extend" && videoFile == nil { return "请上传需要扩展的视频" }
        return nil
    }
}

struct FileRef {
    let data: Data
    let name: String
    let mime: String
}
