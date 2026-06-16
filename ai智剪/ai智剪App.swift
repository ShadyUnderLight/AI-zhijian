import SwiftUI

@main
struct AI____App: App {
    @StateObject private var api = APIService.shared
    @StateObject private var worksStore = WorksStore()
    @StateObject private var queueStore = GenerationQueueStore(api: APIService.shared)
    @StateObject private var editCoordinator = EditTaskCoordinator()
    @StateObject private var workflowStore = WorkflowStore(api: APIService.shared)
    @StateObject private var presetStore = PresetStore()
    @StateObject private var scriptStore = ScriptStore()
    @StateObject private var sidebarVisibility = SidebarVisibilityStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .environmentObject(worksStore)
                .environmentObject(queueStore)
                .environmentObject(editCoordinator)
                .environmentObject(workflowStore)
                .environmentObject(presetStore)
                .environmentObject(scriptStore)
                .environmentObject(sidebarVisibility)
                .frame(minWidth: 960, minHeight: 680)
                .onAppear {
                    queueStore.attachWorksStore(worksStore)
                    workflowStore.attachWorksStore(worksStore)
                }
        }
        .windowStyle(.titleBar)
    }
}
