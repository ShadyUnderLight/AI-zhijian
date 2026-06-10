import SwiftUI

struct TikTokTagManageView: View {
    @EnvironmentObject var api: APIService

    @State private var tags: [TikTokTag] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var newTagName = ""

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
                                deleteTag(tag)
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
