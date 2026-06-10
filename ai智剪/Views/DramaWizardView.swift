import SwiftUI
import AVKit

// MARK: - Drama Wizard View

struct DramaWizardView: View {
    @EnvironmentObject var api: APIService

    // MARK: - Step 1: Type Selection

    @State private var dramaType = "带货"
    @State private var productInfo = ""
    @State private var educationTopic = ""
    @State private var language = "中文"

    // MARK: - Step 2: Outline Preview

    @State private var outline: String?
    @State private var outlineId: String?
    @State private var isGeneratingOutline = false
    @State private var perspectiveIndex = 0

    // MARK: - Step 3: Storyboard & Script

    @State private var storyboard: String?
    @State private var storyboardId: String?
    @State private var script: String?
    @State private var scriptId: String?
    @State private var isGeneratingStoryboard = false
    @State private var isGeneratingScript = false

    // MARK: - Step 4: Script Edit + Voice

    @State private var editedScript = ""
    @State private var selectedVoicePlatform = "elevenlabs"
    @State private var elevenlabsVoices: [EleVoice] = []
    @State private var minimaxVoices: [MiniMaxVoice] = []
    @State private var voiceId = ""
    @State private var isLoadingVoices = false
    @State private var isSubmittingVoiceover = false
    @State private var voiceTaskId: String?

    // MARK: - Step 5: Video Tasks

    @State private var videoTaskStatuses: [DramaVideoTask] = []
    @State private var isSubmittingVideo = false
    @State private var isPollingTasks = false

    // MARK: - Step 6: Concat & Preview

    @State private var concatVideoUrl: String?
    @State private var isConcatting = false
    @State private var player: AVPlayer?

    // MARK: - General

    @State private var currentStep = 0
    @State private var errorMessage: String?
    @State private var showError = false

