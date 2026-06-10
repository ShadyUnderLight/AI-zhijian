import SwiftUI
import AVKit
import UniformTypeIdentifiers

// MARK: - Health Action 科普 Workflow View

struct HealthActionWorkflowView: View {
    @EnvironmentObject var api: APIService

    // MARK: - State

    @State private var chineseText = ""
    @State private var modelImageData: Data?; @State private var modelImageURL: URL?; @State private var modelImageName = ""
    @State private var referenceVideoData: Data?; @State private var referenceVideoURL: URL?; @State private var referenceVideoName = ""
    @State private var referenceFrameData: Data?; @State private var referenceFrameURL: URL?; @State private var referenceFrameName = ""
    @State private var isStarted = false
    @State private var isStarting = false
    @State private var branchATaskId: String?
    @State private var branchBTaskId: String?
    @State private var branchAStatus = "等待中"
    @State private var branchBStatus = "等待中"
    @State private var branchAProgress: Double = 0
    @State private var branchBProgress: Double = 0
    @State private var modelReferenceUrl: String?
    @State private var isReviewing = false
    @State private var isRegenerating = false
    @State private var isConfirming = false
    @State private var finalVideoUrl: String?
    @State private var finalVideoTaskId: String?
    @State private var errorMessage: String?

    @State private var isLoadingModelImage = false
    @State private var isLoadingRefVideo = false
    @State private var isLoadingRefFrame = false
    @State private var player: AVPlayer?
    @State private var isPolling = false
    @State private var showResetConfirm = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !isStarted {
                    inputForm
                } else {
                    workflowProgress
                }
            }
            .padding(24)
        }
        .frame(minWidth: 620, minHeight: 480)
        .onDisappear { player?.pause() }
        .alert("错误", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("确认重置", isPresented: $showResetConfirm) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) { resetWorkflow() }
        } message: {
            Text("重置将清空当前进度，确定重新开始？")
        }
    }

    // MARK: - Input Form

    private var inputForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("健康动作科普视频").font(.title2).bold()
            Text("输入动作描述，上传模型形象图，可选参考视频/帧，生成专业健康科普视频。")
                .font(.caption).foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("动作描述").font(.headline)
                TextEditor(text: $chineseText)
                    .font(.body)
                    .frame(minHeight: 90, maxHeight: 140)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    .overlay(alignment: .topLeading) {
                        if chineseText.isEmpty {
                            Text("例如：肩颈放松操，站立双脚与肩同宽，缓慢转动头部...")
                                .font(.body).foregroundColor(.secondary).padding(12).allowsHitTesting(false)
                        }
                    }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("模型形象图").font(.headline)
                Text("人物形象照片，用于生成讲解视频").font(.caption).foregroundColor(.secondary)
                filePickerRow(url: $modelImageURL, data: $modelImageData, name: $modelImageName,
                              isLoading: $isLoadingModelImage, label: "选择图片", types: [.image, .png, .jpeg])
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("参考视频（可选）").font(.headline)
                Text("动作参考视频，帮助 AI 理解动作").font(.caption).foregroundColor(.secondary)
                filePickerRow(url: $referenceVideoURL, data: $referenceVideoData, name: $referenceVideoName,
                              isLoading: $isLoadingRefVideo, label: "选择视频", types: [.movie, .mpeg4Movie, .quickTimeMovie])
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("参考帧（可选）").font(.headline)
                Text("动作参考截图，辅助姿态对齐").font(.caption).foregroundColor(.secondary)
                filePickerRow(url: $referenceFrameURL, data: $referenceFrameData, name: $referenceFrameName,
                              isLoading: $isLoadingRefFrame, label: "选择图片", types: [.image, .png, .jpeg])
            }

            Divider()

            if let err = errorMessage {
                Text(err).foregroundColor(.red).font(.caption)
            }

            HStack(spacing: 12) {
                Button(action: startWorkflow) {
                    if isStarting {
                        HStack { ProgressView().scaleEffect(0.8); Text("提交中...") }
                    } else {
                        Label("开始生成", systemImage: "play.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStarting || chineseText.isEmpty || modelImageData == nil)

                if isStarted {
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        Label("重置", systemImage: "arrow.counterclockwise")
                    }.buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Workflow Progress

    private var workflowProgress: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("生成进度").font(.title2).bold()
                Spacer()
                if isPolling { ProgressView().scaleEffect(0.7) }
                Button("重置") { showResetConfirm = true }.buttonStyle(.bordered).controlSize(.small)
            }
            Divider()

            branchStatusCard(title: "讲解视频（Branch A）", icon: "person.wave.2",
                             status: branchAStatus, progress: branchAProgress)
            branchStatusCard(title: "模型参考图（Branch B）", icon: "photo",
                             status: branchBStatus, progress: branchBProgress)

            if isReviewing, let imageUrl = modelReferenceUrl, let url = URL(string: imageUrl) {
                Divider()
                modelReferenceReviewSection(url: url)
            }

            if let finalUrl = finalVideoUrl, let url = URL(string: finalUrl) {
                Divider()
                finalVideoPreviewSection(url: url)
            }

            if let err = errorMessage {
                Text(err).foregroundColor(.red).font(.caption)
            }
        }
    }

    private func branchStatusCard(title: String, icon: String, status: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.title3).foregroundColor(statusColor(status))
                Text(title).font(.subheadline)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(statusColor(status)).frame(width: 8, height: 8)
                    Text(statusDisplay(status)).font(.caption).foregroundColor(statusColor(status))
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(statusColor(status).opacity(0.1)).cornerRadius(4)
            }
            if progress > 0 && progress < 1 {
                ProgressView(value: progress, total: 1).progressViewStyle(.linear).frame(maxWidth: 300)
            }
            Text(statusDesc(status)).font(.caption).foregroundColor(.secondary)
        }
        .padding(12).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
    }

    private func statusDisplay(_ s: String) -> String { statusMap[s]?.0 ?? s }
    private func statusDesc(_ s: String) -> String { statusMap[s]?.1 ?? s }
    private func statusColor(_ s: String) -> Color {
        switch s { case "completed","完成": .green; case "failed","失败": .red
        case "processing","处理中","regenerating","重新生成","confirming","确认中": .orange
        default: .secondary }
    }
    private let statusMap: [String: (String, String)] = [
        "pending": ("等待中", "任务已提交，等待调度..."),
        "等待中": ("等待中", "任务已提交，等待调度..."),
        "processing": ("处理中", "AI 正在处理，请稍候..."),
        "处理中": ("处理中", "AI 正在处理，请稍候..."),
        "completed": ("已完成", "任务已完成"),
        "完成": ("已完成", "任务已完成"),
        "failed": ("失败", "任务执行失败，请重试"),
        "失败": ("失败", "任务执行失败，请重试"),
        "regenerating": ("重新生成", "正在重新生成模型参考图..."),
        "重新生成": ("重新生成", "正在重新生成模型参考图..."),
        "confirming": ("确认中", "正在生成最终动作视频..."),
        "确认中": ("确认中", "正在生成最终动作视频..."),
    ]

    // MARK: - Model Reference Review

    private func modelReferenceReviewSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模型参考图预览").font(.headline)
            Text("确认 AI 生成的模型参考图是否符合预期，确认后将进入最终视频合成。")
                .font(.caption).foregroundColor(.secondary)

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 300).cornerRadius(8)
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark").font(.largeTitle).foregroundColor(.secondary)
                        Text("图片加载失败").font(.caption).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 160)
                    .background(Color(nsColor: .controlBackgroundColor)).cornerRadius(8)
                case .empty:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                @unknown default: EmptyView()
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

            HStack(spacing: 12) {
                Button(action: confirmModelReference) {
                    if isConfirming {
                        HStack { ProgressView().scaleEffect(0.7); Text("确认中...") }
                    } else { Label("确认", systemImage: "checkmark.circle") }
                }
                .buttonStyle(.borderedProminent).disabled(isConfirming || isRegenerating)

                Button(action: regenerateModelReference) {
                    if isRegenerating {
                        HStack { ProgressView().scaleEffect(0.7); Text("重新生成...") }
                    } else { Label("重新生成", systemImage: "arrow.triangle.2.circlepath") }
                }
                .buttonStyle(.bordered).disabled(isConfirming || isRegenerating)

                Button(role: .destructive) { rejectModelReference() } label: {
                    Label("拒绝，重新开始", systemImage: "xmark.circle")
                }.buttonStyle(.bordered).disabled(isConfirming || isRegenerating)
            }
        }
    }

    // MARK: - Final Video Preview

    private func finalVideoPreviewSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最终视频预览").font(.headline)
            AppKitVideoPlayerView(player: player)
                .frame(minHeight: 260).cornerRadius(8)
                .onAppear { if player == nil { player = AVPlayer(url: url) } }
                .onDisappear { player?.pause() }

            HStack(spacing: 12) {
                Button(action: { player?.seek(to: .zero); player?.play() }) {
                    Label("播放", systemImage: "play.circle")
                }.buttonStyle(.bordered)

                Button(action: exportVideo) {
                    Label("导出视频", systemImage: "square.and.arrow.up")
                }.buttonStyle(.borderedProminent)

                Spacer()
                Button("重新开始") { showResetConfirm = true }.buttonStyle(.bordered)
            }
        }
    }

    // MARK: - File Picker Row

    private func filePickerRow(url: Binding<URL?>, data: Binding<Data?>, name: Binding<String>,
                                isLoading: Binding<Bool>, label: String, types: [UTType]) -> some View {
        HStack {
            if let u = url.wrappedValue {
                Label(u.lastPathComponent, systemImage: "doc.fill").lineLimit(1).truncationMode(.middle)
            } else {
                Label("未选择文件", systemImage: "doc").foregroundColor(.secondary)
            }
            Spacer()
            if isLoading.wrappedValue { ProgressView().scaleEffect(0.6) }
            Button(label) { pickFile(url: url, data: data, name: name, isLoading: isLoading, types: types) }
                .buttonStyle(.bordered).disabled(isLoading.wrappedValue || isStarting)
        }
        .padding(10).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }

    // MARK: - Actions

    private func startWorkflow() {
        guard let imageData = modelImageData, !chineseText.isEmpty else { return }
        isStarting = true
        errorMessage = nil
        Task {
            do {
                let mime = mimeType(for: modelImageURL)
                let result = try await api.startHealthActionWorkflow(
                    chineseText: chineseText, modelImageData: imageData,
                    modelImageName: modelImageName, modelImageMime: mime,
                    referenceVideoData: referenceVideoData,
                    referenceVideoName: referenceVideoName.isEmpty ? nil : referenceVideoName,
                    referenceVideoMime: referenceVideoURL.flatMap { mimeType(for: $0) },
                    referenceFrameData: referenceFrameData,
                    referenceFrameName: referenceFrameName.isEmpty ? nil : referenceFrameName,
                    referenceFrameMime: referenceFrameURL.flatMap { mimeType(for: $0) }
                )
                if result.success {
                    branchATaskId = result.taskId
                    branchBTaskId = result.modelReferenceTaskId
                    branchAStatus = "处理中"
                    branchBStatus = "处理中"
                    isStarted = true
                    startPolling()
                } else {
                    errorMessage = result.message ?? "启动工作流失败"
                }
            } catch {
                errorMessage = "启动失败: \(error.localizedDescription)"
            }
            isStarting = false
        }
    }

    private func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        Task {
            while isPolling {
                do {
                    try await pollTask(branchATaskId, where: branchAStatus != "完成" && branchAStatus != "失败") { s in
                        branchAStatus = s.status ?? branchAStatus; branchAProgress = s.progress ?? branchAProgress
                    }
                    try await pollTask(branchBTaskId, where: branchBStatus != "完成" && branchBStatus != "失败") { s in
                        branchBStatus = s.status ?? branchBStatus; branchBProgress = s.progress ?? branchBProgress
                        if let img = s.imageUrl { modelReferenceUrl = img }
                    }
                    if ["完成", "completed"].contains(branchBStatus) { isReviewing = true }
                    if let tid = finalVideoTaskId {
                        try await pollTask(tid) { s in
                            if let v = s.videoUrl, let url = URL(string: v) { finalVideoUrl = v; player = AVPlayer(url: url) }
                            if ["完成", "completed", "失败", "failed"].contains(s.status) { finalVideoTaskId = nil }
                        }
                    }
                    let terminal: Set<String> = ["完成", "completed", "失败", "failed"]
                    if terminal.contains(branchAStatus) && terminal.contains(branchBStatus)
                        && finalVideoTaskId == nil && !isReviewing && finalVideoUrl == nil { isPolling = false }
                } catch { /* ignore */ }
                if isPolling { try? await Task.sleep(nanoseconds: 2_000_000_000) }
            }
        }
    }

    private func pollTask(_ taskId: String?, where condition: Bool = true, update: (HealthActionTaskStatusResponse) -> Void) async throws {
        guard let taskId, condition else { return }
        let s = try await api.queryHealthActionTaskStatus(taskId: taskId)
        if s.success { update(s) }
    }

    private func confirmModelReference() {
        isConfirming = true
        errorMessage = nil
        Task {
            do {
                let result = try await api.confirmHealthActionVideo()
                if result.success, let videoTaskId = result.videoTaskId {
                    finalVideoTaskId = videoTaskId
                    branchAStatus = "确认中"
                    if !isPolling { startPolling() }
                } else {
                    errorMessage = result.message ?? "确认失败"
                }
            } catch { errorMessage = "确认失败: \(error.localizedDescription)" }
            isConfirming = false
        }
    }

    private func regenerateModelReference() {
        isRegenerating = true
        errorMessage = nil
        isReviewing = false
        Task {
            do {
                let result = try await api.regenerateHealthActionModelReference()
                if result.success, let retryTaskId = result.retryTaskId {
                    branchBTaskId = retryTaskId; branchBStatus = "重新生成"; modelReferenceUrl = nil
                    if !isPolling { startPolling() }
                } else { errorMessage = result.message ?? "重新生成失败"; isReviewing = true }
            } catch { errorMessage = "重新生成失败: \(error.localizedDescription)"; isReviewing = true }
            isRegenerating = false
        }
    }

    private func rejectModelReference() {
        errorMessage = nil; isReviewing = false; branchBStatus = "失败"
        resetWorkflow()
    }

    private func resetWorkflow() {
        isStarted = false; isStarting = false; isPolling = false
        branchATaskId = nil; branchBTaskId = nil
        branchAStatus = "等待中"; branchBStatus = "等待中"
        branchAProgress = 0; branchBProgress = 0
        modelReferenceUrl = nil; isReviewing = false
        isRegenerating = false; isConfirming = false
        finalVideoUrl = nil; finalVideoTaskId = nil
        player?.pause(); player = nil
        errorMessage = nil; showResetConfirm = false
    }

    private func exportVideo() {
        guard let urlString = finalVideoUrl, let url = URL(string: urlString) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "健康科普-\(df.string(from: Date())).mp4"
        panel.begin { response in
            if response == .OK, let dest = panel.url {
                Task {
                    do { try Data(contentsOf: url).write(to: dest) }
                    catch { errorMessage = "导出失败: \(error.localizedDescription)" }
                }
            }
        }
    }

    // MARK: - File Picker

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
            Task {
                do {
                    let d = try Data(contentsOf: u)
                    await MainActor.run { data.wrappedValue = d }
                } catch {
                    await MainActor.run { errorMessage = "读取文件失败: \(error.localizedDescription)" }
                }
                await MainActor.run { isLoading.wrappedValue = false }
            }
        }
    }

    // MARK: - Helpers

    private func mimeType(for fileURL: URL?) -> String {
        guard let url = fileURL else { return "application/octet-stream" }
        if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
           let mime = UTType(uti)?.preferredMIMEType { return mime }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        default: return "application/octet-stream"
        }
    }
}
