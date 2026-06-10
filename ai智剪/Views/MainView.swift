import SwiftUI

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
        }
    }

    var id: Self { self }
    var accessibilityIdentifier: String { "sidebar-\(self)" }
}

struct MainView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var worksStore: WorksStore
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var workflowStore: WorkflowStore
    @State private var selectedTab: SidebarTab = .dashboard
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedTab) {
                    Section("首页") {
                        sidebarLabel(.dashboard)
                    }
                    Section("图片") {
                        sidebarLabel(.imageGen)
                        sidebarLabel(.banana)
                    }
                    Section("视频生成") {
                        sidebarLabel(.seedance)
                        sidebarLabel(.wan)
                        sidebarLabel(.veo)
                        sidebarLabel(.grok)
                    }
                    Section("视频编辑") {
                        sidebarLabel(.subtitleRemove)
                        sidebarLabel(.backgroundReplace)
                        sidebarLabel(.characterReplace)
                        sidebarLabel(.motionTransfer)
                        sidebarLabel(.lipSyncImage)
                        sidebarLabel(.videoReplica)
                    }
                    Section("数字人") {
                        sidebarLabel(.heygen)
                    }
                    Section("AI 创作") {
                        sidebarLabel(.dramaWizard)
                        sidebarLabel(.aiComicStudio)
                    }
                    Section("语音") {
                        sidebarLabel(.voiceGen)
                        sidebarLabel(.transcript)
                    }
                    Section("工具") {
                        sidebarLabel(.scriptLib)
                        sidebarLabel(.workflow)
                        sidebarLabel(.works)
                        sidebarLabel(.tasks)
                        sidebarLabel(.settings)
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
        case .voiceGen: return .voiceGen
        case .transcript: return .transcript
        case .subtitleRemove: return .subtitleRemove
        case .backgroundReplace: return .backgroundReplace
        case .characterReplace: return .characterReplace
        case .motionTransfer: return .motionTransfer
        case .lipSyncImage: return .lipSyncImage
        case .videoReplica: return .videoReplica
        case .heygen: return .heygen
        }
    }

    @ViewBuilder
    private func sidebarLabel(_ tab: SidebarTab) -> some View {
        Label(tab.rawValue, systemImage: tab.icon)
            .tag(tab)
            .accessibilityIdentifier(tab.accessibilityIdentifier)
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
        .environmentObject(ScriptStore())
}
