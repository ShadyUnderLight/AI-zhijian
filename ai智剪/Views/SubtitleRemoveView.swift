import SwiftUI
import UniformTypeIdentifiers

// MARK: - 视频去字幕

struct SubtitleRemoveView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var selectedVideoURL: URL?
    @State private var videoData: Data?
    @State private var videoName = ""
    @State private var region = "full"
    @State private var isTaskPending = false
    @State private var submittedTaskId: String?
    @State private var errorMessage: String?
    @State private var resultVideoUrl: String?
    @State private var isLoadingFile = false
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?
    @StateObject private var preflight = GenerationPreflightService()

    private let regions = [
        ("full", "全屏"),
        ("bottom", "底部"),
        ("top", "顶部")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 视频选择
                VStack(alignment: .leading, spacing: 6) {
                    Text("选择视频").font(.headline)
                    HStack {
                        if let url = selectedVideoURL {
                            Label(url.lastPathComponent, systemImage: "film")
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Label("未选择文件", systemImage: "video.slash")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if isLoadingFile {
                            ProgressView().scaleEffect(0.6)
                        }
                        Button("选择视频") { pickVideo() }
                            .buttonStyle(.bordered)
                            .disabled(isLoadingFile || isTaskPending)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }

                // 去字幕区域
                VStack(alignment: .leading, spacing: 2) {
                    Text("去除区域").font(.caption2).foregroundColor(.secondary)
                    Picker("", selection: $region) {
                        ForEach(regions, id: \.0) { (code, name) in
                            Text(name).tag(code)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    .disabled(isTaskPending)
                }

                presetRow
                preflightBanner()

                // 操作按钮
                HStack {
                    Button(action: startGeneration) {
                        if isTaskPending {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("队列中...")
                            }
                        } else {
                            Label("去字幕", systemImage: "text.badge.minus")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(videoData == nil || isTaskPending || preflight.state.isBlocking)
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
                        Text("处理结果").font(.headline)
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
                            Button("复制链接") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(videoUrl, forType: .string)
                            }
                            .buttonStyle(.bordered)
                            Button("在浏览器打开") {
                                if let url = URL(string: videoUrl) {
                                    NSWorkspace.shared.open(url)
                                }
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
        .onChange(of: videoData?.count) { _, _ in triggerPreflight() }
        .onChange(of: region) { _, _ in triggerPreflight() }
        .onChange(of: queueStore.items.count) { _, _ in checkSubmittedTask() }
    }

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

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .subtitleRemove(let p) = item.params else { return }
        videoData = p.videoData
        videoName = p.videoName
        region = p.region
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
              case .subtitleRemove(let reg) = params
        else { return }
        region = reg
        errorMessage = nil
        resultVideoUrl = nil
        isTaskPending = false
        submittedTaskId = nil
    }

    private func pickVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            selectedVideoURL = url
            videoName = url.lastPathComponent
            isLoadingFile = true
            Task.detached(priority: .userInitiated) {
                let data = try? Data(contentsOf: url, options: .mappedIfSafe)
                await MainActor.run {
                    videoData = data
                    isLoadingFile = false
                    triggerPreflight()
                }
            }
        }
    }

    private func startGeneration() {
        guard let data = videoData, !data.isEmpty else {
            errorMessage = "请先选择视频文件"
            return
        }
        errorMessage = nil
        resultVideoUrl = nil

        let mime = videoMimeType(for: videoName)
        let params = SubtitleRemoveJobParams(videoData: data, videoName: videoName, videoMime: mime, region: region)
        let item = GenerationQueueItem(kind: .subtitleRemove, createdAt: Date(), params: .subtitleRemove(params))
        submittedTaskId = item.id
        isTaskPending = true
        queueStore.enqueue(item)
        editCoordinator.editingItem = nil
    }

    private func videoMimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"
        case "mkv": return "video/x-matroska"
        case "webm": return "video/webm"
        default: return "video/mp4"
        }
    }

    // MARK: - Presets

    private var presetRow: some View {
        let kind = PresetKind.subtitleRemove
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
                    guard case .subtitleRemove(let p) = preset.params else { return }
                    region = p.region
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
                let params = SubtitleRemovePresetParams(region: region)
                presetStore.save(name: name, params: .subtitleRemove(params))
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text("保存当前去字幕区域设置")
        }
    }

    // MARK: - Preflight

    private func triggerPreflight() {
        guard let data = videoData, !data.isEmpty else { preflight.reset(); return }
        let params = SubtitleRemoveJobParams(videoData: data, videoName: videoName, videoMime: videoMimeType(for: videoName), region: region)
        preflight.schedule(for: .subtitleRemove(params))
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
