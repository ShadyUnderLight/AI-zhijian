import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
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

    var icon: String {
        switch self {
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
    @State private var selectedTab: SidebarTab = .imageGen

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .font(.body)
                    .tag(tab)
                    .accessibilityIdentifier("sidebar-\(tab)")
            }
            .listStyle(.sidebar)
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
