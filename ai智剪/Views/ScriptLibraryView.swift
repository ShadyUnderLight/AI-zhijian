import SwiftUI

struct ScriptLibraryView: View {
    @EnvironmentObject var scriptStore: ScriptStore

    @State private var editorRoute: ScriptEditorRoute?
    @State private var searchText = ""
    @State private var confirmDeleteId: Script.ID?

    private var filteredScripts: [Script] {
        let list = scriptStore.scripts
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return list }
        return list.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.product.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if scriptStore.scripts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredScripts) { script in
                        ScriptRow(script: script)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editorRoute = .edit(script.id)
                            }
                            .contextMenu {
                                Button {
                                    scriptStore.duplicate(script.id)
                                } label: {
                                    Label("复制脚本", systemImage: "doc.on.doc")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    confirmDeleteId = script.id
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { indexSet in
                        if let firstId = indexSet.map({ filteredScripts[$0].id }).first {
                            confirmDeleteId = firstId
                        }
                    }
                }
                .listStyle(.inset)
                .searchable(text: $searchText, prompt: "搜索脚本标题或产品")
                .confirmationDialog(
                    confirmDeleteId.flatMap { id in scriptStore.script(with: id).map { "删除脚本「\($0.title)」" } } ?? "",
                    isPresented: Binding(
                        get: { confirmDeleteId != nil },
                        set: { if !$0 { confirmDeleteId = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("删除", role: .destructive) {
                        if let id = confirmDeleteId {
                            scriptStore.delete(id)
                            confirmDeleteId = nil
                        }
                    }
                    Button("取消", role: .cancel) {
                        confirmDeleteId = nil
                    }
                } message: {
                    Text("删除后无法恢复")
                }
            }
        }
        .navigationTitle("脚本库")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    editorRoute = .new()
                } label: {
                    Label("新建脚本", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorRoute) { route in
            ScriptEditorView(script: route.scriptId.flatMap(scriptStore.script(with:)))
                .environmentObject(scriptStore)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "暂无脚本",
            systemImage: "doc.text",
            description: Text("点击工具栏 + 按钮创建新的带货脚本")
        )
    }
}

private struct ScriptEditorRoute: Identifiable, Equatable {
    let id: String
    let scriptId: Script.ID?

    static func new() -> ScriptEditorRoute {
        ScriptEditorRoute(id: "new-\(UUID().uuidString)", scriptId: nil)
    }

    static func edit(_ scriptId: Script.ID) -> ScriptEditorRoute {
        ScriptEditorRoute(id: "edit-\(scriptId)", scriptId: scriptId)
    }
}

private struct ScriptRow: View {
    var script: Script

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(script.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(script.product)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("· \(script.shots.count) 个镜头")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(script.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
