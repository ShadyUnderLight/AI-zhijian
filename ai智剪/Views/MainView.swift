import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case dashboard = "首页"
    case imageGen = "图片生成"
    case seedance = "Seedance 视频"
    case banana = "Banana 图片"
    case wan = "Wan 视频"
    case veo = "Veo 视频"
    case grok = "Grok 视频"
    case workflow = "工作流"
    case works = "作品库"
    case history = "历史记录"
    case tasks = "任务队列"
    case settings = "设置"

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .imageGen: return "photo.badge.plus"
        case .seedance: return "video.badge.plus"
        case .banana: return "paintbrush"
        case .wan: return "film"
        case .veo: return "globe"
        case .grok: return "brain"
        case .workflow: return "arrow.triangle.branch"
        case .works: return "square.grid.2x2"
        case .history: return "clock.arrow.circlepath"
        case .tasks: return "list.bullet.rectangle"
        case .settings: return "gearshape"
        }
    }

    var id: Self { self }
}

struct MainView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var worksStore: WorksStore
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var workflowStore: WorkflowStore
    @State private var selectedTab: SidebarTab = .dashboard

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(SidebarTab.allCases, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.body)
                        .tag(tab)
                        .accessibilityIdentifier("sidebar-\(tab)")
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
                    Button("退出") {
                        queueStore.cancelAndClearAll()
                        Task { await api.logout() }
                    }
                        .font(.caption)
                }
            }
        } detail: {
            detailView
        }
        .navigationTitle("AI 智剪")
        .navigationSubtitle("\(api.username) (\(api.role))")
        .task {
            await api.checkBackendHealth()
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
    }

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
        case .workflow:
            WorkflowEditorView()
        case .works:
            WorksGalleryView()
        case .history:
            HistoryView()
        case .tasks:
            TaskListView()
        case .settings:
            SettingsView()
        }
    }

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
        }
    }
}

#Preview {
    MainView()
        .environmentObject(APIService.shared)
        .environmentObject(WorksStore())
        .environmentObject(GenerationQueueStore(api: APIService.shared))
        .environmentObject(EditTaskCoordinator())
        .environmentObject(WorkflowStore(api: APIService.shared))
        .environmentObject(PresetStore())
}
