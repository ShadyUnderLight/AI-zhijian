import SwiftUI

struct TikTokTagManageView: View {
    @EnvironmentObject var api: APIService

    @State private var tags: [TikTokTag] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var newTagName = ""
    @State private var tagToDelete: TikTokTag?
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载标签...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundColor(.red)
                    Button("重试") {
                        loadTags()
                    }
                }
            } else {
                List {
                    ForEach(tags) { tag in
                        HStack {
                            Text(tag.name)
                            Spacer()
                            Button(role: .destructive) {
                                tagToDelete = tag
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("标签管理")
        .toolbar {
            ToolbarItem {
                Button {
                    newTagName = ""
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            VStack(spacing: 16) {
                Text("创建新标签")
                    .font(.headline)
                TextField("标签名称", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                HStack(spacing: 12) {
                    Button("取消") {
                        showCreateSheet = false
                    }
                    Button("创建") {
                        createTag()
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .frame(width: 300)
        }
        .confirmationDialog(
            tagToDelete.map { "确认删除标签「\($0.name)」？" } ?? "",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let tag = tagToDelete { deleteTag(tag) }
                tagToDelete = nil
            }
            Button("取消", role: .cancel) {
                tagToDelete = nil
            }
        } message: {
            Text("删除后，已打此标签的达人不受影响，但标签将不再可用。")
        }
        .task {
            loadTags()
        }
    }

    private func loadTags() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                tags = try await api.tiktokGetTags()
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            do {
                let tag = try await api.tiktokCreateTag(name: name)
                tags.append(tag)
                showCreateSheet = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteTag(_ tag: TikTokTag) {
        Task {
            do {
                try await api.tiktokDeleteTag(id: tag.id)
                tags.removeAll { $0.id == tag.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
