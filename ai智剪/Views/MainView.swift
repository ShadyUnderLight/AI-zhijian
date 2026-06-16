import SwiftUI

// MARK: - Sidebar Tab Enum

enum SidebarTab: String, Identifiable {
    case dashboard = "首页"
    case imageGen = "图片生成"
    case seedance = "Seedance 视频"
    case banana = "Banana 图片"
    case wan = "Wan 视频"
    case veo = "Veo 视频"
    case grok = "Grok 视频"
    case dramaWizard = "短剧一键生成"
    case aiComicStudio = "AI 漫剧生成"
    case voiceGen = "语音生成"
    case transcript = "视频文案提取"
    case subtitleRemove = "视频去字幕"
    case backgroundReplace = "视频背景替换"
    case characterReplace = "人物替换"
    case motionTransfer = "动作迁移"
    case lipSyncImage = "图片对口型"
    case videoReplica = "视频复刻"
    case heygen = "HeyGen 数字人"
    case scriptLib = "脚本库"
    case workflow = "工作流"
    case works = "作品库"
    case tasks = "任务队列"
    case settings = "设置"
    // Workflow 模板
    case textImageVideo = "文→图→视频"
    case healthAction = "健康科普"
    case softAd = "软广工作流"
    // TikTok 达人采集
    case tiktokCreators = "TikTok 达人发现"
    case tiktokTags = "TikTok 标签管理"
    case tiktokScrape = "TikTok 采集控制"
    // Admin
    case adminUsers = "用户管理"
    case adminApiKeys = "API Key"
    case adminCallLogs = "调用日志"
    case adminRouteHealth = "线路检测"
    // Admin — Phase 7
    case adminContentAudit = "内容审核"
    case adminPromptRules = "提示词规则"

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .imageGen: return "photo.badge.plus"
        case .seedance: return "video.badge.plus"
        case .banana: return "paintbrush"
        case .wan: return "film"
        case .veo: return "globe"
        case .grok: return "brain"
        case .dramaWizard: return "theatermasks"
        case .aiComicStudio: return "book.pages"
        case .voiceGen: return "waveform"
        case .transcript: return "doc.text.magnifyingglass"
        case .subtitleRemove: return "text.badge.minus"
        case .backgroundReplace: return "photo.on.rectangle"
        case .characterReplace: return "person.crop.circle.badge.plus"
        case .motionTransfer: return "figure.walk"
        case .lipSyncImage: return "mouth"
        case .videoReplica: return "square.on.square"
        case .heygen: return "person.wave.2"
        case .scriptLib: return "doc.text"
        case .workflow: return "arrow.triangle.branch"
        case .works: return "square.grid.2x2"
        case .tasks: return "list.bullet.rectangle"
        case .settings: return "gearshape"
        case .textImageVideo: return "photo.on.rectangle"
        case .healthAction: return "figure.run"
        case .softAd: return "bag"
        case .tiktokCreators: return "person.3"
        case .tiktokTags: return "tag"
        case .tiktokScrape: return "antenna.radiowaves.left.and.right"
        case .adminUsers: return "person.2"
        case .adminApiKeys: return "key"
        case .adminCallLogs: return "doc.text.magnifyingglass"
        case .adminRouteHealth: return "heart"
        case .adminContentAudit: return "checkmark.shield"
        case .adminPromptRules: return "doc.richtext"
        }
    }

    /// 是否可以置顶（首页和管理页不置顶）
    var isPinnable: Bool {
        switch self {
        case .dashboard, .adminUsers, .adminApiKeys, .adminCallLogs,
                .adminRouteHealth, .adminContentAudit, .adminPromptRules:
            return false
        default:
            return true
        }
    }

    var id: Self { self }
    var accessibilityIdentifier: String { "sidebar-\(self)" }
}

// MARK: - MainView

