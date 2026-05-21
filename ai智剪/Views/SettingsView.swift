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
    @State private var showClearCredentialConfirm = false
    @State private var showHostChangeConfirm = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    /// 待确认的 URL（确认前不写入 UserDefaults）
    @State private var pendingURL: URL? = nil

    private var currentOrigin: String {
        AppConfig.apiBaseURL.normalizedOrigin
    }

    private var hasActiveSession: Bool {
        api.isLoggedIn || api.rememberLogin
    }

    private var isHTTPWithoutLocalhost: Bool {
        guard let url = URL(string: apiURLString) else { return false }
        return url.scheme == "http" && !AppConfig.isLoopbackHost(url.host)
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

                Button("清除登录凭据", role: .destructive) {
                    showClearCredentialConfirm = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .confirmationDialog(
                    "确定清除已保存的登录凭据？",
                    isPresented: $showClearCredentialConfirm,
                    titleVisibility: .visible
                ) {
                    Button("清除", role: .destructive) {
                        let ok = CredentialStore.delete()
                        api.rememberLogin = false
                        api.clearCachedUserInfo()
                        alertMessage = ok
                            ? "已清除已保存的登录凭据。本次登录状态不受影响，下次 Cookie 过期时需重新登录。"
                            : "清除登录凭据失败，请重试"
                        showAlert = true
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("这将清除 Keychain 中保存的用户名和密码，并关闭「记住登录」选项。当前登录状态不受影响，下次启动时需要重新登录。")
                }

                Button("清除队列、作品库、登录凭据", role: .destructive) {
                    showClearAllConfirm = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .confirmationDialog(
                    "确定清除队列、作品库、登录凭据？",
                    isPresented: $showClearAllConfirm,
                    titleVisibility: .visible
                ) {
                    Button("清除", role: .destructive) {
                        queueStore.cancelAndClearAll()
                        worksStore.clearAll()
                        AppConfig.resetCustomBaseURL()
                        let ok = CredentialStore.delete()
                        api.rememberLogin = false
                        api.clearCachedUserInfo()
                        alertMessage = ok
                            ? "已清除本地数据（队列、作品库、API 地址、登录凭据）"
                            : "已清除队列和作品库数据，但清除登录凭据失败，请重试"
                        showAlert = true
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("这将清除：\n· 所有队列任务（含进行中任务）\n· 作品库记录和本地缓存图片\n· API 服务器地址（恢复默认）\n· 已保存的登录凭据\n\n远端任务不受影响。下次启动需要重新登录。并发等设置不受影响。")
                }
            }

            Section("隐私说明") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("数据发送说明")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("• 您输入的提示词（Prompt）和上传的素材文件（图片/视频），在提交任务时会发送到后端服务器进行处理。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 后端服务器地址可在本页「API 服务器」中查看和修改。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("本地存储说明")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("• 登录凭据：勾选「记住登录信息」后，用户名和密码使用 macOS Keychain 安全存储，不会写入纯文本文件。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 任务队列：队列中的任务记录保存在本地，可手动清除。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 作品库：已完成任务的结果 URL 和本地缓存图片保存在「应用程序支持」目录，可手动清除。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("数据清除")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("• 您可在本页「数据管理」中分别清除任务队列、作品库、登录凭据，或一键清除所有本地数据。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 退出登录时会自动取消所有进行中的本地队列任务，清除本地任务记录，并清除已保存的登录凭据。远端任务的运行不受影响。")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            Button("切换并重新登录", role: .destructive) { commitPendingURL() }
            Button("取消", role: .cancel) { pendingURL = nil }
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

    // MARK: - URL 变更：两阶段（先验 → 确认 → 提交）

    private func validateAndApply() {
        let trimmed = apiURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let sanitized = AppConfig.sanitizedBaseURL(trimmed) else {
            alertMessage = "无效的 URL 格式：只支持 http/https 协议，且必须包含有效的域名或 IP"
            showAlert = true
            return
        }
        beginURLChange(pending: sanitized)
    }

    private func resetToDefault() {
        let defaultString = AppConfig.defaultBaseURLString
        guard let defaultURL = AppConfig.sanitizedBaseURL(defaultString) else { return }
        apiURLString = defaultString
        beginURLChange(pending: defaultURL)
    }

    /// 第一步：记下 pendingURL，确认是否需要弹对话框
    private func beginURLChange(pending url: URL) {
        pendingURL = url
        let originChanged = url.normalizedOrigin != currentOrigin

        if originChanged && hasActiveSession {
            showHostChangeConfirm = true
        } else {
            commitPendingURL()
        }
    }

    /// 第二步：用户确认（或无会话时直接）提交
    private func commitPendingURL() {
        guard let url = pendingURL else { return }
        defer { pendingURL = nil }

        let originChanged = url.normalizedOrigin != currentOrigin

        if url.absoluteString != AppConfig.currentBaseURLString {
            if url.absoluteString == AppConfig.defaultBaseURLString {
                AppConfig.resetCustomBaseURL()
            } else {
                AppConfig.setCustomBaseURL(url.absoluteString)
            }
        }
        apiURLString = AppConfig.currentBaseURLString

        if originChanged && hasActiveSession {
            queueStore.cancelAndClearAll()
            api.resetForNewHost()
            alertMessage = "API 地址已更新，登录状态已重置，请重新登录"
        } else {
            alertMessage = "API 地址已更新"
        }
        showAlert = true
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIService.shared)
        .environmentObject(WorksStore())
        .environmentObject(GenerationQueueStore(api: APIService.shared))
}
