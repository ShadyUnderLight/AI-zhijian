import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @State private var previewItem: TaskMediaPreviewItem?
    @State private var selectedTaskId: String?

    private var selectedTaskBinding: Binding<Bool> {
        Binding(
            get: { selectedTaskId != nil },
            set: { if !$0 { selectedTaskId = nil } }
        )
    }

    private var nonQueueActiveTasks: [ActiveTask] {
        let queueItemIds = Set(queueStore.items.map { $0.id })
        return api.activeTasks.filter { !queueItemIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            statsBar
            Divider()

            if queueStore.items.isEmpty && nonQueueActiveTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("队列为空")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("在图片生成页切换到批量模式，添加多条提示词到队列")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if !queueStore.items.isEmpty {
                            taskSection("批量队列") {
                                ForEach(queueStore.items) { item in
                                    queueItemRow(item)
                                }
                            }
                        }

                        if !nonQueueActiveTasks.isEmpty {
                            taskSection("活跃任务（单条提交）") {
                                ForEach(nonQueueActiveTasks) { task in
                                    activeTaskRow(task)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .navigationTitle("任务队列")
        .toolbar {
            ToolbarItem {
                if queueStore.isPaused {
                    Button("继续") { queueStore.resumeQueue() }
                } else if !queueStore.items.isEmpty {
                    Button("暂停") { queueStore.pauseQueue() }
                }
            }
        }
        .sheet(item: $previewItem) { item in
            switch item.kind {
            case .image:
                RemoteImagePreviewSheet(url: item.url)
            case .video:
                RemoteVideoPreviewSheet(url: item.url)
            }
        }
        .inspector(isPresented: selectedTaskBinding) {
            if let id = selectedTaskId {
                TaskDetailPanel(taskId: id)
                    .environmentObject(queueStore)
            }
        }
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            statBadge(label: "待提交", count: queueStore.pendingCount, color: .secondary)
            statBadge(label: "提交中", count: queueStore.submittingCount, color: .blue)
            statBadge(label: "轮询中", count: queueStore.pollingCount, color: .orange)
            statBadge(label: "完成", count: queueStore.succeededCount, color: .green)
            statBadge(label: "失败", count: queueStore.failedCount, color: .red)

            Spacer()

            if queueStore.succeededCount > 0 || queueStore.failedCount > 0 {
                Button("清除已完成") {
                    queueStore.clearAllCompleted()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .font(.caption)
            }

            HStack(spacing: 2) {
                Picker("并发", selection: $queueStore.concurrencyLimit) {
                    ForEach(1...5, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 42)
                .labelsHidden()
                .accessibilityLabel("并发数")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func statBadge(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(.title3, design: .monospaced))
                .foregroundColor(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func taskSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            LazyVStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func queueItemRow(_ item: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: item.iconName)
                    .foregroundColor(.accentColor)
                Text(item.displayType)
                    .font(.headline)
                Spacer()
                detailButton(item)
                statusBadge(item.status)
            }

            Text(item.summary.prefix(80))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                if let taskId = item.taskId {
                    Text("ID: \(String(taskId.prefix(16)))...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let price = item.priceUsd, !price.isEmpty {
                    Text(price)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                Text(item.elapsed)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                if item.retryCount > 0 {
                    Text("重试\(item.retryCount)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            if item.status == .polling, item.consecutivePollFailures > 0, let lastErr = item.lastPollError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("轮询异常(\(item.consecutivePollFailures)/\(queueStore.maxConsecutivePollFailures)): \(lastErr)")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                        .lineLimit(2)
                }
            }

            // Result URLs (images)
            if item.status == .succeeded, !item.resultUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(item.resultUrls, id: \.self) { url in
                            RemoteImageResultView(
                                urlString: url,
                                maxHeight: 120,
                                onPreview: { previewItem = TaskMediaPreviewItem(url: $0, kind: .image) }
                            )
                        }
                    }
                }
                .frame(minHeight: 158, alignment: .top)
            }

            // Banana result image
            if item.status == .succeeded, item.kind == .banana, let imageData = item.bananaResultImageData, let nsImage = NSImage(data: imageData) {
                LocalImageResultView(
                    image: nsImage,
                    data: imageData,
                    suggestedFilename: "banana-result.png",
                    maxHeight: 200
                )
            }

            // Video result URL
            if item.status == .succeeded, let videoUrl = item.videoUrl {
                RemoteVideoResultView(
                    urlString: videoUrl,
                    height: 180,
                    inlinePreview: false,
                    onPreview: { previewItem = TaskMediaPreviewItem(url: $0, kind: .video) }
                )
            }

            // Error message
            if item.status == .failed, let error = item.errorMessage {
                HStack {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                    if !item.restoredFromPersistence {
                        Button("编辑") {
                            editCoordinator.editingItem = item
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.caption)
                    }
                    Button("重试") {
                        queueStore.retryFailedItem(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption)
                }
            }

            // Cancel button for pending items
            if item.status == .pending {
                HStack {
                    Spacer()
                    Button("取消") {
                        queueStore.cancelPendingItem(item.id)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .taskRowStyle()
    }

    @ViewBuilder
    private func detailButton(_ item: GenerationQueueItem) -> some View {
        Button {
            selectedTaskId = item.id
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
        .help("查看详情")
    }

    private func activeTaskRow(_ task: ActiveTask) -> some View {
        HStack {
            Image(systemName: task.type.contains("Image") || task.type.contains("Banana") ? "photo" : "video")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.type).font(.headline)
                Text(task.desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("进行中").font(.caption).foregroundColor(.orange)
                Text(task.elapsed).font(.caption2).foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .taskRowStyle()
    }

    private func statusBadge(_ status: GenerationQueueStatus) -> some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .cornerRadius(4)
    }

    private func statusColor(_ status: GenerationQueueStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .submitting: return .blue
        case .polling: return .orange
        case .succeeded: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

private extension View {
    func taskRowStyle() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
    }
}

private struct TaskMediaPreviewItem: Identifiable {
    enum Kind {
        case image
        case video
    }

    let id = UUID()
    let url: URL
    let kind: Kind
}

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var api: APIService

    @State private var imageHistory: [HistoryItem] = []
    @State private var videoHistory: [HistoryItem] = []
    @State private var isLoading = false
    @State private var previewItem: TaskMediaPreviewItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image history
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("GPT-Image-2 历史").font(.title3)
                        Spacer()
                        if !imageHistory.isEmpty {
                            Text("\(imageHistory.count) 条").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    if imageHistory.isEmpty {
                        Text("暂无记录").font(.caption).foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220))], spacing: 10) {
                            ForEach(imageHistory.filter { $0.resultUrl != nil }) { item in
                                VStack(spacing: 4) {
                                    if let url = item.resultUrl {
                                        RemoteImageResultView(
                                            urlString: url,
                                            maxHeight: 160,
                                            onPreview: { previewItem = TaskMediaPreviewItem(url: $0, kind: .image) }
                                        )
                                    }
                                    Text(item.prompt?.prefix(20) ?? "")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // Video history
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Seedance 视频历史").font(.title3)
                        Spacer()
                        if !videoHistory.isEmpty {
                            Text("\(videoHistory.count) 条").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    if videoHistory.isEmpty {
                        Text("暂无记录").font(.caption).foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220))], spacing: 10) {
                            ForEach(videoHistory.filter { $0.videoUrl != nil }) { item in
                                VStack(spacing: 4) {
                                    if let url = item.videoUrl {
                                        RemoteVideoResultView(
                                            urlString: url,
                                            height: 160,
                                            inlinePreview: false,
                                            onPreview: { previewItem = TaskMediaPreviewItem(url: $0, kind: .video) }
                                        )
                                    }
                                    Text(item.prompt?.prefix(20) ?? "")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear { loadHistory() }
        .toolbar {
            ToolbarItem {
                Button("刷新") { loadHistory() }
                    .disabled(isLoading)
            }
        }
        .sheet(item: $previewItem) { item in
            switch item.kind {
            case .image:
                RemoteImagePreviewSheet(url: item.url)
            case .video:
                RemoteVideoPreviewSheet(url: item.url)
            }
        }
    }
    
    private func loadHistory() {
        isLoading = true
        Task {
            async let imgResult = try? api.getImageHistory()
            async let vidResult = try? api.getSeedanceHistory()
            let (img, vid) = await (imgResult, vidResult)
            imageHistory = img?.data ?? []
            videoHistory = vid?.data ?? []
            isLoading = false
        }
    }

    private func externalURL(_ rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        return ExternalURL.sanitizedURL(rawValue)
    }
}

// MARK: - Task Detail Panel

private struct TaskDetailPanel: View {
    let taskId: String
    @EnvironmentObject var queueStore: GenerationQueueStore

    private var task: GenerationQueueItem? {
        queueStore.items.first { $0.id == taskId }
    }

    @State private var promptCopied = false
    @State private var errorCopied = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        if let task {
            content(task: task)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 30))
                    .foregroundColor(.secondary)
                Text("任务已移除")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func content(task: GenerationQueueItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection(task: task)
                Divider()
                promptSection(task: task)
                Divider()
                parameterSection(task: task)
                Divider()
                timelineSection(task: task)
                if task.status == .succeeded {
                    Divider()
                    resultSection(task: task)
                }
                if task.status == .failed, let _ = task.errorMessage {
                    Divider()
                    errorSection(task: task)
                }
                if task.status == .polling && task.consecutivePollFailures > 0 {
                    Divider()
                    pollingWarningSection(task: task)
                }
                Divider()
                actionSection(task: task)
            }
            .padding(16)
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
    }

    // MARK: - Header

    private func headerSection(task: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: task.iconName)
                    .foregroundColor(.accentColor)
                Text(task.displayType)
                    .font(.headline)
                Spacer()
                statusBadge(task.status)
            }

            if let taskId = task.taskId {
                Text("ID: \(taskId)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let price = task.priceUsd, !price.isEmpty {
                Text(price)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func statusBadge(_ status: GenerationQueueStatus) -> some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .cornerRadius(4)
    }

    private func statusColor(_ status: GenerationQueueStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .submitting: return .blue
        case .polling: return .orange
        case .succeeded: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }

    // MARK: - Prompt

    private func promptSection(task: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Prompt")
            Text(task.summary)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
            copyButton(text: task.summary, copied: $promptCopied, label: "复制 Prompt")
        }
    }

    // MARK: - Parameters

    private func parameterSection(task: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("参数")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                ForEach(task.parameterFields, id: \.0) { key, value in
                    GridRow {
                        Text(key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(value)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(3)
                            .truncationMode(.tail)
                    }
                }
            }
        }
    }

    // MARK: - Timeline

    private func timelineSection(task: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("时间线")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("创建")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dateFormatter.string(from: task.createdAt))
                        .font(.caption)
                        .monospacedDigit()
                }
                GridRow {
                    Text("提交")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(task.startedAt.map { dateFormatter.string(from: $0) } ?? "-")
                        .font(.caption)
                        .monospacedDigit()
                }
                GridRow {
                    Text("完成")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(task.completedAt.map { dateFormatter.string(from: $0) } ?? "-")
                        .font(.caption)
                        .monospacedDigit()
                }
                GridRow {
                    Text("耗时")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(task.elapsed)
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Results

    private func resultSection(task: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("结果")

            if !task.resultUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(task.resultUrls, id: \.self) { url in
                            RemoteImageResultView(
                                urlString: url,
                                maxHeight: 160
                            )
                        }
                    }
                }
                .frame(minHeight: 200, alignment: .top)
            }

            if task.kind == .banana, let imageData = task.bananaResultImageData, let nsImage = NSImage(data: imageData) {
                LocalImageResultView(
                    image: nsImage,
                    data: imageData,
                    suggestedFilename: "banana-result.png",
                    maxHeight: 200
                )
            }

            if let videoUrl = task.videoUrl {
                RemoteVideoResultView(
                    urlString: videoUrl,
                    height: 160,
                    inlinePreview: false
                )
            }
        }
    }

    // MARK: - Error

    private func errorSection(task: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("错误信息")
            Text(task.errorMessage ?? "")
                .font(.caption)
                .foregroundColor(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.red.opacity(0.05))
                .cornerRadius(6)
            if let errMsg = task.errorMessage {
                copyButton(text: errMsg, copied: $errorCopied, label: "复制错误")
            }
        }
    }

    // MARK: - Polling Warning

    private func pollingWarningSection(task: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("轮询状态")
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("轮询异常 (\(task.consecutivePollFailures)/\(queueStore.maxConsecutivePollFailures))")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
            if let lastErr = task.lastPollError {
                Text(lastErr)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func actionSection(task: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("操作")

            HStack(spacing: 8) {
                if task.status == .failed {
                    Button("重试") {
                        queueStore.retryFailedItem(task.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if task.status == .pending {
                    Button("取消") {
                        queueStore.cancelPendingItem(task.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    private func copyButton(text: String, copied: Binding<Bool>, label: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied.wrappedValue = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied.wrappedValue = false
            }
        } label: {
            Label(copied.wrappedValue ? "已复制" : label, systemImage: copied.wrappedValue ? "checkmark" : "doc.on.doc")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// MARK: - Parameter Fields

private extension GenerationQueueItem {
    var parameterFields: [(String, String)] {
        switch params {
        case .gptImage(let p):
            return [
                ("渠道", p.channel),
                ("比例", p.aspectRatio),
                ("分辨率", p.resolution),
                ("质量", p.quality),
                ("照片级", p.photoReal ? "是" : "否"),
            ]
        case .banana(let p):
            return [("提供商", p.provider)]
        case .seedance(let p):
            return [
                ("模式", p.mode),
                ("模型", p.model),
                ("比例", p.ratio),
                ("分辨率", p.resolution),
                ("时长", "\(p.duration)s"),
                ("生成数量", "\(p.count)"),
                ("生成音频", p.generateAudio ? "是" : "否"),
            ]
        case .wan(let p):
            return [
                ("模式", p.mode == "image" ? "图片转视频" : "首尾帧"),
                ("尺寸", "\(p.width)×\(p.height)"),
                ("时长", "\(p.seconds)s"),
            ]
        case .veo(let p):
            var fields: [(String, String)] = [
                ("渠道", p.channel),
                ("模型", p.model),
                ("模式", p.mode),
                ("比例", p.aspectRatio),
                ("分辨率", p.resolution),
                ("时长", "\(p.duration)s"),
                ("生成音频", p.generateAudio ? "是" : "否"),
            ]
            if let neg = p.negativePrompt, !neg.isEmpty {
                fields.append(("负面提示词", neg))
            }
            return fields
        case .grok(let p):
            return [
                ("渠道", p.channel),
                ("模式", p.mode),
                ("比例", p.aspectRatio),
                ("分辨率", p.resolution),
                ("时长", "\(p.duration)s"),
            ]
        }
    }
}
