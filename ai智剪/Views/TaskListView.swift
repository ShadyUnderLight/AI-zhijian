import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @State private var previewItem: TaskMediaPreviewItem?

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
                List {
                    if !queueStore.items.isEmpty {
                        Section("批量队列") {
                            ForEach(queueStore.items) { item in
                                queueItemRow(item)
                            }
                        }
                    }

                    if !nonQueueActiveTasks.isEmpty {
                        Section("活跃任务（单条提交）") {
                            ForEach(nonQueueActiveTasks) { task in
                                activeTaskRow(task)
                            }
                        }
                    }
                }
                .listStyle(.inset)
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

    private func queueItemRow(_ item: GenerationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: item.iconName)
                    .foregroundColor(.accentColor)
                Text(item.displayType)
                    .font(.headline)
                Spacer()
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
        .padding(.vertical, 4)
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
        .padding(.vertical, 4)
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
                                        RemoteImageResultView(urlString: url, maxHeight: 160)
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
                                        RemoteVideoResultView(urlString: url, height: 160, inlinePreview: false)
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
