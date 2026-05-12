import SwiftUI

@main
struct AI____App: App {
    @StateObject private var api = APIService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .frame(minWidth: 960, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}
