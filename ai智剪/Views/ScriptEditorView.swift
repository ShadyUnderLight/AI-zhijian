import SwiftUI

struct ScriptEditorView: View {
    @EnvironmentObject var scriptStore: ScriptStore
    @Environment(\.dismiss) private var dismiss

    private let existing: Script?

    @State private var title: String = ""
    @State private var product: String = ""
    @State private var shots: [ScriptShot] = []

    init(script: Script?) {
        existing = script
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("脚本信息") {
                    TextField("脚本标题", text: $title)
                    TextField("带货产品", text: $product)
                }

                Section("镜头列表") {
                    ForEach(Array(shots.enumerated()), id: \.element.id) { idx, shot in
                        ShotEditorView(
                            index: idx + 1,
                            shot: Binding(
                                get: { shots[idx] },
                                set: { shots[idx] = $0 }
                            )
                        )
                    }
                    .onDelete { indexSet in
                        shots.remove(atOffsets: indexSet)
                    }

                    Button {
                        shots.append(ScriptShot(sortOrder: shots.count))
                    } label: {
                        Label("添加镜头", systemImage: "plus.circle")
                    }
                }

                if shots.isEmpty {
                    Section {
                        Text("点击「添加镜头」开始构建脚本")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil ? "新建脚本" : "编辑脚本")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(title.isEmpty || product.isEmpty)
                }
            }
            .onAppear {
                if let s = existing {
                    title = s.title
                    product = s.product
                    shots = s.shots
                }
            }
        }
    }

    private func save() {
        var s: Script
        if let existing {
            s = existing
            s.title = title
            s.product = product
            s.shots = shots
        } else {
            s = Script(title: title, product: product, shots: shots)
        }
        for i in s.shots.indices {
            s.shots[i].sortOrder = i
        }
        scriptStore.save(script: s)
    }
}

private struct ShotEditorView: View {
    let index: Int
    @Binding var shot: ScriptShot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("镜头 \(index)")
                .font(.subheadline.bold())

            TextField("镜头标题", text: $shot.title)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("参考图 Prompt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $shot.referencePrompt)
                    .font(.body)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("视频 Prompt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $shot.videoPrompt)
                    .font(.body)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}
