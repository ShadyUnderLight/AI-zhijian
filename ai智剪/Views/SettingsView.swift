import SwiftUI

private enum SettingsCachedKey {
    static let concurrencyLimit = "settings_concurrency_limit"
    static let notificationEnabled = "settings_notification_enabled"
}

private extension URL {
    var normalizedOrigin: String {
        guard let comps = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let host = comps.host?.lowercased()
        else { return "" }
        let scheme = comps.scheme?.lowercased() ?? "https"
        let port: Int
        if let p = comps.port {
            port = p
        } else {
            port = scheme == "https" ? 443 : 80
        }
        return "\(scheme)://\(host):\(port)"
    }
}

struct SettingsView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var worksStore: WorksStore
    @EnvironmentObject var queueStore: GenerationQueueStore

    @State private var apiURLString: String = ""
    @State private var concurrency: Int = 5
    @State private var notificationEnabled: Bool = false
    @State private var showClearConfirm = false
    @State private var showClearAllConfirm = false
    @State private var showHostChangeConfirm = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var currentOrigin: String {
        AppConfig.apiBaseURL.normalizedOrigin
    }

    private var isHTTPWithoutLocalhost: Bool {
        guard let url = URL(string: apiURLString) else { return false }
        return url.scheme == "http"
            && url.host != "localhost"
            && url.host != "127.0.0.1"
    }

    var body: some View {
        Form {
            Section("API 服务器") {
                TextField("服务器地址", text: $apiURLString)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .onSubmit { validateAndApply() }

                if isHTTPWithoutLocalhost {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("当前 API 地址使用 HTTP 协议，数据传输未加密")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }

                HStack {
                    Button("保存") { validateAndApply() }
                        .buttonStyle(.borderedProminent)
                    Button("重置默认") { resetToDefault() }
                        .buttonStyle(.bordered)
                }
            }

            Section("任务") {
                HStack {
                    Text("默认并发数")
                    Spacer()
                    Stepper(value: $concurrency, in: 1...5) {
                        Text("\(concurrency)")
                            .font(.body.monospaced())
                            .frame(width: 24)
                    }
                    .onChange(of: concurrency) { _, newValue in
                        queueStore.concurrencyLimit = newValue
                        UserDefaults.standard.set(newValue, forKey: SettingsCachedKey.concurrencyLimit)
                    }
                }
            }

            Section("通知") {
                Toggle("启用通知", isOn: $notificationEnabled)
                    .onChange(of: notificationEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: SettingsCachedKey.notificationEnabled)
                    }
                Text("通知功能当前为预留设置，暂未实现推送")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("数据管理") {
                Button("清除已完成/失败的队列任务") {
                    queueStore.clearAllCompleted()
                    alertMessage = "已清除队列中的已完成/失败/已取消任务"
                    showAlert = true
                }
                .buttonStyle(.bordered)

                Button("清除作品库记录（含本地文件）") {
                    worksStore.clearAll()
                    alertMessage = "已清除作品库记录及本地缓存图片"
                    showAlert = true
                }
                .buttonStyle(.bordered)

                Button("清除所有本地数据", role: .destructive) {
                    showClearAllConfirm = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .confirmationDialog(
                    "确定清除所有本地数据？",
                    isPresented: $showClearAllConfirm,
                    titleVisibility: .visible
                ) {
                    Button("清除", role: .destructive) {
                        queueStore.cancelAndClearAll()
                        worksStore.clearAll()
                        alertMessage = "已清除所有本地数据（包含队列、作品库、本地文件）"
                        showAlert = true
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("这将清除所有队列任务（含进行中任务）、作品库记录和本地缓存图片。正在进行中的远端任务不会被取消。不影响登录状态。")
                }
            }

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "--")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        .onAppear { loadSettings() }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .alert("切换 API 服务器", isPresented: $showHostChangeConfirm) {
            Button("切换并重新登录", role: .destructive) { commitHostChange() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("更改 API 服务器地址将：\n· 清除当前登录状态\n· 清除记住的凭据\n· 清空任务队列\n\n请确认新的服务器地址正确，然后重新登录。")
        }
    }

    private func loadSettings() {
        apiURLString = AppConfig.currentBaseURLString
        concurrency = UserDefaults.standard.integer(forKey: SettingsCachedKey.concurrencyLimit)
        if concurrency < 1 || concurrency > 5 { concurrency = 5 }
        queueStore.concurrencyLimit = concurrency
        notificationEnabled = UserDefaults.standard.bool(forKey: SettingsCachedKey.notificationEnabled)
    }

    private func validateAndApply() {
        let trimmed = apiURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let sanitized = AppConfig.sanitizedBaseURL(trimmed) else {
            alertMessage = "无效的 URL 格式：只支持 http/https 协议，且必须包含有效的域名或 IP"
            showAlert = true
            return
        }
        applyURL(sanitized)
    }

    private func resetToDefault() {
        AppConfig.resetCustomBaseURL()
        guard let url = AppConfig.sanitizedBaseURL(AppConfig.currentBaseURLString) else { return }
        apiURLString = AppConfig.currentBaseURLString
        applyURL(url)
    }

    private func applyURL(_ url: URL) {
        let originChanged = url.normalizedOrigin != currentOrigin
        AppConfig.setCustomBaseURL(url.absoluteString)
        apiURLString = AppConfig.currentBaseURLString

        if originChanged && api.isLoggedIn {
            showHostChangeConfirm = true
        } else {
            alertMessage = originChanged
                ? "API 地址已更新（未登录，无需重置会话）"
                : "API 地址已更新"
            showAlert = true
        }
    }

    private func commitHostChange() {
        queueStore.cancelAndClearAll()
        api.resetForNewHost()
        alertMessage = "API 地址已更新，登录状态已重置，请重新登录"
        showAlert = true
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIService.shared)
        .environmentObject(WorksStore())
        .environmentObject(GenerationQueueStore(api: APIService.shared))
}
