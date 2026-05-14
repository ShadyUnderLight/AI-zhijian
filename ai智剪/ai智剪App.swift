import SwiftUI

@main
struct AI____App: App {
    @StateObject private var api = APIService.shared
    @StateObject private var worksStore = WorksStore()
    @StateObject private var queueStore: GenerationQueueStore = {
        let store = GenerationQueueStore(api: APIService.shared)
        return store
    }()
    @StateObject private var editCoordinator = EditTaskCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .environmentObject(worksStore)
                .environmentObject(queueStore)
                .environmentObject(editCoordinator)
                .frame(minWidth: 960, minHeight: 680)
                .onAppear {
                    queueStore.worksStore = worksStore
                }
        }
        .windowStyle(.titleBar)
    }
}
