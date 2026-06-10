import SwiftUI
import AVKit
import AVFoundation

// MARK: - 语音生成与克隆

struct VoiceGenView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var selectedPlatform = "elevenlabs"
    @State private var text = ""
    @State private var voiceId = ""
    @State private var modelId = ""
    @State private var speed: Double = 1.0
    @State private var stability: Double = 0.5
    @State private var similarityBoost: Double = 0.75
    @State private var style: Double = 0.0
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultAudioUrl: String?
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false

    // 声音管理
    @State private var voices: [EleVoice] = []
    @State private var models: [EleTTSModel] = []
    @State private var minimaxVoices: [MiniMaxVoice] = []
    @State private var isLoadingVoices = false
    @State private var searchQuery = ""
    @State private var showCloneSheet = false
    @State private var cloneName = ""
    @State private var cloneAudioURL: URL?

    // 文案优化
    @State private var isOptimizing = false

    // 预设
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?
    @StateObject private var preflight = GenerationPreflightService()

    private let platforms = [
        ("elevenlabs", "ElevenLabs"),
        ("minimax", "MiniMax")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 平台选择
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("平台").font(.caption2).foregroundColor(.secondary)
                        Picker("", selection: $selectedPlatform) {
                            ForEach(platforms, id: \.0) { (code, name) in
                                Text(name).tag(code)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                        .onChange(of: selectedPlatform) { _, _ in
                            loadVoiceList()
                            if selectedPlatform == "elevenlabs" { loadModelList() }
                        }
                    }
                }

                // 文本输入
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("文本内容").font(.headline)
                        Spacer()
                        Button("优化文案") { optimizeText() }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isOptimizing)
                    }
                    TextEditor(text: $text)
                        .font(.body).frame(height: 100)
                        .scrollContentBackground(.hidden).padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }

                // 声音选择
                voiceSelector

                // 模型选择（ElevenLabs）
                if selectedPlatform == "elevenlabs" {
                    modelSelector
                }

                // 参数调节
                parameterSliders

                presetRow
                preflightBanner()

                // 操作按钮
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8); Text("生成中...")
                        } else {
                            Label("朗读", systemImage: "waveform")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || voiceId.isEmpty || isGenerating || preflight.state.isBlocking)
                }

                if let err = errorMessage {
                    Text(err).foregroundColor(.red).font(.caption)
                }

                // 音频播放
                if let audioUrl = resultAudioUrl {
                    Divider().padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("生成结果").font(.headline)
                        HStack {
                            Button(action: { playAudio(url: audioUrl) }) {
                                Label(isPlaying ? "播放中..." : "播放", systemImage: isPlaying ? "speaker.wave.2.fill" : "play.circle")
                            }
                            .buttonStyle(.bordered)
                            Button("下载") {
                                if let url = URL(string: audioUrl) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            Button("复制链接") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(audioUrl, forType: .string)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                // 声音管理
                if !isLoadingVoices {
                    voiceManagementSection
                }
            }
            .padding(24)
        }
        .onAppear {
            applyEditIfNeeded()
            applyRecordIfNeeded()
            loadVoiceList()
            if selectedPlatform == "elevenlabs" { loadModelList() }
            triggerPreflight()
        }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
        .onChange(of: editCoordinator.applyRecord?.id) { _, _ in applyRecordIfNeeded() }
        .onChange(of: text) { _, _ in triggerPreflight() }
        .onChange(of: voiceId) { _, _ in triggerPreflight() }
        .sheet(isPresented: $showCloneSheet) {
            cloneSheet
        }
    }

    // MARK: - Voice & Model Loading

    private func loadVoiceList() {
        isLoadingVoices = true
        Task {
            do {
                if selectedPlatform == "elevenlabs" {
                    let resp = try await api.fetchElevenLabsVoices()
                    voices = resp.voices ?? []
                } else {
                    let resp = try await api.fetchMiniMaxVoices()
                    minimaxVoices = resp.voices ?? []
                }
            } catch {
                errorMessage = "加载声音列表失败: \(error.localizedDescription)"
            }
            isLoadingVoices = false
        }
    }

    private func loadModelList() {
        Task {
            do {
                let resp = try await api.fetchElevenLabsModels()
                models = resp.models ?? []
                if modelId.isEmpty, let first = models.first {
                    modelId = first.modelId
                }
            } catch {
                // 模型加载失败不阻塞操作
            }
        }
    }

    // MARK: - Voice Selector

    private var voiceSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("选择声音").font(.headline)
                Spacer()
                if isLoadingVoices {
                    ProgressView().scaleEffect(0.6)
                }
            }
            if selectedPlatform == "elevenlabs" {
                HStack {
                    TextField("搜索声音...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { searchVoices() }
                    Button("搜索") { searchVoices() }
                        .buttonStyle(.bordered)
                    Button("刷新") { loadVoiceList() }
                        .buttonStyle(.bordered)
                }

                Picker("", selection: $voiceId) {
                    Text("请选择声音").tag("")
                    ForEach(filteredVoices) { voice in
                        Text(voice.name ?? voice.voiceId).tag(voice.voiceId)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 400)
            } else {
                Picker("", selection: $voiceId) {
                    Text("请选择声音").tag("")
                    ForEach(minimaxVoices) { voice in
                        Text(voice.name ?? voice.voiceId).tag(voice.voiceId)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 400)
            }
        }
    }

    private var filteredVoices: [EleVoice] {
        guard !searchQuery.isEmpty else { return voices }
        let q = searchQuery.lowercased()
        return voices.filter {
            ($0.name ?? "").lowercased().contains(q) ||
            $0.voiceId.lowercased().contains(q)
        }
    }

    private func searchVoices() {
        guard !searchQuery.isEmpty else { loadVoiceList(); return }
        isLoadingVoices = true
        Task {
            do {
                let resp = try await api.searchElevenLabsVoices(query: searchQuery)
                voices = resp.voices ?? []
            } catch {
                errorMessage = "搜索声音失败: \(error.localizedDescription)"
            }
            isLoadingVoices = false
        }
    }

    // MARK: - Model Selector

    private var modelSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TTS 模型").font(.headline)
            Picker("", selection: $modelId) {
                Text("默认模型").tag("")
                ForEach(models) { model in
                    Text(model.name ?? model.modelId).tag(model.modelId)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 400)
        }
    }

    // MARK: - Parameter Sliders

    private var parameterSliders: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("参数调节").font(.headline)

            VStack(spacing: 4) {
                HStack {
                    Text("语速: \(String(format: "%.1f", speed))x").font(.caption)
                    Spacer()
                }
                Slider(value: $speed, in: 0.5...2.0, step: 0.1)
            }

            if selectedPlatform == "elevenlabs" {
                VStack(spacing: 4) {
                    HStack {
                        Text("稳定性: \(String(format: "%.0f", stability * 100))%").font(.caption)
                        Spacer()
                    }
                    Slider(value: $stability, in: 0...1, step: 0.05)
                }

                VStack(spacing: 4) {
                    HStack {
                        Text("相似度: \(String(format: "%.0f", similarityBoost * 100))%").font(.caption)
                        Spacer()
                    }
                    Slider(value: $similarityBoost, in: 0...1, step: 0.05)
                }

                VStack(spacing: 4) {
                    HStack {
                        Text("风格: \(String(format: "%.0f", style * 100))%").font(.caption)
                        Spacer()
                    }
                    Slider(value: $style, in: 0...1, step: 0.05)
                }
            }
        }
    }

    // MARK: - Voice Management

    private var voiceManagementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 4)
            HStack {
                Text("声音管理").font(.headline)
                Spacer()
                Button("创建克隆") { showCloneSheet = true }
                    .buttonStyle(.bordered)
            }

            if selectedPlatform == "elevenlabs" {
                if voices.isEmpty {
                    Text("暂无声音").font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(voices) { voice in
                        HStack {
                            Text(voice.name ?? voice.voiceId)
                            Spacer()
                            if let _ = voice.previewUrl {
                                Button("试听") {
                                    // 使用 previewUrl 播放
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                            Button("删除") {
                                deleteVoice(voice.voiceId)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                    }
                }
            }
        }
    }

    private func deleteVoice(_ voiceId: String) {
        Task {
            do {
                _ = try await api.deleteElevenLabsVoice(voiceId)
                loadVoiceList()
            } catch {
                errorMessage = "删除失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Clone Sheet

    private var cloneSheet: some View {
        VStack(spacing: 16) {
            Text("创建语音克隆").font(.headline)
            TextField("克隆名称", text: $cloneName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("选择音频文件") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.mp3, .wav, .aiff]
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            cloneAudioURL = url
                        }
                    }
                }
                .buttonStyle(.bordered)
                if let url = cloneAudioURL {
                    Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary)
                }
            }

            HStack {
                Button("取消") { showCloneSheet = false }
                    .buttonStyle(.bordered)
                Button("创建") { createClone() }
                    .buttonStyle(.borderedProminent)
                    .disabled(cloneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cloneAudioURL == nil)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func createClone() {
        guard let url = cloneAudioURL, let data = try? Data(contentsOf: url) else {
            errorMessage = "无法读取音频文件"
            return
        }
        let mime = audioMimeType(for: url.lastPathComponent)
        showCloneSheet = false
        Task {
            do {
                if selectedPlatform == "elevenlabs" {
                    _ = try await api.createElevenLabsClone(name: cloneName, audioData: data, audioName: url.lastPathComponent, audioMime: mime)
                } else {
                    _ = try await api.createMiniMaxClone(name: cloneName, audioData: data, audioName: url.lastPathComponent, audioMime: mime)
                }
                cloneName = ""
                cloneAudioURL = nil
                loadVoiceList()
            } catch {
                errorMessage = "克隆失败: \(error.localizedDescription)"
            }
        }
    }

    private func audioMimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "m4a", "aac": return "audio/mp4"
        case "aiff", "aif": return "audio/aiff"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        default: return "audio/mpeg"
        }
    }

    // MARK: - Text Optimization

    private func optimizeText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isOptimizing = true
        Task {
            do {
                let resp = try await api.optimizeText(trimmed)
                if let optimized = resp.optimizedText {
                    text = optimized
                }
            } catch {
                errorMessage = "文案优化失败: \(error.localizedDescription)"
            }
            isOptimizing = false
        }
    }

    // MARK: - Generation

    private func startGeneration() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !voiceId.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        resultAudioUrl = nil

        let params = VoiceGenJobParams(
            platform: selectedPlatform, voiceId: voiceId, modelId: modelId,
            text: trimmed, speed: speed, stability: stability,
            similarityBoost: similarityBoost, style: style
        )
        let item = GenerationQueueItem(kind: .voiceGen, createdAt: Date(), params: .voiceGen(params))
        queueStore.enqueue(item)
        editCoordinator.editingItem = nil
        isGenerating = false
    }

    private func playAudio(url: String) {
        guard let url = URL(string: url) else { return }
        audioPlayer = AVPlayer(url: url)
        audioPlayer?.play()
        isPlaying = true
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
        }
    }

    // MARK: - Edit / Record

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .voiceGen(let p) = item.params else { return }
        selectedPlatform = p.platform
        text = p.text
        voiceId = p.voiceId
        modelId = p.modelId
        speed = p.speed
        stability = p.stability
        similarityBoost = p.similarityBoost
        style = p.style
        errorMessage = nil
        resultAudioUrl = nil
        isGenerating = false
        editCoordinator.editingItem = nil
    }

    private func applyRecordIfNeeded() {
        guard let record = editCoordinator.applyRecord else { return }
        defer { editCoordinator.applyRecord = nil }
        guard let snapshot = record.paramsSnapshot,
              let data = snapshot.data(using: .utf8),
              let params = try? JSONDecoder().decode(WorkRecordParams.self, from: data),
              case .voiceGen(let platform) = params
        else { return }
        selectedPlatform = platform
        errorMessage = nil
        resultAudioUrl = nil
        isGenerating = false
    }

    // MARK: - Presets

    private var presetRow: some View {
        let kind = PresetKind.voiceGen
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
                    guard case .voiceGen(let p) = preset.params else { return }
                    selectedPlatform = p.platform
                    voiceId = p.voiceId
                    modelId = p.modelId
                    speed = p.speed
                    stability = p.stability
                    similarityBoost = p.similarityBoost
                    style = p.style
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
                let params = VoiceGenPresetParams(
                    platform: selectedPlatform, voiceId: voiceId, modelId: modelId,
                    speed: speed, stability: stability, similarityBoost: similarityBoost, style: style
                )
                presetStore.save(name: name, params: .voiceGen(params))
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text("保存当前语音参数设置")
        }
    }

    // MARK: - Preflight

    private func triggerPreflight() {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasVoice = !voiceId.isEmpty
        guard hasText, hasVoice else { preflight.reset(); return }
        let params = VoiceGenJobParams(
            platform: selectedPlatform, voiceId: voiceId, modelId: modelId,
            text: text, speed: speed, stability: stability,
            similarityBoost: similarityBoost, style: style
        )
        preflight.schedule(for: .voiceGen(params))
    }

    private func preflightBanner() -> some View {
        VStack(spacing: 0) {
            switch preflight.state {
            case .loading:
                HStack { ProgressView().scaleEffect(0.6); Text("估算费用...").font(.caption).foregroundColor(.secondary); Spacer() }
                    .padding(.horizontal)
            case .ready(let info):
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                    Text("预估费用: \(info.estimatedPriceUsd) USD")
                        .font(.caption).foregroundColor(.secondary)
                    if info.estimatedDurationSeconds > 0 {
                        Text("· 预计 \(info.estimatedDurationSeconds)s").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            case .insufficient(let info):
                HStack {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange).font(.caption)
                    Text("余额不足: \(info.estimatedPriceUsd) USD").font(.caption).foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal)
            case .unavailable:
                HStack {
                    Image(systemName: "questionmark.circle").foregroundColor(.secondary).font(.caption)
                    Text("暂无法估算费用").font(.caption).foregroundColor(.secondary); Spacer()
                }
                .padding(.horizontal)
            default: EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}
