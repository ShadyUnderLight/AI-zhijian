import SwiftUI

// MARK: - User Manage View

struct UserManageView: View {
    @EnvironmentObject var api: APIService

    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    // Sheet states
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var editingUser: AdminUser?
    @State private var userToDelete: AdminUser?
    @State private var showDeleteConfirm = false

    var filteredUsers: [AdminUser] {
        if searchText.isEmpty { return users }
        return users.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("用户管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    Label("新建用户", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索用户名…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

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
                Button("重试") { loadUsers() }
                    .buttonStyle(.bordered)
                Spacer()
            } else if filteredUsers.isEmpty {
                Spacer()
                ContentUnavailableView(
                    searchText.isEmpty ? "暂无用户" : "未找到匹配的用户",
                    systemImage: "person.slash",
                    description: searchText.isEmpty ? Text("点击「新建用户」创建第一个用户") : Text("尝试其他搜索关键词")
                )
                Spacer()
            } else {
                Table(filteredUsers) {
                    TableColumn("ID") { user in
                        Text("#\(user.id)")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .width(50)

                    TableColumn("用户名") { user in
                        Text(user.username)
                            .fontWeight(.medium)
                    }

                    TableColumn("角色") { user in
                        roleBadge(user.role)
                    }
                    .width(100)

                    TableColumn("审核权限") { user in
                        if let perm = user.contentAuditPermission {
                            Image(systemName: perm ? "checkmark.shield" : "shield.slash")
                                .foregroundColor(perm ? .green : .secondary)
                        } else {
                            Text("-")
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(90)

                    TableColumn("创建时间") { user in
                        Text(user.createdAt ?? "-")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    TableColumn("操作") { user in
                        HStack(spacing: 8) {
                            Button("编辑") {
                                editingUser = user
                                showEditSheet = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("删除") {
                                userToDelete = user
                                showDeleteConfirm = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                    }
                    .width(120)
                }
                .tableStyle(.bordered)
                .alternatingRowBackgrounds()
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            UserFormView(mode: .create) { user in
                users.append(user)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let user = editingUser {
                UserFormView(mode: .edit(user)) { updated in
                    if let idx = users.firstIndex(where: { $0.id == updated.id }) {
                        users[idx] = updated
                    }
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm, presenting: userToDelete) { user in
            Button("删除", role: .destructive) { deleteUser(user) }
            Button("取消", role: .cancel) { userToDelete = nil }
        } message: { user in
            Text("确定要删除用户「\(user.username)」吗？此操作不可撤销。")
        }
        .task { loadUsers() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func roleBadge(_ role: String?) -> some View {
        switch role?.uppercased() {
        case "ADMIN":
            Text("管理员")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(4)
        case "USER":
            Text("普通用户")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
        default:
            Text(role ?? "-")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Data

    private func loadUsers() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp = try await api.adminGetUsers()
                if resp.success, let users = resp.users {
                    self.users = users
                } else {
                    errorMessage = resp.message ?? "未知错误"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func deleteUser(_ user: AdminUser) {
        Task {
            do {
                let resp = try await api.adminDeleteUser(id: user.id)
                if resp.success {
                    users.removeAll { $0.id == user.id }
                } else {
                    errorMessage = resp.message ?? "删除失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - User Form Sheet

struct UserFormView: View {
    @EnvironmentObject var api: APIService

    enum Mode {
        case create
        case edit(AdminUser)

        var title: String {
            switch self {
            case .create: return "新建用户"
            case .edit: return "编辑用户"
            }
        }

        var isEdit: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    let mode: Mode
    let onSave: (AdminUser) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var role = "USER"
    @State private var contentAuditPermission = false
    @State private var isSaving = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    private let roleOptions = ["USER", "ADMIN"]

    var body: some View {
        Form {
            if case let .edit(user) = mode {
                Section {
                    HStack {
                        Text("用户名")
                        Spacer()
                        Text(user.username)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Section("账号信息") {
                    TextField("用户名", text: $username)
                        .textFieldStyle(.roundedBorder)

                    SecureField("密码", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if case .create = mode {
                        SecureField("确认密码", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Section("权限设置") {
                Picker("角色", selection: $role) {
                    ForEach(roleOptions, id: \.self) { r in
                        Text(r == "ADMIN" ? "管理员" : "普通用户").tag(r)
                    }
                }

                Toggle("内容审核权限", isOn: $contentAuditPermission)
            }

            Section {
                HStack {
                    Button("取消") { dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button(mode.isEdit ? "保存" : "创建") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                }
            }
        }
        .padding()
        .frame(width: 400)
        .alert("提示", isPresented: $showAlert, presenting: alertMessage) { _ in
            Button("确定") {}
        } message: { msg in
            Text(msg)
        }
        .onAppear {
            if case let .edit(user) = mode {
                role = user.role ?? "USER"
                contentAuditPermission = user.contentAuditPermission ?? false
            }
        }
    }

    private var canSave: Bool {
        switch mode {
        case .create:
            return !username.trimmingCharacters(in: .whitespaces).isEmpty
                && !password.isEmpty
                && password == confirmPassword
        case .edit:
            return true // editing only requires at least one field changed (handled server-side)
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                switch mode {
                case .create:
                    let resp = try await api.adminCreateUser(
                        username: username.trimmingCharacters(in: .whitespaces),
                        password: password,
                        role: role
                    )
                    if resp.success {
                        // Reload to get the created user with ID
                        let listResp = try await api.adminGetUsers()
                        if let users = listResp.users, let created = users.last {
                            onSave(created)
                        }
                        dismiss()
                    } else {
                        alertMessage = resp.message ?? "创建失败"
                        showAlert = true
                    }
                case .edit(let user):
                    let resp = try await api.adminUpdateUser(
                        id: user.id,
                        password: password.isEmpty ? nil : password,
                        role: role,
                        contentAuditPermission: contentAuditPermission
                    )
                    if resp.success {
                        // Reload to get updated user info
                        let detailResp = try await api.adminGetUser(id: user.id)
                        if let updatedUser = detailResp.user {
                            onSave(updatedUser)
                        }
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
