import SwiftUI

struct ScriptLibraryView: View {
    @EnvironmentObject var scriptStore: ScriptStore

    @State private var showEditor = false
    @State private var editingScript: Script?

    var body: some View {
        VStack(spacing: 0) {
            if scriptStore.scripts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(scriptStore.scripts) { script in
                        ScriptRow(script: script)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingScript = script
                                showEditor = true
                            }
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { scriptStore.scripts[$0].id }
                        for id in ids {
                            scriptStore.delete(id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("脚本库")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    editingScript = nil
                    showEditor = true
                } label: {
                    Label("新建脚本", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ScriptEditorView(script: editingScript)
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
