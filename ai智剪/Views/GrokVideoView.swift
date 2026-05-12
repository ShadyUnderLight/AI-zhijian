import SwiftUI
import UniformTypeIdentifiers

struct GrokVideoView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    
    @State private var prompt = ""
    @State private var channel = "budget"
    @State private var mode = "text"
    @State private var ratio = "9:16"
    @State private var resolution = "720p"
    @State private var duration = "6"
    @State private var imageFiles: [FileRef] = []
    @State private var videoFile: FileRef?

    var imageMaxCount: Int {
        if mode == "image" && channel == "official" { return 1 }
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
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?
    
    var durationOptions: [(String, String)] {
        if channel == "official" {
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
            
            if showImagePicker {
                MultiImagePickerRow(label: "参考图片", files: $imageFiles, maxCount: imageMaxCount)
            }
            
            if showVideoPicker {
                FilePickerRow(label: "视频素材", types: [.movie, .video], onClear: { videoFile = nil }) { data, name, mime in
                    videoFile = FileRef(data: data, name: name, mime: mime)
                }
            }
            
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
                TaskPollingView(taskId: tid, pollType: .grok, api: api)
            }
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
    }

    private var batchModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("批量提示词").font(.headline)
                    Spacer()
                    Text("\(parsedGrokBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(parsedGrokBatchPrompts.isEmpty ? .secondary : .accentColor)
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
                opt("渠道", $channel, [("budget","低价"),("official","官方")])
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

            HStack {
                Button(action: enqueueGrokBatch) {
                    Label("加入批量队列 (\(parsedGrokBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedGrokBatchPrompts.isEmpty)

                if !queueStore.items.isEmpty {
                    Text("队列: \(queueStore.pendingCount) 待提交")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let msg = batchMessage { Text(msg).font(.caption).foregroundColor(msg.contains("失败") ? .red : .green) }
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
        }
    }

    private var parsedGrokBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private func enqueueGrokBatch() {
        let prompts = parsedGrokBatchPrompts
        guard !prompts.isEmpty else { return }
        errorMessage = nil; batchMessage = nil

        let items = prompts.map { prompt in
            GenerationQueueItem(
                kind: .grok,
                createdAt: Date(),
                params: .grok(GrokJobParams(
                    prompt: prompt, channel: channel, mode: mode,
                    aspectRatio: ratio, resolution: resolution, duration: duration
                ))
            )
        }
        queueStore.enqueueBatch(items)
        batchMessage = "已加入 \(items.count) 条 Grok 任务到队列"
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
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPrompt.count < 5 { return "提示词至少 5 个字符" }
        if channel == "official" && trimmedPrompt.count > 800 { return "官方稳定版提示词不能超过 800 字" }
        if channel == "budget" && trimmedPrompt.count > 20_000 { return "低价渠道提示词不能超过 20000 字" }
        if mode == "image" {
            if imageFiles.isEmpty { return "图生视频需上传参考图" }
            if channel == "official" && imageFiles.count > 1 { return "官方图生视频只支持 1 张图片" }
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
}
