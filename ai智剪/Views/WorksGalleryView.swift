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
    @State private var isSelecting = false
    @State private var selectedIds: Set<String> = []
    @State private var isBatchDownloading = false
    @State private var batchProgress: MediaDownloadService.BatchDownloadProgress?
    @State private var showExportMenu = false
    @State private var showEditSheet = false
    @State private var editingRecordId: String = ""

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

            if isSelecting {
                Divider()
                selectionToolbar
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
        .sheet(isPresented: $showEditSheet) {
            RecordEditSheetView(recordId: editingRecordId)
                .environmentObject(worksStore)
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
        .overlay {
            if isBatchDownloading {
                batchProgressOverlay
            }
        }
        .animation(.easeInOut(duration: 0.2), value: downloadMessage != nil)
        .animation(.easeInOut(duration: 0.2), value: isBatchDownloading)
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

            Toggle(isOn: $isSelecting) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(isSelecting ? .accentColor : .primary)
            }
            .toggleStyle(.button)
            .help("多选模式")
            .onChange(of: isSelecting) { _, newValue in
                if !newValue {
                    selectedIds.removeAll()
                }
            }

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

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        HStack(spacing: 16) {
            Button("全选") {
                let visibleIds = Set(filteredRecords.map(\.id))
                let allVisibleSelected = visibleIds.isSubset(of: selectedIds)
                if allVisibleSelected {
                    selectedIds.subtract(visibleIds)
                } else {
                    selectedIds.formUnion(visibleIds)
                }
            }
            .font(.caption)

            Text("已选 \(selectedIds.count) 项")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Menu {
                Button("批量下载选中") {
                    batchDownloadSelected()
                }
                .disabled(selectedIds.isEmpty)

                Divider()

                Button("导出选中为 CSV") {
                    exportSelected(format: .csv)
                }
                .disabled(selectedIds.isEmpty)

                Button("导出选中为 JSON") {
                    exportSelected(format: .json)
                }
                .disabled(selectedIds.isEmpty)

                Divider()

                Button("导出当前筛选为 CSV") {
                    exportAll(format: .csv)
                }

                Button("导出当前筛选为 JSON") {
                    exportAll(format: .json)
                }
            } label: {
                Label("操作", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button("取消选择") {
                isSelecting = false
                selectedIds.removeAll()
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Batch Progress Overlay

    private var batchProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("批量下载中...")
                    .font(.headline)

                if let progress = batchProgress {
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.title2)
                        .monospacedDigit()

                    if !progress.currentFile.isEmpty {
                        Text(progress.currentFile)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if let progress = batchProgress, !progress.errors.isEmpty {
                    Text("\(progress.errors.count) 个文件下载失败")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(32)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10)
        }
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

                ratingStars(for: record)

                HStack {
                    detailBadges(for: record)
                    Spacer()
                    Text(record.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if !record.tags.isEmpty {
                    tagChips(for: record)
                }

                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
        .overlay(alignment: .topTrailing) {
            if isSelecting {
                selectionCheckmark(for: record)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu { contextMenuContent(for: record) }
        .onTapGesture {
            if isSelecting {
                toggleSelection(for: record)
            } else {
                openPreview(for: record)
            }
        }
    }

    @ViewBuilder
    private func selectionCheckmark(for record: WorkRecord) -> some View {
        let isSelected = selectedIds.contains(record.id)
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background(Color(nsColor: .controlBackgroundColor).clipShape(Circle()))
            .padding(6)
    }

    private func toggleSelection(for record: WorkRecord) {
        if selectedIds.contains(record.id) {
            selectedIds.remove(record.id)
        } else {
            selectedIds.insert(record.id)
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

    private func ratingStars(for record: WorkRecord) -> some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: (record.rating ?? 0) >= star ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundColor(.yellow)
                    .onTapGesture {
                        let newRating = record.rating == star ? nil : star
                        worksStore.updateRating(record.id, rating: newRating)
                    }
            }
        }
    }

    private func tagChips(for record: WorkRecord) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(record.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
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

        Button("复用参数生成") {
            editCoordinator.applyRecord = record
            editCoordinator.navigateToKind = record.kind
        }

        Divider()

        Button("编辑信息") {
            editingRecordId = record.id
            showEditSheet = true
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
        } else if record.localImage != nil {
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

    // MARK: - Batch Operations

    private enum ExportFormat {
        case csv
        case json
    }

    private func batchDownloadSelected() {
        let selectedRecords = records.filter { selectedIds.contains($0.id) }
        guard !selectedRecords.isEmpty else { return }

        Task {
            guard let directory = MediaDownloadService.chooseDirectory() else { return }

            isBatchDownloading = true
            batchProgress = nil

            let progress = await MediaDownloadService.batchDownloadRecords(
                records: selectedRecords,
                toDirectory: directory
            ) { progress in
                Task { @MainActor in
                    self.batchProgress = progress
                }
            }

            isBatchDownloading = false

            if progress.total == 0 {
                downloadMessage = "没有可下载文件"
            } else if progress.errors.isEmpty {
                downloadMessage = "已下载 \(progress.completed) 个文件"
            } else {
                downloadMessage = "下载完成，\(progress.errors.count) 个失败"
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            downloadMessage = nil

            if progress.total > 0 {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
            }
        }
    }

    private func exportSelected(format: ExportFormat) {
        let selectedRecords = records.filter { selectedIds.contains($0.id) }
        guard !selectedRecords.isEmpty else { return }
        exportRecords(selectedRecords, format: format)
    }

    private func exportAll(format: ExportFormat) {
        exportRecords(filteredRecords, format: format)
    }

    private func exportRecords(_ records: [WorkRecord], format: ExportFormat) {
        let data: Data
        let filename: String

        switch format {
        case .csv:
            data = ExportService.exportCSV(records: records)
            filename = "AI智剪-导出-\(formattedDate()).csv"
        case .json:
            data = ExportService.exportJSON(records: records)
            filename = "AI智剪-导出-\(formattedDate()).json"
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = filename
        panel.title = "导出记录"
        panel.prompt = "导出"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
            downloadMessage = "已导出到 \(url.lastPathComponent)"
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        } catch {
            downloadMessage = "导出失败：\(error.localizedDescription)"
        }

        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            downloadMessage = nil
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

struct RecordEditSheetView: View {
    let recordId: String
    @EnvironmentObject var worksStore: WorksStore
    @Environment(\.dismiss) var dismiss

    @State private var rating: Int?
    @State private var notes: String = ""
    @State private var tagsText: String = ""

    private var record: WorkRecord? {
        worksStore.records.first(where: { $0.id == recordId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑作品信息")
                .font(.headline)

            if let record = record {
                Text(record.prompt.prefix(80))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text("评分")
                    .font(.callout)
                    .frame(width: 40, alignment: .leading)
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                rating = rating == star ? nil : star
                            }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("备注")
                    .font(.callout)
                TextEditor(text: $notes)
                    .font(.body)
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("标签（逗号分隔）")
                    .font(.callout)
                TextField("例如: 满意, 待修改, 发布版", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    worksStore.updateRating(recordId, rating: rating)
                    worksStore.updateNotes(recordId, notes: notes.isEmpty ? nil : notes)
                    let tags = tagsText
                        .components(separatedBy: CharacterSet(charactersIn: ",，"))
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    worksStore.updateTags(recordId, tags: tags)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            if let r = record {
                rating = r.rating
                notes = r.notes ?? ""
                tagsText = r.tags.joined(separator: ", ")
            }
        }
    }
}
