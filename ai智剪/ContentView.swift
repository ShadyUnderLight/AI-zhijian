import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: APIService
    
    var body: some View {
        Group {
            if api.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 960, minHeight: 680)
    }
}
