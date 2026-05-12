import SwiftUI

struct LoginView: View {
    @EnvironmentObject var api: APIService
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    
    enum Field { case user, pass }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "scissors")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("AI 智剪")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("海灵智剪 macOS 客户端")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("用户名").font(.caption).foregroundColor(.secondary)
                    TextField("请输入用户名", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .user)
                        .onSubmit { focusedField = .pass }
                        .disabled(api.isLoggingIn)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("密码").font(.caption).foregroundColor(.secondary)
                    SecureField("请输入密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .pass)
                        .onSubmit { doLogin() }
                        .disabled(api.isLoggingIn)
                }
                
                if let error = api.loginError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Button(action: doLogin) {
                    HStack {
                        if api.isLoggingIn {
                            ProgressView().scaleEffect(0.7)
                                .padding(.trailing, 4)
                        }
                        Text("登录")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || api.isLoggingIn)
                .padding(.top, 8)
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
        .frame(width: 420, height: 380)
        .onAppear {
            if username.isEmpty {
                let cached = UserDefaults.standard.string(forKey: "cached_username") ?? ""
                username = cached.isEmpty ? "user" : cached
            }
        }
    }
    
    private func doLogin() {
        guard !username.isEmpty, !password.isEmpty else { return }
        Task { await api.login(username: username, password: password) }
    }
}

#Preview {
    LoginView()
        .environmentObject(APIService.shared)
}
