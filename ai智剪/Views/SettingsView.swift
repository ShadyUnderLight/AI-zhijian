import SwiftUI

private enum SettingsCachedKey {
    static let concurrencyLimit = "settings_concurrency_limit"
    static let notificationEnabled = "settings_notification_enabled"
}

struct SettingsView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var worksStore: WorksStore
    @EnvironmentObject var queueStore: GenerationQueueStore

    @State private var apiURLString: String = ""
    @State private var concurrency: Int = 5
    @State private var notificationEnabled: Bool = false
    @State private var showClearConfirm = false
    @State private var showAlert = false
    @State private var alertMessage = ""

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
                    .onSubmit { applyAPIURL() }

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
                    Button("保存") { applyAPIURL() }
                        .buttonStyle(.borderedProminent)
                    Button("重置默认") {
                        AppConfig.resetCustomBaseURL()
                        apiURLString = AppConfig.currentBaseURLString
                        alertMessage = "已重置为默认 API 地址"
                        showAlert = true
                    }
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

                Button("清除作品库记录") {
                    worksStore.clearAll()
                    alertMessage = "已清除作品库记录"
                    showAlert = true
                }
                .buttonStyle(.bordered)

                Button("清除所有本地数据", role: .destructive) {
                    showClearConfirm = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .confirmationDialog(
                    "确定清除所有本地数据？",
                    isPresented: $showClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("清除", role: .destructive) {
                        queueStore.clearAllCompleted()
                        worksStore.clearAll()
                        alertMessage = "已清除所有本地数据"
                        showAlert = true
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("这将清除队列记录和作品库数据，但不会影响登录状态。")
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
    }

    private func loadSettings() {
        apiURLString = AppConfig.currentBaseURLString
        concurrency = UserDefaults.standard.integer(forKey: SettingsCachedKey.concurrencyLimit)
        if concurrency < 1 || concurrency > 5 { concurrency = 5 }
        queueStore.concurrencyLimit = concurrency
        notificationEnabled = UserDefaults.standard.bool(forKey: SettingsCachedKey.notificationEnabled)
    }

    private func applyAPIURL() {
        let trimmed = apiURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard URL(string: trimmed) != nil else {
            alertMessage = "无效的 URL 格式"
            showAlert = true
            return
        }
        AppConfig.setCustomBaseURL(trimmed)
        apiURLString = AppConfig.currentBaseURLString
        alertMessage = "API 地址已更新，新建请求将使用新地址"
        showAlert = true
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIService.shared)
        .environmentObject(WorksStore())
        .environmentObject(GenerationQueueStore(api: APIService.shared))
}
