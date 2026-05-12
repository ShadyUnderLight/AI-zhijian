import SwiftUI

@main
struct AI____App: App {
    @StateObject private var api = APIService.shared
    @StateObject private var queueStore = GenerationQueueStore(api: APIService.shared)
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .environmentObject(queueStore)
                .frame(minWidth: 960, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}
