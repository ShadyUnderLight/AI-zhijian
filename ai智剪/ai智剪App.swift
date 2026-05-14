import SwiftUI

@main
struct AI____App: App {
    @StateObject private var api = APIService.shared
    @StateObject private var queueStore = GenerationQueueStore(api: APIService.shared)
    @StateObject private var editCoordinator = EditTaskCoordinator()
    @StateObject private var workflowStore = WorkflowStore(api: APIService.shared)
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .environmentObject(queueStore)
                .environmentObject(editCoordinator)
                .environmentObject(workflowStore)
                .frame(minWidth: 960, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}