    private let stepTitles = ["类型选择", "大纲预览", "分镜脚本", "配音编辑", "视频任务", "合成预览"]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            stepIndicatorView
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stepContent
                }
                .padding(24)
            }
            Divider()
            navigationBar
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear { loadVoices() }
        .onChange(of: errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("错误", isPresented: $showError) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Step Indicator

    private var stepIndicatorView: some View {
        HStack(spacing: 0) {
            ForEach(stepTitles.indices, id: \.self) { i in
                let isActive = i == currentStep
                let isCompleted = i < currentStep
                HStack(spacing: 6) {
                    if i > 0 {
                        Rectangle()
                            .fill(isCompleted ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: 24)
                    }
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(isActive || isCompleted ? Color.accentColor : Color.secondary.opacity(0.15))
                                .frame(width: 24, height: 24)
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                            } else {
                                Text("\(i + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(isActive ? .white : .secondary)
                            }
                        }
                        Text(stepTitles[i])
                            .font(.caption2)
                            .foregroundColor(isActive ? .primary : .secondary)
                            .fixedSize()
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        if currentStep == 0 {
            step1TypeSelection
        } else if currentStep == 1 {
            step2OutlinePreview
        } else if currentStep == 2 {
            step3StoryboardScript
        } else if currentStep == 3 {
            step4ScriptEditVoice
        } else if currentStep == 4 {
            step5VideoTasks
        } else if currentStep == 5 {
            step6ConcatPreview
        }
    }

    // MARK: - Step 1: Type Selection

    private var step1TypeSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("短剧类型")
                .font(.headline)

            Picker("类型", selection: $dramaType) {
                Text("带货").tag("带货")
                Text("科普").tag("科普")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            if dramaType == "带货" {
                VStack(alignment: .leading, spacing: 6) {
                    Text("产品信息").font(.headline)
                    TextField("输入产品名称、特点、卖点...", text: $productInfo)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("科普主题").font(.headline)
                    TextField("输入科普主题、方向...", text: $educationTopic)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("语言").font(.headline)
                Picker("语言", selection: $language) {
                    Text("中文").tag("中文")
                    Text("English").tag("English")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            Text(dramaType == "带货"
                 ? "将根据产品信息生成带货短剧大纲"
                 : "将根据科普主题生成科普短剧大纲")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Step 2: Outline Preview

    private var step2OutlinePreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI 生成的大纲")
                    .font(.headline)
                Spacer()
                if isGeneratingOutline {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let outline {
                ScrollView {
                    Text(outline)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 200, maxHeight: 300)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("点击下方按钮生成大纲")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }

            if !isGeneratingOutline {
                HStack(spacing: 12) {
                    Button(action: generateOutline) {
                        Label("生成大纲", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGeneratingOutline)

                    if outline != nil {
                        Button(action: regenerateOutline) {
                            Label("换一个", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)

                        Button(action: changePerspective) {
                            Label("换角度", systemImage: "arrow.right.arrow.left")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if let outlineId, let outline {
                Text("大纲 ID: \(outlineId.prefix(12))...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Step 3: Storyboard & Script

    private var step3StoryboardScript: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Storyboard section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("分镜（Storyboard）")
                        .font(.headline)
                    Spacer()
                    if isGeneratingStoryboard {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if let storyboard {
                    ScrollView {
                        Text(storyboard)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 120, maxHeight: 200)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.split.2x2")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                        Text("确认大纲后生成分镜")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }

                Button(action: generateStoryboard) {
                    Label("生成分镜", systemImage: "rectangle.split.2x2")
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingStoryboard || outlineId == nil)
            }

            Divider()

            // Script section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("完整脚本")
                        .font(.headline)
                    Spacer()
                    if isGeneratingScript {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if let script {
                    ScrollView {
                        Text(script)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 150, maxHeight: 300)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                        Text("生成分镜后生成完整脚本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }

                Button(action: generateScript) {
                    Label("生成完整脚本", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingScript || outlineId == nil)

                if let scriptId {
                    Text("脚本 ID: \(scriptId.prefix(12))...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Step 4: Script Edit + Voice

    private var step4ScriptEditVoice: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Script editor
            VStack(alignment: .leading, spacing: 6) {
                Text("编辑脚本")
                    .font(.headline)
                TextEditor(text: $editedScript)
                    .font(.body)
                    .frame(minHeight: 150, maxHeight: 250)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }
            .onAppear {
                if editedScript.isEmpty, let script {
                    editedScript = script
                }
            }

            Divider()

            // Voice selection
            VStack(alignment: .leading, spacing: 8) {
                Text("配音设置")
                    .font(.headline)

                Picker("平台", selection: $selectedVoicePlatform) {
                    Text("ElevenLabs").tag("elevenlabs")
                    Text("MiniMax").tag("minimax")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
                .onChange(of: selectedVoicePlatform) { _, _ in
                    loadVoices()
                }

                HStack {
                    if isLoadingVoices {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("加载声音列表...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("选择声音", selection: $voiceId) {
                            Text("请选择声音").tag("")
                            if selectedVoicePlatform == "elevenlabs" {
                                ForEach(elevenlabsVoices) { voice in
                                    Text(voice.name ?? voice.voiceId).tag(voice.voiceId)
                                }
                            } else {
                                ForEach(minimaxVoices) { voice in
                                    Text(voice.name ?? voice.voiceId).tag(voice.voiceId)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 400)
                    }
                }

                HStack(spacing: 12) {
                    Button(action: submitVoiceover) {
                        if isSubmittingVoiceover {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("提交中...")
                            }
                        } else {
                            Label("配音", systemImage: "waveform")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmittingVoiceover || voiceId.isEmpty || editedScript.isEmpty)

                    if let voiceTaskId {
                        Text("配音任务已提交: \(voiceTaskId.prefix(12))...")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Video Tasks

    private var step5VideoTasks: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频生成任务")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("将大纲和脚本提交为视频生成任务，系统会自动按分镜生成对应片段。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: submitVideoTasks) {
                    if isSubmittingVideo {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("提交中...")
                        }
                    } else {
                        Label("提交视频任务", systemImage: "video.badge.plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmittingVideo || outlineId == nil || scriptId == nil)
            }

            if !videoTaskStatuses.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("任务状态")
                            .font(.headline)
                        Spacer()
                        if isPollingTasks {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("轮询中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(videoTaskStatuses.indices, id: \.self) { i in
                        let task = videoTaskStatuses[i]
                        HStack {
                            Image(systemName: statusIcon(for: task.status))
                                .foregroundColor(statusColor(for: task.status))
                            Text("场景 \(task.sceneIndex.map(String.init) ?? "?")")
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            Text(task.taskId.prefix(12) + "...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(task.status ?? "排队中")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .onChange(of: videoTaskStatuses.count) { _, _ in
            if !videoTaskStatuses.isEmpty {
                startTaskPolling()
            }
        }
    }

    // MARK: - Step 6: Concat & Preview

    private var step6ConcatPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频合成与预览")
                .font(.headline)

            Button(action: concatVideo) {
                if isConcatting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("合成中...")
                    }
                } else {
                    Label("拼接视频", systemImage: "rectangle.connected.to.line.below")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConcatting)

            if let concatVideoUrl, let url = URL(string: concatVideoUrl) {
                Divider()

                Text("预览")
                    .font(.headline)

                AppKitVideoPlayerView(player: player)
                    .frame(minHeight: 260)
                    .cornerRadius(8)
                    .onAppear {
                        if player == nil {
                            player = AVPlayer(url: url)
                        }
                    }
                    .onDisappear {
                        player?.pause()
                    }

                HStack(spacing: 12) {
                    Button(action: { player?.seek(to: .zero); player?.play() }) {
                        Label("播放", systemImage: "play.circle")
                    }
                    .buttonStyle(.bordered)

                    Button(action: exportVideo) {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if currentStep > 0 {
                Button(action: { currentStep -= 1 }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一步")
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep < stepTitles.count - 1 {
                Button(action: goToNextStep) {
                    HStack(spacing: 4) {
                        Text("下一步")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceedToNext)
            }
        }
    }

    private var canProceedToNext: Bool {
        switch currentStep {
        case 0:
            return !productInfo.isEmpty || !educationTopic.isEmpty
        case 1:
            return outline != nil
        case 2:
            return script != nil
        case 3:
            return true // voiceover is optional
        case 4:
            return !videoTaskStatuses.isEmpty
        default:
            return true
        }
    }

    private func goToNextStep() {
        // Trigger any auto-generation when transitioning
        if currentStep == 0 && outline == nil {
            // User can navigate to step 2 without generating outline
        }
        currentStep += 1
    }

    // MARK: - API Methods

    private func generateOutline() {
        isGeneratingOutline = true
        errorMessage = nil
        Task {
            do {
                let result = try await api.generateDramaOutline(
                    dramaType: dramaType,
                    productInfo: dramaType == "带货" ? productInfo : nil,
                    educationTopic: dramaType == "科普" ? educationTopic : nil,
                    language: language,
                    perspectiveIndex: nil,
                    changePerspective: nil,
                    previousOutline: nil
                )
                if result.success, let resultOutline = result.outline {
                    outline = resultOutline
                    outlineId = result.outlineId
                } else {
                    errorMessage = result.message ?? "生成大纲失败"
                }
            } catch {
                errorMessage = "生成大纲失败: \(error.localizedDescription)"
            }
            isGeneratingOutline = false
        }
    }

    private func regenerateOutline() {
        perspectiveIndex = 0
        outline = nil
        outlineId = nil
        script = nil
        scriptId = nil
        storyboard = nil
        storyboardId = nil
        generateOutline()
    }

    private func changePerspective() {
        isGeneratingOutline = true
        errorMessage = nil
        perspectiveIndex += 1
        Task {
            do {
                let result = try await api.generateDramaOutline(
                    dramaType: dramaType,
                    productInfo: dramaType == "带货" ? productInfo : nil,
                    educationTopic: dramaType == "科普" ? educationTopic : nil,
                    language: language,
                    perspectiveIndex: perspectiveIndex,
                    changePerspective: true,
                    previousOutline: outline
                )
                if result.success, let resultOutline = result.outline {
                    outline = resultOutline
                    outlineId = result.outlineId
                } else {
                    errorMessage = result.message ?? "换角度失败"
                }
            } catch {
                errorMessage = "切换角度失败: \(error.localizedDescription)"
            }
            isGeneratingOutline = false
        }
    }

    private func generateStoryboard() {
        guard let outlineId else {
            errorMessage = "请先生成大纲"
            return
        }
        isGeneratingStoryboard = true
        errorMessage = nil
        Task {
            do {
                let result = try await api.generateDramaStoryboard(outlineId: outlineId)
                if result.success, let resultStoryboard = result.storyboard {
                    storyboard = resultStoryboard
                    storyboardId = result.storyboardId
                } else {
                    errorMessage = result.message ?? "生成分镜失败"
                }
            } catch {
                errorMessage = "生成分镜失败: \(error.localizedDescription)"
            }
            isGeneratingStoryboard = false
        }
    }

    private func generateScript() {
        guard let outlineId else {
            errorMessage = "请先生成大纲"
            return
        }
        isGeneratingScript = true
        errorMessage = nil
        Task {
            do {
                let result = try await api.generateDramaScript(outlineId: outlineId, storyboardId: storyboardId)
                if result.success, let resultScript = result.script {
                    script = resultScript
                    scriptId = result.scriptId
                    editedScript = resultScript
                } else {
                    errorMessage = result.message ?? "生成脚本失败"
                }
            } catch {
                errorMessage = "生成脚本失败: \(error.localizedDescription)"
            }
            isGeneratingScript = false
        }
    }

    private func loadVoices() {
        isLoadingVoices = true
        Task {
            do {
                if selectedVoicePlatform == "elevenlabs" {
                    let resp = try await api.fetchElevenLabsVoices()
                    if let voices = resp.voices {
                        elevenlabsVoices = voices
                    }
                } else {
                    let resp = try await api.fetchMiniMaxVoices()
                    if let voices = resp.voices {
                        minimaxVoices = voices
                    }
                }
            } catch {
                // Silently fail - voices not critical
                if selectedVoicePlatform == "elevenlabs" {
                    elevenlabsVoices = []
                } else {
                    minimaxVoices = []
                }
            }
            isLoadingVoices = false
        }
    }

    private func submitVoiceover() {
        guard let scriptId, !voiceId.isEmpty else {
            errorMessage = "请先生成脚本并选择声音"
            return
        }
        isSubmittingVoiceover = true
        errorMessage = nil
        Task {
            do {
                let result = try await api.submitDramaVoiceover(
                    scriptId: scriptId,
                    voiceId: voiceId,
                    platform: selectedVoicePlatform
                )
                if result.success, let taskId = result.taskId {
                    voiceTaskId = taskId
                } else {
                    errorMessage = result.message ?? "提交配音失败"
                }
            } catch {
                errorMessage = "配音提交失败: \(error.localizedDescription)"
            }
            isSubmittingVoiceover = false
        }
    }

    private func submitVideoTasks() {
        guard let outlineId, let scriptId else {
            errorMessage = "请先完成大纲和脚本"
            return
        }
        isSubmittingVideo = true
        errorMessage = nil
        Task {
            do {
                let result = try await api.submitDramaVideoTasks(
                    outlineId: outlineId,
                    scriptId: scriptId
                )
                if result.success, let tasks = result.tasks, !tasks.isEmpty {
                    videoTaskStatuses = tasks
                } else {
                    errorMessage = result.message ?? "提交视频任务失败"
                }
            } catch {
                errorMessage = "提交视频任务失败: \(error.localizedDescription)"
            }
            isSubmittingVideo = false
        }
    }

    private func startTaskPolling() {
        guard !isPollingTasks else { return }
        isPollingTasks = true
        let taskIds = videoTaskStatuses.map(\.taskId)
        Task {
            while isPollingTasks {
                do {
                    for i in videoTaskStatuses.indices {
                        let taskId = videoTaskStatuses[i].taskId
                        let status = try await api.queryDramaTaskStatus(taskId: taskId)
                        if status.success {
                            videoTaskStatuses[i] = DramaVideoTask(
                                taskId: taskId,
                                sceneIndex: videoTaskStatuses[i].sceneIndex,
                                status: status.status ?? videoTaskStatuses[i].status
                            )
                        }
                    }
                    // Check if all tasks are done
                    let allDone = videoTaskStatuses.allSatisfy { task in
                        let s = task.status ?? ""
                        return s == "完成" || s == "completed" || s == "failed" || s == "失败"
                    }
                    if allDone {
                        isPollingTasks = false
                    }
                } catch {
                    // Ignore polling errors, continue
                }
                if isPollingTasks {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }

    private func concatVideo() {
        let taskIds = videoTaskStatuses.map(\.taskId)
        guard !taskIds.isEmpty else {
            errorMessage = "没有可拼接的视频任务"
            return
        }
        isConcatting = true
        errorMessage = nil
        Task {
            do {
                let result = try await api.concatDramaVideo(taskIds: taskIds)
                if result.success, let url = result.videoUrl {
                    concatVideoUrl = url
                    if let validURL = URL(string: url) {
                        player = AVPlayer(url: validURL)
                    }
                } else {
                    errorMessage = result.message ?? "拼接视频失败"
                }
            } catch {
                errorMessage = "视频拼接失败: \(error.localizedDescription)"
            }
            isConcatting = false
        }
    }

    private func exportVideo() {
        guard let urlString = concatVideoUrl, let url = URL(string: urlString) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "短剧-\(df.string(from: Date())).mp4"
        panel.begin { response in
            if response == .OK, let destinationURL = panel.url {
                Task {
                    do {
                        let data = try Data(contentsOf: url)
                        try data.write(to: destinationURL)
                    } catch {
                        errorMessage = "导出失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusIcon(for status: String?) -> String {
        switch status {
        case "完成", "completed": return "checkmark.circle.fill"
        case "失败", "failed": return "xmark.circle.fill"
        case "处理中", "processing": return "gearshape.2"
        default: return "clock"
        }
    }

    private func statusColor(for status: String?) -> Color {
        switch status {
        case "完成", "completed": return .green
        case "失败", "failed": return .red
        case "处理中", "processing": return .orange
        default: return .secondary
        }
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
