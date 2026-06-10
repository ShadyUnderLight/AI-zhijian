import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case dashboard = "首页"
    case imageGen = "图片生成"
    case seedance = "Seedance 视频"
    case banana = "Banana 图片"
    case wan = "Wan 视频"
    case veo = "Veo 视频"
    case grok = "Grok 视频"
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
                        Label(SidebarTab.dashboard.rawValue, systemImage: SidebarTab.dashboard.icon)
                            .tag(SidebarTab.dashboard)
                    }
                    Section("图片") {
                        Label(SidebarTab.imageGen.rawValue, systemImage: SidebarTab.imageGen.icon)
                            .tag(SidebarTab.imageGen)
                        Label(SidebarTab.banana.rawValue, systemImage: SidebarTab.banana.icon)
                            .tag(SidebarTab.banana)
                    }
                    Section("视频生成") {
                        Label(SidebarTab.seedance.rawValue, systemImage: SidebarTab.seedance.icon)
                            .tag(SidebarTab.seedance)
                        Label(SidebarTab.wan.rawValue, systemImage: SidebarTab.wan.icon)
                            .tag(SidebarTab.wan)
                        Label(SidebarTab.veo.rawValue, systemImage: SidebarTab.veo.icon)
                            .tag(SidebarTab.veo)
                        Label(SidebarTab.grok.rawValue, systemImage: SidebarTab.grok.icon)
                            .tag(SidebarTab.grok)
                    }
                    Section("视频编辑") {
                        Label(SidebarTab.subtitleRemove.rawValue, systemImage: SidebarTab.subtitleRemove.icon)
                            .tag(SidebarTab.subtitleRemove)
                        Label(SidebarTab.backgroundReplace.rawValue, systemImage: SidebarTab.backgroundReplace.icon)
                            .tag(SidebarTab.backgroundReplace)
                        Label(SidebarTab.characterReplace.rawValue, systemImage: SidebarTab.characterReplace.icon)
                            .tag(SidebarTab.characterReplace)
                        Label(SidebarTab.motionTransfer.rawValue, systemImage: SidebarTab.motionTransfer.icon)
                            .tag(SidebarTab.motionTransfer)
                        Label(SidebarTab.lipSyncImage.rawValue, systemImage: SidebarTab.lipSyncImage.icon)
                            .tag(SidebarTab.lipSyncImage)
                        Label(SidebarTab.videoReplica.rawValue, systemImage: SidebarTab.videoReplica.icon)
                            .tag(SidebarTab.videoReplica)
                    }
                    Section("数字人") {
                        Label(SidebarTab.heygen.rawValue, systemImage: SidebarTab.heygen.icon)
                            .tag(SidebarTab.heygen)
                    }
                    Section("语音") {
                        Label(SidebarTab.voiceGen.rawValue, systemImage: SidebarTab.voiceGen.icon)
                            .tag(SidebarTab.voiceGen)
                        Label(SidebarTab.transcript.rawValue, systemImage: SidebarTab.transcript.icon)
                            .tag(SidebarTab.transcript)
                    }
                    Section("工具") {
                        Label(SidebarTab.scriptLib.rawValue, systemImage: SidebarTab.scriptLib.icon)
                            .tag(SidebarTab.scriptLib)
                        Label(SidebarTab.workflow.rawValue, systemImage: SidebarTab.workflow.icon)
                            .tag(SidebarTab.workflow)
                        Label(SidebarTab.works.rawValue, systemImage: SidebarTab.works.icon)
                            .tag(SidebarTab.works)
                        Label(SidebarTab.tasks.rawValue, systemImage: SidebarTab.tasks.icon)
                            .tag(SidebarTab.tasks)
                        Label(SidebarTab.settings.rawValue, systemImage: SidebarTab.settings.icon)
                            .tag(SidebarTab.settings)
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
