import SwiftUI

// MARK: - 视频文案提取

struct TranscriptView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var videoUrl = ""
    @State private var language = "zh"
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var transcriptResult: String?
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?
    @StateObject private var preflight = GenerationPreflightService()

    private let languages = [
        ("zh", "中文"),
        ("en", "英语"),
        ("ja", "日语"),
        ("ko", "韩语"),
        ("auto", "自动检测")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 视频 URL 输入
                VStack(alignment: .leading, spacing: 6) {
                    Text("视频 URL").font(.headline)
                    TextField("输入视频链接（支持 YouTube、B站等）", text: $videoUrl)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .lineLimit(1)
                }

                // 语言选择
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("视频语言").font(.caption2).foregroundColor(.secondary)
                        Picker("", selection: $language) {
                            ForEach(languages, id: \.0) { (code, name) in
                                Text(name).tag(code)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 500)
                    }
                }

                presetRow
                preflightBanner()

                // 操作按钮
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8); Text("提取中...")
                        } else {
                            Label("提取文案", systemImage: "doc.text.magnifyingglass")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(videoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || preflight.state.isBlocking)

                    if transcriptResult != nil {
                        Button("复制结果") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(transcriptResult ?? "", forType: .string)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let err = errorMessage {
                    Text(err).foregroundColor(.red).font(.caption)
                }

                // 结果展示
                if let result = transcriptResult {
                    Divider().padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("提取结果").font(.headline)
                        ScrollView {
                            Text(result)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .frame(minHeight: 200, maxHeight: 400)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    }
                }
            }
            .padding(24)
        }
        .onAppear { applyEditIfNeeded(); applyRecordIfNeeded(); triggerPreflight() }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
        .onChange(of: editCoordinator.applyRecord?.id) { _, _ in applyRecordIfNeeded() }
        .onChange(of: videoUrl) { _, _ in triggerPreflight() }
        .onChange(of: language) { _, _ in triggerPreflight() }
    }

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .transcript(let p) = item.params else { return }
        videoUrl = p.videoUrl
        language = p.language
        errorMessage = nil
        transcriptResult = nil
        isGenerating = false
        editCoordinator.editingItem = nil
    }

    private func applyRecordIfNeeded() {
        guard let record = editCoordinator.applyRecord else { return }
        defer { editCoordinator.applyRecord = nil }
        guard let snapshot = record.paramsSnapshot,
              let data = snapshot.data(using: .utf8),
              let params = try? JSONDecoder().decode(WorkRecordParams.self, from: data),
              case .transcript(let lang) = params
        else { return }
        videoUrl = record.prompt
        language = lang
        errorMessage = nil
        transcriptResult = nil
        isGenerating = false
    }

    private func startGeneration() {
        let trimmed = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        transcriptResult = nil

        let params = TranscriptJobParams(videoUrl: trimmed, language: language)
        let item = GenerationQueueItem(kind: .transcript, createdAt: Date(), params: .transcript(params))
        queueStore.enqueue(item)
        editCoordinator.editingItem = nil
        isGenerating = false
    }

    // MARK: - Presets

    private var presetRow: some View {
        let kind = PresetKind.transcript
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
                    guard case .transcript(let p) = preset.params else { return }
                    language = p.language
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
                let params = TranscriptPresetParams(language: language)
                presetStore.save(name: name, params: .transcript(params))
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text("保存当前语言设置")
        }
    }

    // MARK: - Preflight

    private func triggerPreflight() {
        let hasUrl = !videoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasUrl else { preflight.reset(); return }
        let params = TranscriptJobParams(videoUrl: videoUrl, language: language)
        preflight.schedule(for: .transcript(params))
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
