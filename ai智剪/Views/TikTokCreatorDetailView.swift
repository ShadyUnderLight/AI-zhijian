import SwiftUI

struct TikTokCreatorDetailView: View {
    @EnvironmentObject var api: APIService

    let creator: TikTokCreator

    @State private var creatorTags: [TikTokTag]
    @State private var videos: [TikTokCreatorVideo] = []
    @State private var allTags: [TikTokTag] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showTagPicker = false

    init(creator: TikTokCreator) {
        self.creator = creator
        self._creatorTags = State(initialValue: creator.tags ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                creatorHeader(creator)

                Divider()

                // Info section
                infoSection(creator)

                Divider()

                // Tags section
                tagsSection

                Divider()

                // Videos section
                videosSection
            }
            .padding()
        }
        .navigationTitle(creator.nickname ?? "达人详情")
        .sheet(isPresented: $showTagPicker) {
            tagPickerSheet
        }
        .task {
            loadVideos()
        }
    }

    // MARK: - Header

    private func creatorHeader(_ creator: TikTokCreator) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 64, height: 64)
                .overlay {
                    Text(creator.nickname?.prefix(1).uppercased() ?? "?")
                        .font(.title)
                        .foregroundColor(.accentColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(creator.nickname ?? "未知")
                    .font(.title2)
                    .fontWeight(.bold)
                if let country = creator.country, !country.isEmpty {
                    Label(country, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let status = creator.status {
                    Text(status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Spacer()

            if let desc = creator.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 200, alignment: .trailing)
                    .lineLimit(4)
            }
        }
    }

    // MARK: - Info Section

    private func infoSection(_ creator: TikTokCreator) -> some View {
        HStack(spacing: 32) {
            if let followers = creator.followerCount {
                infoCard(value: "\(followers)", label: "粉丝")
            }
            if let following = creator.followingCount {
                infoCard(value: "\(following)", label: "关注")
            }
            if let videos = creator.videoCount {
                infoCard(value: "\(videos)", label: "视频")
            }
        }
    }

    private func infoCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("标签")
                    .font(.headline)
                Spacer()
                Button("添加标签") {
                    showTagPicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !creatorTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(creatorTags) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag.name)")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            } else {
                Text("暂无标签")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Videos Section

    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("视频列表")
                .font(.headline)

            if videos.isEmpty {
                Text("暂无视频数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300))], spacing: 12) {
                    ForEach(videos) { video in
                        VideoCard(video: video)
                    }
                }
            }
        }
    }

    // MARK: - Tag Picker Sheet

    private var tagPickerSheet: some View {
        VStack(spacing: 16) {
            Text("选择标签")
                .font(.headline)
            if allTags.isEmpty {
                Text("暂无可用标签，请先在标签管理创建")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                List(allTags) { tag in
                    Button {
                        addTag(tag)
                    } label: {
                        HStack {
                            Text("#\(tag.name)")
                            Spacer()
                            if creatorTags.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("关闭") {
                showTagPicker = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 280, height: 360)
        .task {
            // Load tags when sheet appears, not before (avoids race condition)
            guard allTags.isEmpty else { return }
            do {
                allTags = try await api.tiktokGetTags()
            } catch {
                // Silently fail — sheet will show empty state
            }
        }
    }

    // MARK: - Actions

    private func loadVideos() {
        Task {
            do {
                videos = try await api.tiktokGetCreatorVideos(creatorId: creator.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func addTag(_ tag: TikTokTag) {
        Task {
            do {
                try await api.tiktokTagCreator(creatorId: creator.id, tagId: tag.id)
                // Update local state immediately instead of reloading from server
                if !creatorTags.contains(tag) {
                    creatorTags.append(tag)
                }
                showTagPicker = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

}

// MARK: - Video Card

struct VideoCard: View {
    let video: TikTokCreatorVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Video thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    Image(systemName: "play.rectangle")
                        .font(.title)
                        .foregroundColor(.secondary)
                }

            if let title = video.title, !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if let playCount = video.playCount {
                    Label("\(playCount)", systemImage: "play")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let likeCount = video.likeCount {
                    Label("\(likeCount)", systemImage: "heart")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - FlowLayout (simple horizontal wrapping)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                height += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
            }
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        height += currentRowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var y: CGFloat = bounds.minY
        var currentX: CGFloat = bounds.minX
        var currentRowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > bounds.minX {
                y += currentRowHeight + spacing
                currentX = bounds.minX
                currentRowHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: y), proposal: .unspecified)
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
