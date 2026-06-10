import SwiftUI
import UniformTypeIdentifiers

// MARK: - 图片对口型

struct LipSyncImageView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var selectedImageURL: URL?
    @State private var imageData: Data?
    @State private var imageName = ""
    @State private var selectedAudioURL: URL?
    @State private var audioData: Data?
    @State private var audioName = ""
    @State private var accuracy = "high"
    @State private var isTaskPending = false
    @State private var submittedTaskId: String?
    @State private var errorMessage: String?
    @State private var resultVideoUrl: String?
    @State private var isLoadingImage = false
    @State private var isLoadingAudio = false
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?
    @StateObject private var preflight = GenerationPreflightService()

    private let accuracyOptions = ["high", "medium", "low"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 人物照片选择
                VStack(alignment: .leading, spacing: 6) {
                    Text("人物照片").font(.headline)
                    filePickerRow(
                        url: $selectedImageURL, data: $imageData, name: $imageName,
                        isLoading: $isLoadingImage, label: "选择照片",
                        types: [.image, .png, .jpeg]
                    )
                }

                // 音频选择
                VStack(alignment: .leading, spacing: 6) {
                    Text("音频文件").font(.headline)
                    filePickerRow(
                        url: $selectedAudioURL, data: $audioData, name: $audioName,
                        isLoading: $isLoadingAudio, label: "选择音频",
                        types: audioTypes()
                    )
                }

                // 精度选择
                VStack(alignment: .leading, spacing: 2) {
                    Text("对口型精度").font(.caption2).foregroundColor(.secondary)
                    Picker("", selection: $accuracy) {
                        ForEach(accuracyOptions, id: \.self) { option in
                            Text(optionLocalized(option)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                    .disabled(isTaskPending)
                }

                presetRow
                preflightBanner()

                HStack {
                    Button(action: startGeneration) {
                        if isTaskPending {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("队列中...")
                            }
                        } else {
                            Label("开始生成", systemImage: "mouth")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(imageData == nil || audioData == nil || isTaskPending || preflight.state.isBlocking)
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
        .onChange(of: imageData?.count) { _, _ in triggerPreflight() }
        .onChange(of: audioData?.count) { _, _ in triggerPreflight() }
        .onChange(of: accuracy) { _, _ in triggerPreflight() }
        .onChange(of: queueStore.items.count) { _, _ in checkSubmittedTask() }
    }

    // MARK: - Audio Types

    private func audioTypes() -> [UTType] {
        if let mp3 = UTType(filenameExtension: "mp3") {
            return [.audio, mp3]
        }
        return [.audio]
    }

    // MARK: - File Picker

    private func filePickerRow(url: Binding<URL?>, data: Binding<Data?>, name: Binding<String>,
                                isLoading: Binding<Bool>, label: String, types: [UTType]) -> some View {
        HStack {
            if let u = url.wrappedValue {
                Label(u.lastPathComponent, systemImage: "doc.fill")
                    .lineLimit(1).truncationMode(.middle)
            } else {
                Label("未选择文件", systemImage: "doc").foregroundColor(.secondary)
            }
            Spacer()
            if isLoading.wrappedValue {
                ProgressView().scaleEffect(0.6)
            }
            Button(label) { pickFile(url: url, data: data, name: name, isLoading: isLoading, types: types) }
                .buttonStyle(.bordered)
                .disabled(isLoading.wrappedValue || isTaskPending)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }

    private func pickFile(url: Binding<URL?>, data: Binding<Data?>, name: Binding<String>,
                           isLoading: Binding<Bool>, types: [UTType]) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let u = panel.url else { return }
            url.wrappedValue = u
            name.wrappedValue = u.lastPathComponent
            isLoading.wrappedValue = true
            Task.detached(priority: .userInitiated) {
                let fileData = try? Data(contentsOf: u, options: .mappedIfSafe)
                await MainActor.run {
                    data.wrappedValue = fileData
                    isLoading.wrappedValue = false
                    triggerPreflight()
                }
            }
        }
    }

    // MARK: - Actions

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
        guard case .lipSyncImage(let p) = item.params else { return }
        imageData = p.imageData
        imageName = p.imageName
        audioData = p.audioData
        audioName = p.audioName
        accuracy = p.accuracy
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
              case .lipSyncImage(let acc) = params
        else { return }
        accuracy = acc
        errorMessage = nil
        resultVideoUrl = nil
        isTaskPending = false
        submittedTaskId = nil
    }

    private func startGeneration() {
        guard let imgData = imageData, !imgData.isEmpty else {
            errorMessage = "请先选择人物照片"
            return
        }
        guard let audData = audioData, !audData.isEmpty else {
            errorMessage = "请先选择音频文件"
            return
        }
        errorMessage = nil
        resultVideoUrl = nil

        let imgMime = mimeType(for: imageName, defaultMime: "image/png")
        let audMime = mimeType(for: audioName, defaultMime: "audio/mpeg")
        let params = LipSyncImageJobParams(
            imageData: imgData, imageName: imageName, imageMime: imgMime,
            audioData: audData, audioName: audioName, audioMime: audMime,
            accuracy: accuracy
        )
        let item = GenerationQueueItem(kind: .lipSyncImage, createdAt: Date(), params: .lipSyncImage(params))
        submittedTaskId = item.id
        isTaskPending = true
        queueStore.enqueue(item)
        editCoordinator.editingItem = nil
    }

    private func mimeType(for filename: String, defaultMime: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"
        case "mkv": return "video/x-matroska"
        case "webm": return "video/webm"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aac": return "audio/aac"
        case "m4a": return "audio/mp4"
        case "flac": return "audio/flac"
        case "ogg": return "audio/ogg"
        default: return defaultMime
        }
    }

    // MARK: - Presets

    private var presetRow: some View {
        let kind = PresetKind.lipSyncImage
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
                    guard case .lipSyncImage(let p) = preset.params else { return }
                    accuracy = p.accuracy
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
                let params = LipSyncImagePresetParams(accuracy: accuracy)
                presetStore.save(name: name, params: .lipSyncImage(params))
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text("保存当前对口型精度设置")
        }
    }

    // MARK: - Preflight

    private func triggerPreflight() {
        guard imageData != nil, audioData != nil else { preflight.reset(); return }
        let params = LipSyncImageJobParams(
            imageData: imageData ?? Data(), imageName: imageName, imageMime: mimeType(for: imageName, defaultMime: "image/png"),
            audioData: audioData ?? Data(), audioName: audioName, audioMime: mimeType(for: audioName, defaultMime: "audio/mpeg"),
            accuracy: accuracy
        )
        preflight.schedule(for: .lipSyncImage(params))
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

    // MARK: - Helpers

    private func optionLocalized(_ option: String) -> String {
        switch option {
        case "high": return "高精度"
        case "medium": return "中等"
        case "low": return "低精度"
        default: return option
        }
    }
}
