import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case imageGen = "图片生成"
    case seedance = "Seedance 视频"
    case banana = "Banana 图片"
    case wan = "Wan 视频"
    case veo = "Veo 视频"
    case grok = "Grok 视频"
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
        case .history: return "clock.arrow.circlepath"
        case .tasks: return "list.bullet.rectangle"
        }
    }

    var id: Self { self }
}

struct MainView: View {
    @EnvironmentObject var api: APIService
    @State private var selectedTab: SidebarTab = .imageGen
    
    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .font(.body)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("退出") { Task { await api.logout() } }
                        .font(.caption)
                }
            }
        } detail: {
            detailView
        }
        .navigationTitle("AI 智剪")
        .navigationSubtitle("\(api.username) (\(api.role))")
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
        case .history:
            HistoryView()
        case .tasks:
            TaskListView()
        }
    }
}

#Preview {
    MainView()
        .environmentObject(APIService.shared)
}
