import SwiftUI
import AppKit

struct WorksGalleryView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var worksStore: WorksStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator

    @State private var filterKind: GenerationJobKind? = nil
    @State private var filterDate: DateFilter = .all
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @State private var previewItem: TaskMediaPreviewItem?
    @State private var isDownloading = false
    @State private var downloadMessage: String?

    enum DateFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case today = "今天"
        case week = "本周"
        case month = "本月"

        var id: Self { self }

        func includes(_ date: Date) -> Bool {
            let cal = Calendar.current
            switch self {
            case .all: return true
            case .today: return cal.isDateInToday(date)
            case .week: return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
            case .month: return cal.isDate(date, equalTo: Date(), toGranularity: .month)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()

            if filteredRecords.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredRecords) { record in
                            workCard(record)
                        }
                    }
                    .padding(16)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .navigationTitle("作品库")
        .sheet(item: $previewItem) { item in
            switch item.kind {
            case .image:
                RemoteImagePreviewSheet(url: item.url)
            case .video:
                RemoteVideoPreviewSheet(url: item.url)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let downloadMessage {
                Text(downloadMessage)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: downloadMessage != nil)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 180, maximum: 260))]
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("类型", selection: $filterKind) {
                Text("全部类型").tag(nil as GenerationJobKind?)
                ForEach(GenerationJobKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind as GenerationJobKind?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)
            .labelsHidden()

            Picker("日期", selection: $filterDate) {
                ForEach(DateFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .labelsHidden()

            TextField("搜索 Prompt...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)

            Toggle(isOn: $showFavoritesOnly) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
            .toggleStyle(.button)
            .help("仅显示收藏")

            Spacer()

            Text("\(filteredRecords.count) 条记录")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("作品库为空")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("完成生成任务后，结果会自动出现在这里")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Card

    private func workCard(_ record: WorkRecord) -> some View {
        VStack(spacing: 6) {
            thumbnail(for: record)
                .frame(height: 160)
                .clipped()

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: record.iconName)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    Text(record.displayType)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if worksStore.isFavorited(record.id) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }

                Text(record.prompt.prefix(60))
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    detailBadges(for: record)
                    Spacer()
                    Text(record.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu { contextMenuContent(for: record) }
        .onTapGesture {
            openPreview(for: record)
        }
    }

    @ViewBuilder
    private func thumbnail(for record: WorkRecord) -> some View {
        if !record.isSuccess {
            ZStack {
                Color(nsColor: .quaternarySystemFill)
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.red)
                    if let error = record.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                    }
                }
            }
        } else if record.isVideo, let videoUrl = record.videoUrl {
            RemoteVideoResultView(
                urlString: videoUrl,
                height: 160,
                inlinePreview: true,
                onPreview: { previewItem = TaskMediaPreviewItem(url: $0, kind: .video) }
            )
        } else if let localImage = record.localImage {
            Image(nsImage: localImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 160)
                .cornerRadius(8)
        } else if let firstUrl = record.resultUrls.first {
            RemoteImageResultView(
                urlString: firstUrl,
                maxHeight: 160,
                onPreview: { previewItem = TaskMediaPreviewItem(url: $0, kind: .image) }
            )
        } else {
            ZStack {
                Color(nsColor: .quaternarySystemFill)
                Image(systemName: record.iconName)
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func detailBadges(for record: WorkRecord) -> some View {
        let items = metadataItems(for: record)
        ForEach(items.prefix(2), id: \.self) { item in
            Text(item)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color(nsColor: .separatorColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private func metadataItems(for record: WorkRecord) -> [String] {
        var items: [String] = []
        let m = record.metadata
        if !m.aspectRatio.isEmpty && m.aspectRatio != "—" { items.append(m.aspectRatio) }
        if !m.resolution.isEmpty && m.resolution != "—" { items.append(m.resolution) }
        if !m.duration.isEmpty && m.duration != "—" { items.append(m.duration) }
        if !m.model.isEmpty && m.model != "—" { items.append(m.model) }
        if !m.channel.isEmpty && m.channel != "—" { items.append(m.channel) }
        return items
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent(for record: WorkRecord) -> some View {
        Button("预览") { openPreview(for: record) }

        Divider()

        Button("复制 Prompt") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(record.prompt, forType: .string)
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])

        if !record.isVideo, let firstUrl = record.resultUrls.first {
            Button("复制结果 URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(firstUrl, forType: .string)
            }
        }

        Button("下载") {
            downloadRecord(record)
        }

        Divider()

        Button("前往生成页") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(record.prompt, forType: .string)
            editCoordinator.navigateToKind = record.kind
        }

        Divider()

        Button(worksStore.isFavorited(record.id) ? "取消收藏" : "收藏") {
            worksStore.toggleFavorite(record.id)
        }

        Divider()

        Button("删除") {
            worksStore.deleteRecord(record.id)
        }
    }

    // MARK: - Actions

    private func openPreview(for record: WorkRecord) {
        if record.isVideo, let videoUrl = record.videoUrl, let url = ExternalURL.sanitizedURL(videoUrl) {
            previewItem = TaskMediaPreviewItem(url: url, kind: .video)
        } else if let localImage = record.localImage {
            previewLocalImage(record)
        } else if let firstUrl = record.resultUrls.first, let url = ExternalURL.sanitizedURL(firstUrl) {
            previewItem = TaskMediaPreviewItem(url: url, kind: .image)
        }
    }

    private func previewLocalImage(_ record: WorkRecord) {
        guard let path = record.localImagePath else { return }
        let url = URL(fileURLWithPath: path)
        previewItem = TaskMediaPreviewItem(url: url, kind: .image)
    }

    private func downloadRecord(_ record: WorkRecord) {
        if let path = record.localImagePath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            downloadLocal(data: data, suggestedFilename: "banana-result.png")
            return
        }
        let urls: [URL] = record.resultUrls.compactMap { ExternalURL.sanitizedURL($0) }
        if let videoUrl = record.videoUrl, let url = ExternalURL.sanitizedURL(videoUrl) {
            download(url: url, isVideo: true)
            return
        }
        if let firstUrl = urls.first {
            download(url: firstUrl, isVideo: false)
        }
    }

    private func downloadLocal(data: Data, suggestedFilename: String) {
        isDownloading = true
        downloadMessage = nil
        Task {
            do {
                if let savedURL = try await MediaDownloadService.save(data: data, suggestedFilename: suggestedFilename) {
                    downloadMessage = "已保存到 \(savedURL.lastPathComponent)"
                }
            } catch {
                downloadMessage = "下载失败：\(error.localizedDescription)"
            }
            isDownloading = false
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            downloadMessage = nil
        }
    }

    private func download(url: URL, isVideo: Bool) {
        isDownloading = true
        downloadMessage = nil
        let kind: MediaDownloadService.MediaKind = isVideo ? .video : .image
        let fallback = isVideo ? "video.mp4" : "image.png"
        Task {
            do {
                if let savedURL = try await MediaDownloadService.download(
                    from: url,
                    suggestedFilename: MediaDownloadService.suggestedFilename(for: url, fallback: fallback),
                    kind: kind
                ) {
                    downloadMessage = "已保存到 \(savedURL.lastPathComponent)"
                }
            } catch {
                downloadMessage = "下载失败：\(error.localizedDescription)"
            }
            isDownloading = false
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            downloadMessage = nil
        }
    }

    // MARK: - Filtering

    private var filteredRecords: [WorkRecord] {
        records
            .filter { record in
                if showFavoritesOnly && !worksStore.isFavorited(record.id) { return false }
                if let kind = filterKind, record.kind != kind { return false }
                if !filterDate.includes(record.createdAt) { return false }
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return record.prompt.localizedCaseInsensitiveContains(searchText)
                }
                return true
            }
            .sorted { a, b in
                (a.completedAt ?? a.createdAt) > (b.completedAt ?? b.createdAt)
            }
    }

    private var records: [WorkRecord] { worksStore.records }
}
