import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: APIService

    var body: some View {
        Group {
            if api.isCheckingSession {
                ProgressView("正在验证登录状态...")
                    .frame(minWidth: 300, minHeight: 200)
            } else if api.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 960, minHeight: 680)
        .task {
            await api.checkSessionStatus()
        }
    }
}
