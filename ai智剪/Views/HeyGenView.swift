import SwiftUI

// MARK: - HeyGen 数字人

struct HeyGenView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var avatarId = ""
    @State private var voiceId = ""
    @State private var language = "zh"
    @State private var text = ""
    @State private var title = ""
    @State private var speed: Double = 1.0
    @State private var isTaskPending = false
    @State private var submittedTaskId: String?
    @State private var errorMessage: String?
    @State private var resultVideoUrl: String?

    // 预设
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?
    @StateObject private var preflight = GenerationPreflightService()

    private let languages = [
        ("zh", "中文"),
        ("en", "English"),
        ("ja", "日本語"),
        ("ko", "한국어")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Avatar ID
                VStack(alignment: .leading, spacing: 6) {
                    Text("Avatar ID").font(.headline)
                    TextField("输入数字人 Avatar ID", text: $avatarId)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isTaskPending)
                }

                // Voice ID
                VStack(alignment: .leading, spacing: 6) {
                    Text("Voice ID").font(.headline)
                    TextField("输入声音 Voice ID", text: $voiceId)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isTaskPending)
                }

                // Language
                VStack(alignment: .leading, spacing: 6) {
                    Text("语言").font(.headline)
                    Picker("", selection: $language) {
                        ForEach(languages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                    .disabled(isTaskPending)
                }

                // Script text
                VStack(alignment: .leading, spacing: 6) {
                    Text("文案内容").font(.headline)
                    TextEditor(text: $text)
                        .font(.body)
                        .frame(height: 120)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        .disabled(isTaskPending)
                }

                // Title (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Text("标题（可选）").font(.headline)
                    TextField("输入视频标题", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isTaskPending)
                }

                // Speed
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("语速: \(String(format: "%.1f", speed))x").font(.caption)
                        Spacer()
                    }
                    Slider(value: $speed, in: 0.5...2.0, step: 0.1)
                        .disabled(isTaskPending)
                }

                presetRow
                preflightBanner()

                // Submit
                HStack {
                    Button(action: startGeneration) {
                        if isTaskPending {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("队列中...")
                            }
                        } else {
                            Label("生成数字人视频", systemImage: "person.wave.2")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(avatarId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || voiceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || isTaskPending
                              || preflight.state.isBlocking)
                }

                if let err = errorMessage {
                    Text(err).foregroundColor(.red).font(.caption)
                }

                // 任务进度提示
                if isTaskPending && resultVideoUrl == nil && errorMessage == nil {
                    HStack {
                        ProgressView().scaleEffect(0.6)
                        Text("任务已提交，请前往「任务队列」查看进度")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                // 结果展示
                if let videoUrl = resultVideoUrl {
                    Divider().padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("生成结果").font(.headline)
                        HStack {
                            Image(systemName: "video.fill").foregroundColor(.accentColor)
                            Text(videoUrl).lineLimit(1).truncationMode(.middle).font(.caption)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        HStack {
                            Button("在浏览器预览") {
                                if let url = URL(string: videoUrl) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            Button("复制链接") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(videoUrl, forType: .string)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear { applyEditIfNeeded(); applyRecordIfNeeded(); triggerPreflight() }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
        .onChange(of: editCoordinator.applyRecord?.id) { _, _ in applyRecordIfNeeded() }
        .onChange(of: avatarId) { _, _ in triggerPreflight() }
        .onChange(of: voiceId) { _, _ in triggerPreflight() }
        .onChange(of: text) { _, _ in triggerPreflight() }
        .onChange(of: queueStore.items.count) { _, _ in checkSubmittedTask() }
    }

    // MARK: - Queue Observation

    private func checkSubmittedTask() {
        guard let taskId = submittedTaskId else { return }
        guard let item = queueStore.items.first(where: { $0.id == taskId }) else {
            submittedTaskId = nil
            isTaskPending = false
            return
        }
        switch item.status {
        case .succeeded:
            resultVideoUrl = item.videoUrl
            isTaskPending = false
            submittedTaskId = nil
        case .failed:
            errorMessage = item.errorMessage ?? "任务失败"
            isTaskPending = false
            submittedTaskId = nil
        case .cancelled:
            errorMessage = "任务已取消"
            isTaskPending = false
            submittedTaskId = nil
        default:
            break
        }
    }

    // MARK: - Actions

    private func startGeneration() {
        let trimmedAvatar = avatarId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVoice = voiceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAvatar.isEmpty, !trimmedVoice.isEmpty, !trimmedText.isEmpty else {
            errorMessage = "请填写 Avatar ID、Voice ID 和文案内容"
            return
        }
        errorMessage = nil
        resultVideoUrl = nil

        let params = HeyGenJobParams(
            avatarId: trimmedAvatar,
            voiceId: trimmedVoice,
            language: language,
            text: trimmedText,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            speed: speed
        )
        let item = GenerationQueueItem(kind: .heygen, createdAt: Date(), params: .heygen(params))
        submittedTaskId = item.id
        isTaskPending = true
        queueStore.enqueue(item)
        editCoordinator.editingItem = nil
    }

    // MARK: - Edit / Record

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .heygen(let p) = item.params else { return }
        avatarId = p.avatarId
        voiceId = p.voiceId
        language = p.language
        text = p.text
        title = p.title
        speed = p.speed
        errorMessage = nil
        resultVideoUrl = nil
        isTaskPending = false
        submittedTaskId = nil
        editCoordinator.editingItem = nil
    }

    private func applyRecordIfNeeded() {
        guard let record = editCoordinator.applyRecord else { return }
        defer { editCoordinator.applyRecord = nil }
        guard let snapshot = record.paramsSnapshot,
              let data = snapshot.data(using: .utf8),
              let params = try? JSONDecoder().decode(WorkRecordParams.self, from: data),
              case .heygen(let avatar, let voice, let lang) = params
        else { return }
        avatarId = avatar
        voiceId = voice
        language = lang
        errorMessage = nil
        resultVideoUrl = nil
        isTaskPending = false
        submittedTaskId = nil
    }

    // MARK: - Presets

    private var presetRow: some View {
        let kind = PresetKind.heygen
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
                    guard case .heygen(let p) = preset.params else { return }
                    avatarId = p.avatarId
                    voiceId = p.voiceId
                    language = p.language
                    speed = p.speed
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
                let params = HeyGenPresetParams(
                    avatarId: avatarId,
                    voiceId: voiceId,
                    language: language,
                    speed: speed
                )
                presetStore.save(name: name, params: .heygen(params))
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text("保存当前 HeyGen 数字人参数设置")
        }
    }

    // MARK: - Preflight

    private func triggerPreflight() {
        let hasAvatar = !avatarId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasVoice = !voiceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasAvatar, hasVoice, hasText else { preflight.reset(); return }
        let params = HeyGenJobParams(
            avatarId: avatarId,
            voiceId: voiceId,
            language: language,
            text: text,
            title: title,
            speed: speed
        )
        preflight.schedule(for: .heygen(params))
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
