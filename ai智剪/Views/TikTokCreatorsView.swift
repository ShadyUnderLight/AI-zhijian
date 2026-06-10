import SwiftUI

struct TikTokCreatorsView: View {
    @EnvironmentObject var api: APIService

    @State private var creators: [TikTokCreator] = []
    @State private var tags: [TikTokTag] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Filters
    @State private var selectedTagId: Int?
    @State private var selectedStatus: CreatorStatus?
    @State private var minFollowers: String = ""
    @State private var maxFollowers: String = ""
    @State private var selectedCountry: String = ""
    @State private var searchKeyword: String = ""

    // Selection
    @State private var isSelecting = false
    @State private var selectedIds = Set<Int>()

    // Batch status
    @State private var showBatchStatusPicker = false
    @State private var batchStatus: CreatorStatus = .interested

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Content
            if isLoading {
                Spacer()
                ProgressView("加载达人数据...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundColor(.red)
                    Button("重试") {
                        loadData()
                    }
                }
                Spacer()
            } else if creators.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("暂无达人数据")
                        .foregroundColor(.secondary)
                    Text("请先启动采集或调整筛选条件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 360))], spacing: 12) {
                        ForEach(creators) { creator in
                            NavigationLink {
                                TikTokCreatorDetailView(creatorId: creator.id)
                            } label: {
                                CreatorCard(creator: creator, isSelected: selectedIds.contains(creator.id))
                                    .overlay(alignment: .topTrailing) {
                                        if isSelecting {
                                            Image(systemName: selectedIds.contains(creator.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundColor(selectedIds.contains(creator.id) ? .accentColor : .secondary)
                                                .padding(8)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isSelecting {
                                            toggleSelection(creator.id)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("达人发现池")
        .toolbar {
            ToolbarItem {
                Button(isSelecting ? "取消" : "选择") {
                    withAnimation {
                        isSelecting.toggle()
                        if !isSelecting { selectedIds.removeAll() }
                    }
                }
            }
            ToolbarItem {
                Button("刷新") {
                    loadData()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting && !selectedIds.isEmpty {
                batchActionBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .sheet(isPresented: $showBatchStatusPicker) {
            batchStatusPicker
        }
        .task {
            loadData()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Tag filter
            Picker("标签", selection: $selectedTagId) {
                Text("全部标签").tag(Int?.none)
                ForEach(tags) { tag in
                    Text(tag.name).tag(Int?.some(tag.id))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .onChange(of: selectedTagId) { _, _ in loadData() }

            // Status filter
            Picker("状态", selection: $selectedStatus) {
                Text("全部状态").tag(CreatorStatus?.none)
                ForEach(CreatorStatus.allCases) { status in
                    Text(status.displayName).tag(CreatorStatus?.some(status))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .onChange(of: selectedStatus) { _, _ in loadData() }

            // Followers range
            TextField("最低粉丝", text: $minFollowers)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .onSubmit { loadData() }
            TextField("最高粉丝", text: $maxFollowers)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .onSubmit { loadData() }

            // Country
            TextField("国家", text: $selectedCountry)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onSubmit { loadData() }

            // Search keyword
            TextField("搜索昵称", text: $searchKeyword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .onSubmit { loadData() }
        }
    }

    // MARK: - Batch Action Bar

    private var batchActionBar: some View {
        HStack {
            Text("已选择 \(selectedIds.count) 个达人")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("批量打标签") {
                showBatchStatusPicker = true
            }
            .buttonStyle(.bordered)
            Button("批量更新状态") {
                showBatchStatusPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Batch Status Picker

    private var batchStatusPicker: some View {
        VStack(spacing: 16) {
            Text("更新达人状态")
                .font(.headline)
            Picker("状态", selection: $batchStatus) {
                ForEach(CreatorStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.radioGroup)
            HStack(spacing: 12) {
                Button("取消") {
                    showBatchStatusPicker = false
                }
                Button("确认更新 \(selectedIds.count) 个达人") {
                    batchUpdateStatus()
                }
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Actions

    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                async let tagsTask = api.tiktokGetTags()
                async let creatorsTask = api.tiktokGetCreatorsDiscovery(
                    tagId: selectedTagId,
                    status: selectedStatus,
                    minFollowers: Int(minFollowers).flatMap { $0 },
                    maxFollowers: Int(maxFollowers).flatMap { $0 },
                    country: selectedCountry.isEmpty ? nil : selectedCountry,
                    keyword: searchKeyword.isEmpty ? nil : searchKeyword
                )
                let (loadedTags, loadedCreators) = try await (tagsTask, creatorsTask)
                tags = loadedTags
                creators = loadedCreators
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func toggleSelection(_ id: Int) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func batchUpdateStatus() {
        let ids = Array(selectedIds)
        Task {
            do {
                try await api.tiktokBatchUpdateStatus(creatorIds: ids, status: batchStatus)
                showBatchStatusPicker = false
                selectedIds.removeAll()
                isSelecting = false
                loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Creator Card

struct CreatorCard: View {
    let creator: TikTokCreator
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Avatar placeholder
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(creator.nickname?.prefix(1).uppercased() ?? "?")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(creator.nickname ?? "未知")
                        .font(.headline)
                        .lineLimit(1)
                    if let country = creator.country, !country.isEmpty {
                        Text("📍 \(country)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let status = creator.status {
                    Text(status.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor(status).opacity(0.15))
                        .foregroundColor(statusColor(status))
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 16) {
                if let followers = creator.followerCount {
                    statItem(value: followers, label: "粉丝")
                }
                if let videos = creator.videoCount {
                    statItem(value: videos, label: "视频")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if let tags = creator.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(3)) { tag in
                        Text("#\(tag.name)")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    if tags.count > 3 {
                        Text("+\(tags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private func statItem(value: Int, label: String) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .fontWeight(.medium)
            Text(label)
        }
    }

    private func statusColor(_ status: CreatorStatus) -> Color {
        switch status {
        case .new: return .blue
        case .interested: return .orange
        case .contacted: return .purple
        case .cooperating: return .green
        case .rejected: return .red
        case .blacklist: return .gray
        }
    }
}