struct MainView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var worksStore: WorksStore
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var workflowStore: WorkflowStore
    @EnvironmentObject var sidebarVisibility: SidebarVisibilityStore
    @State private var selectedTab: SidebarTab = .dashboard
    @State private var showLogoutConfirm = false
    @State private var pinnedTabIds: Set<String> = []
    @State private var isLoadingPinned = false

    /// 当前用户可见的所有 tab 的 rawValue 集合（用于过滤置顶项）
    private var visibleTabRawValues: Set<String> {
        var values = Set(SidebarTab.allTabs.map(\.rawValue))
        // 非管理员看不到仅管理员 tab（内容审核除外，它可由审核权限控制）
        if api.role.uppercased() != "ADMIN" {
            let adminTabs: [SidebarTab] = [.adminUsers, .adminApiKeys, .adminCallLogs,
                                           .adminRouteHealth, .adminPromptRules]
            for tab in adminTabs {
                values.remove(tab.rawValue)
            }
            // 无审核权限的非管理员也看不到内容审核
            if !api.contentAuditPermission {
                values.remove(SidebarTab.adminContentAudit.rawValue)
            }
        }
        // 用户显式隐藏的 tab
        for hidden in sidebarVisibility.hiddenTabs {
            values.remove(hidden)
        }
        return values
    }

    /// 仅首页不被置顶
    private var pinnableTabIds: Set<String> {
        Set(SidebarTab.allTabs.filter(\.isPinnable).map(\.rawValue))
    }

    private var effectivePinnedTabIds: [SidebarTab] {
        pinnedTabIds
            .compactMap { SidebarTab(rawValue: $0) }
            .filter { visibleTabRawValues.contains($0.rawValue) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedTab) {
                    // ——— 置顶区 ———
                    if !effectivePinnedTabIds.isEmpty {
                        Section("置顶") {
                            ForEach(effectivePinnedTabIds, id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }

                    Section("首页") {
                        sidebarLabel(.dashboard)
                    }
                    if !sidebarVisibility.filterVisible([.imageGen, .banana]).isEmpty {
                        Section("图片") {
                            ForEach(sidebarVisibility.filterVisible([.imageGen, .banana]), id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }
                    if !sidebarVisibility.filterVisible([.seedance, .wan, .veo, .grok]).isEmpty {
                        Section("视频生成") {
                            ForEach(sidebarVisibility.filterVisible([.seedance, .wan, .veo, .grok]), id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }
                    if !sidebarVisibility.filterVisible([.subtitleRemove, .backgroundReplace, .characterReplace, .motionTransfer, .lipSyncImage, .videoReplica]).isEmpty {
                        Section("视频编辑") {
                            ForEach(sidebarVisibility.filterVisible([.subtitleRemove, .backgroundReplace, .characterReplace, .motionTransfer, .lipSyncImage, .videoReplica]), id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }
                    if sidebarVisibility.isVisible(.heygen) {
                        Section("数字人") {
                            sidebarLabel(.heygen)
                        }
                    }
                    if !sidebarVisibility.filterVisible([.textImageVideo, .healthAction, .softAd]).isEmpty {
                        Section("工作流") {
                            ForEach(sidebarVisibility.filterVisible([.textImageVideo, .healthAction, .softAd]), id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }
                    if !sidebarVisibility.filterVisible([.dramaWizard, .aiComicStudio]).isEmpty {
                        Section("AI 创作") {
                            ForEach(sidebarVisibility.filterVisible([.dramaWizard, .aiComicStudio]), id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }
                    if !sidebarVisibility.filterVisible([.voiceGen, .transcript]).isEmpty {
                        Section("语音") {
                            ForEach(sidebarVisibility.filterVisible([.voiceGen, .transcript]), id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }
                    if !sidebarVisibility.filterVisible([.scriptLib, .workflow, .works, .tasks, .settings]).isEmpty {
                        Section("工具") {
                            ForEach(sidebarVisibility.filterVisible([.scriptLib, .workflow, .works, .tasks, .settings]), id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }
                    if !sidebarVisibility.filterVisible([.tiktokCreators, .tiktokTags, .tiktokScrape]).isEmpty {
                        Section("TikTok 达人") {
                            ForEach(sidebarVisibility.filterVisible([.tiktokCreators, .tiktokTags, .tiktokScrape]), id: \.self) { tab in
                                sidebarLabel(tab)
                            }
                        }
                    }
                    if api.role.uppercased() == "ADMIN" {
                        if !sidebarVisibility.filterVisible([.adminUsers, .adminApiKeys, .adminCallLogs, .adminRouteHealth, .adminContentAudit, .adminPromptRules]).isEmpty {
                            Section("管理") {
                                ForEach(sidebarVisibility.filterVisible([.adminUsers, .adminApiKeys, .adminCallLogs, .adminRouteHealth, .adminContentAudit, .adminPromptRules]), id: \.self) { tab in
                                    sidebarLabel(tab)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack(spacing: 6) {
                    Circle()
                        .fill(healthDotColor)
                        .frame(width: 7, height: 7)
                    Text(healthDotLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(verbatim: "· \(api.serverDisplayOrigin)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if api.isHTTPWithoutLocalhost {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("退出", role: .destructive) {
                        showLogoutConfirm = true
                    }
                        .font(.caption)
                        .confirmationDialog(
                            "确定退出登录？",
                            isPresented: $showLogoutConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("退出", role: .destructive) {
                                queueStore.cancelAndClearAll()
                                Task { await api.logout() }
                            }
                            Button("取消", role: .cancel) {}
                        } message: {
                            Text("退出后将：\n· 清除本地队列任务（进行中的远端任务不受影响）\n· 清除已保存的登录凭据\n· 清除本地任务记录\n\n下次启动需要重新登录。")
                        }
                }
            }
        } detail: {
            detailView
        }
        .navigationTitle("AI 智剪")
        .navigationSubtitle("\(api.username) (\(api.role))")
        .task {
            await api.checkBackendHealth()
            await loadPinnedItems()
        }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in
            guard let item = editCoordinator.editingItem else { return }
            selectedTab = tabForKind(item.kind)
        }
        .onChange(of: editCoordinator.navigateToKind) { _, kind in
            guard let kind else { return }
            selectedTab = tabForKind(kind)
            editCoordinator.navigateToKind = nil
        }
        .onChange(of: api.role) { _, newRole in
            if newRole.uppercased() != "ADMIN" {
                let adminTabs: [SidebarTab] = [
                    .adminUsers, .adminApiKeys, .adminCallLogs, .adminRouteHealth,
                    .adminContentAudit, .adminPromptRules
                ]
                if adminTabs.contains(selectedTab) {
                    selectedTab = .dashboard
                }
            }
        }
        .onChange(of: api.contentAuditPermission) { _, newValue in
            if !newValue, selectedTab == .adminContentAudit {
                selectedTab = .dashboard
            }
        }
        .onChange(of: sidebarVisibility.hiddenTabs) { _, newHidden in
            if newHidden.contains(selectedTab.rawValue) {
                selectedTab = .dashboard
            }
        }
    }

    // MARK: - Detail View Router

    @ViewBuilder
    var detailView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView(onNavigateToTab: { selectedTab = $0 })
        case .imageGen:
            ImageGenView()
        case .seedance:
            SeedanceVideoView()
        case .banana:
            BananaView()
        case .wan:
            WanVideoView()
        case .veo:
            VeoVideoView()
        case .grok:
            GrokVideoView()
        case .voiceGen:
            VoiceGenView()
        case .transcript:
            TranscriptView()
        case .subtitleRemove:
            SubtitleRemoveView()
        case .backgroundReplace:
            BackgroundReplaceView()
        case .characterReplace:
            CharacterReplaceView()
        case .motionTransfer:
            MotionTransferView()
        case .lipSyncImage:
            LipSyncImageView()
        case .videoReplica:
            VideoReplicaView()
        case .heygen:
            HeyGenView()
        case .textImageVideo:
            TextImageVideoWorkflowView()
        case .healthAction:
            HealthActionWorkflowView()
        case .softAd:
            SoftAdWorkflowView()
        case .dramaWizard:
            DramaWizardView()
        case .aiComicStudio:
            AiComicStudioView()
        case .scriptLib:
            ScriptLibraryView()
        case .workflow:
            WorkflowEditorView()
        case .works:
            WorksGalleryView()
        case .tasks:
            TaskListView()
        case .settings:
            SettingsView()
        case .tiktokCreators:
            TikTokCreatorsView()
        case .tiktokTags:
            TikTokTagManageView()
        case .tiktokScrape:
            TikTokScrapeControlView()
        case .adminUsers:
            UserManageView()
        case .adminApiKeys:
            ApiKeyManageView()
        case .adminCallLogs:
            CallLogView()
        case .adminRouteHealth:
            RouteHealthView()
        case .adminContentAudit:
            ContentAuditView()
        case .adminPromptRules:
            PromptRuleView()
        }
    }

    // MARK: - Helpers

    private var healthDotColor: Color {
        switch api.backendHealthState {
        case .healthy: return .green
        case .reachable: return .yellow
        case .unhealthy: return .orange
        case .unreachable: return .red
        case .unknown, .checking: return .gray
        }
    }

    private var healthDotLabel: String {
        switch api.backendHealthState {
        case .unknown, .checking: return "检测中..."
        case .healthy: return "已连接"
        case .reachable: return "需鉴权"
        case .unhealthy: return "服务异常"
        case .unreachable: return "无法连接"
        }
    }

    private func tabForKind(_ kind: GenerationJobKind) -> SidebarTab {
        switch kind {
        case .gptImage: return .imageGen
        case .banana: return .banana
        case .seedance: return .seedance
        case .wan: return .wan
        case .veo: return .veo
        case .grok: return .grok
        case .voiceGen: return .voiceGen
        case .transcript: return .transcript
        case .subtitleRemove: return .subtitleRemove
        case .backgroundReplace: return .backgroundReplace
        case .characterReplace: return .characterReplace
        case .motionTransfer: return .motionTransfer
        case .lipSyncImage: return .lipSyncImage
        case .videoReplica: return .videoReplica
        case .heygen: return .heygen
        case .gptStoryboardScene: return .imageGen
        }
    }

    // MARK: - Pinned Items

    private func loadPinnedItems() async {
        guard !isLoadingPinned else { return }
        isLoadingPinned = true
        defer { isLoadingPinned = false }

        do {
            let resp = try await api.pinnedGetItems()
            if resp.success {
                let ids = Set(resp.items?.map(\.itemId) ?? [])
                await MainActor.run {
                    pinnedTabIds = ids.intersection(pinnableTabIds)
                }
            }
        } catch {
            // Silently fail — pinning is a convenience feature
        }
    }

    private func togglePinned(_ tab: SidebarTab) {
        guard tab.isPinnable else { return }
        if pinnedTabIds.contains(tab.rawValue) {
            // Unpin
            pinnedTabIds.remove(tab.rawValue)
            Task {
                _ = try? await api.pinnedRemoveItem(itemType: "sidebar_tab", itemId: tab.rawValue)
            }
        } else {
            // Pin
            pinnedTabIds.insert(tab.rawValue)
            Task {
                _ = try? await api.pinnedAddItem(itemType: "sidebar_tab", itemId: tab.rawValue)
            }
        }
    }

    // MARK: - Sidebar Label

    @ViewBuilder
    private func sidebarLabel(_ tab: SidebarTab) -> some View {
        Label(tab.rawValue, systemImage: tab.icon)
            .tag(tab)
            .accessibilityIdentifier(tab.accessibilityIdentifier)
            .contextMenu {
                if tab.isPinnable {
                    if pinnedTabIds.contains(tab.rawValue) {
                        Button {
                            togglePinned(tab)
                        } label: {
                            Label("取消置顶", systemImage: "pin.slash")
                        }
                    } else {
                        Button {
                            togglePinned(tab)
                        } label: {
                            Label("置顶", systemImage: "pin")
                        }
                    }
                }
            }
    }
}

// MARK: - All Cases Conformance

extension SidebarTab {
    /// 所有 tab 列表（用于计算可见集合，避免 CaseIterable 的 Swift 6 并发问题）
    static let allTabs: [SidebarTab] = [
        .dashboard,
        .imageGen, .seedance, .banana, .wan, .veo, .grok,
        .dramaWizard, .aiComicStudio,
        .voiceGen, .transcript,
        .subtitleRemove, .backgroundReplace, .characterReplace,
        .motionTransfer, .lipSyncImage, .videoReplica,
        .heygen,
        .scriptLib, .workflow, .works, .tasks, .settings,
        .textImageVideo, .healthAction, .softAd,
        .tiktokCreators, .tiktokTags, .tiktokScrape,
        .adminUsers, .adminApiKeys, .adminCallLogs, .adminRouteHealth,
        .adminContentAudit, .adminPromptRules
    ]
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(APIService.shared)
        .environmentObject(WorksStore())
        .environmentObject(GenerationQueueStore(api: APIService.shared))
        .environmentObject(EditTaskCoordinator())
        .environmentObject(WorkflowStore(api: APIService.shared))
        .environmentObject(PresetStore())
        .environmentObject(ScriptStore())
}
