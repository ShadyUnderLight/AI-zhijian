import SwiftUI

// MARK: - API Key Manage View

struct ApiKeyManageView: View {
    @EnvironmentObject var api: APIService

    @State private var keys: [AdminApiKey] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Sheet states
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var editingKey: AdminApiKey?
    @State private var keyToDelete: AdminApiKey?
    @State private var showDeleteConfirm = false

    // Authorization
    @State private var selectedKeyForAuth: AdminApiKey?
    @State private var showAuthSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("API Key 管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    Label("新建 Key", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            if isLoading {
                Spacer()
                ProgressView("加载中…")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                Button("重试") { loadKeys() }
                    .buttonStyle(.bordered)
                Spacer()
            } else if keys.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "暂无 API Key",
                    systemImage: "key.slash",
                    description: Text("点击「新建 Key」创建第一个 API Key")
                )
                Spacer()
            } else {
                Table(keys) {
                    TableColumn("名称") { key in
                        Text(key.name)
                            .fontWeight(.medium)
                    }

                    TableColumn("Key 值") { key in
                        if let kv = key.keyValue, kv.count > 10 {
                            Text(String(kv.prefix(10)) + "******")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        } else if let kv = key.keyValue {
                            Text(kv)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        } else {
                            Text("-")
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(160)

                    TableColumn("最大任务数") { key in
                        Text(key.maxTasks.map(String.init) ?? "-")
                            .foregroundColor(.secondary)
                    }
                    .width(100)

                    TableColumn("运行中任务") { key in
                        Text(key.activeTaskCount.map(String.init) ?? "0")
                            .foregroundColor(.secondary)
                    }
                    .width(100)

                    TableColumn("创建时间") { key in
                        Text(key.createdAt ?? "-")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    TableColumn("操作") { key in
                        HStack(spacing: 6) {
                            Button("授权") {
                                selectedKeyForAuth = key
                                showAuthSheet = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("编辑") {
                                editingKey = key
                                showEditSheet = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("删除") {
                                keyToDelete = key
                                showDeleteConfirm = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                    }
                    .width(180)
                }
                .tableStyle(.bordered)
                .alternatingRowBackgrounds()
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            ApiKeyFormView(mode: .create) { newKey in
                keys.append(newKey)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let key = editingKey {
                ApiKeyFormView(mode: .edit(key)) { updated in
                    if let idx = keys.firstIndex(where: { $0.id == updated.id }) {
                        keys[idx] = updated
                    }
                }
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            if let key = selectedKeyForAuth {
                ApiKeyAuthView(apiKey: key)
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm, presenting: keyToDelete) { key in
            Button("删除", role: .destructive) { deleteKey(key) }
            Button("取消", role: .cancel) { keyToDelete = nil }
        } message: { key in
            Text("确定要删除 API Key「\(key.name)」吗？相关授权也将一并撤销。")
        }
        .task { loadKeys() }
    }

    // MARK: - Data

    private func loadKeys() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp = try await api.adminGetApiKeys()
                if resp.success, let keys = resp.keys {
                    self.keys = keys
                } else {
                    errorMessage = resp.message ?? "未知错误"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func deleteKey(_ key: AdminApiKey) {
        Task {
            do {
                let resp = try await api.adminDeleteApiKey(id: key.id)
                if resp.success {
                    keys.removeAll { $0.id == key.id }
                } else {
                    errorMessage = resp.message ?? "删除失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - API Key Form Sheet

struct ApiKeyFormView: View {
    @EnvironmentObject var api: APIService

    enum Mode {
        case create
        case edit(AdminApiKey)

        var title: String {
            switch self {
            case .create: return "新建 API Key"
            case .edit: return "编辑 API Key"
            }
        }

        var isEdit: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    let mode: Mode
    let onSave: (AdminApiKey) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var keyValue = ""
    @State private var workflowConfig = ""
    @State private var maxTasks = 5
    @State private var isSaving = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("名称", text: $name)
                    .textFieldStyle(.roundedBorder)

                if case .create = mode {
                    TextField("Key 值（留空则后端自动生成）", text: $keyValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }
            }

            Section("配置") {
                TextField("工作流配置", text: $workflowConfig)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("最大并发任务数")
                    Spacer()
                    Stepper(value: $maxTasks, in: 1...50) {
                        Text("\(maxTasks)")
                            .font(.body.monospaced())
                            .frame(width: 30)
                    }
                }
            }

            Section {
                HStack {
                    Button("取消") { dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button(mode.isEdit ? "保存" : "创建") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 420)
        .alert("提示", isPresented: $showAlert, presenting: alertMessage) { _ in
            Button("确定") {}
        } message: { msg in
            Text(msg)
        }
        .onAppear {
            if case let .edit(key) = mode {
                name = key.name
                workflowConfig = key.workflowConfig ?? ""
                maxTasks = key.maxTasks ?? 5
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                switch mode {
                case .create:
                    let resp = try await api.adminCreateApiKey(
                        name: name.trimmingCharacters(in: .whitespaces),
                        keyValue: keyValue.isEmpty ? nil : keyValue,
                        workflowConfig: workflowConfig.isEmpty ? nil : workflowConfig,
                        maxTasks: maxTasks
                    )
                    if resp.success, let newKey = resp.apiKey {
                        onSave(newKey)
                        dismiss()
                    } else {
                        alertMessage = resp.message ?? "创建失败"
                        showAlert = true
                    }
                case .edit(let key):
                    let resp = try await api.adminUpdateApiKey(
                        id: key.id,
                        name: name.trimmingCharacters(in: .whitespaces),
                        workflowConfig: workflowConfig.isEmpty ? nil : workflowConfig,
                        maxTasks: maxTasks
                    )
                    if resp.success, let updatedKey = resp.apiKey {
                        onSave(updatedKey)
                        dismiss()
                    } else {
                        alertMessage = resp.message ?? "更新失败"
                        showAlert = true
                    }
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isSaving = false
        }
    }
}

// MARK: - API Key Authorization Sheet

struct ApiKeyAuthView: View {
    @EnvironmentObject var api: APIService
    let apiKey: AdminApiKey

    @Environment(\.dismiss) private var dismiss

    @State private var authorizedUsers: [AdminAuthorizedUser] = []
    @State private var allUsers: [AdminUser] = []
    @State private var selectedUserIds: Set<Int> = []
    @State private var isLoadingUsers = true
    @State private var alertMessage: String?
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("授权管理 — \(apiKey.name)")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()

            if isLoadingUsers {
                ProgressView("加载用户列表…")
                    .padding()
                Spacer()
            } else {
                List {
                    Section("已授权用户") {
                        if authorizedUsers.isEmpty {
                            Text("暂无已授权用户")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                        ForEach(authorizedUsers) { user in
                            HStack {
                                Text(user.username)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("撤销") {
                                    revoke(userId: user.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .foregroundColor(.red)
                            }
                        }
                    }

                    Section("添加授权") {
                        if allUsers.isEmpty {
                            Text("暂无可用用户")
                                .foregroundColor(.secondary)
                        }
                        ForEach(allUsers) { user in
                            HStack {
                                Text(user.username)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if authorizedUsers.contains(where: { $0.id == user.id }) {
                                    Text("已授权")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Button("授权") {
                                        grant(userId: user.id)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 400, height: 400)
        .alert("提示", isPresented: $showAlert, presenting: alertMessage) { _ in
            Button("确定") {}
        } message: { msg in
            Text(msg)
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoadingUsers = true

        // Load authorized users
        if let resp = try? await api.adminGetAuthorizedUsers(apiKeyId: apiKey.id),
           resp.success, let users = resp.users {
            authorizedUsers = users
        }

        // Load all users for grant list
        if let resp = try? await api.adminGetUsers(),
           resp.success, let users = resp.users {
            allUsers = users
        }

        isLoadingUsers = false
    }

    private func grant(userId: Int) {
        Task {
            do {
                let resp = try await api.adminGrantApiKey(userId: userId, apiKeyId: apiKey.id)
                if resp.success {
                    await loadData()
                } else {
                    alertMessage = resp.message ?? "授权失败"
                    showAlert = true
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func revoke(userId: Int) {
        Task {
            do {
                let resp = try await api.adminRevokeApiKey(userId: userId, apiKeyId: apiKey.id)
                if resp.success {
                    await loadData()
                } else {
                    alertMessage = resp.message ?? "撤销失败"
                    showAlert = true
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
