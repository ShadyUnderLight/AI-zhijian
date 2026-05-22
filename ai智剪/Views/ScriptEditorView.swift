import SwiftUI

struct ScriptEditorView: View {
    @EnvironmentObject var scriptStore: ScriptStore
    @Environment(\.dismiss) private var dismiss

    private let existing: Script?

    @State private var title: String = ""
    @State private var product: String = ""
    @State private var shots: [ScriptShot] = []
    @State private var deleteShotId: String?

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
                    ForEach($shots) { $shot in
                        ShotEditorView(
                            index: (shots.firstIndex(where: { $0.id == shot.id }) ?? 0) + 1,
                            shot: $shot
                        )
                        .swipeActions(edge: .trailing) {
                            Button("删除", role: .destructive) {
                                deleteShotId = shot.id
                            }
                        }
                        .swipeActions(edge: .leading) {
                            let idx = shots.firstIndex(where: { $0.id == shot.id }) ?? 0
                            if idx > 0 {
                                Button("上移") {
                                    shots.move(fromOffsets: IndexSet(integer: idx), toOffset: idx - 1)
                                }
                            }
                            if idx < shots.count - 1 {
                                Button("下移") {
                                    shots.move(fromOffsets: IndexSet(integer: idx), toOffset: idx + 2)
                                }
                            }
                        }
                    }
                    .onMove { from, to in
                        shots.move(fromOffsets: from, toOffset: to)
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || product.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        .confirmationDialog("确认删除镜头", isPresented: Binding(
            get: { deleteShotId != nil },
            set: { if !$0 { deleteShotId = nil } }
        ), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let id = deleteShotId {
                    shots.removeAll { $0.id == id }
                    deleteShotId = nil
                }
            }
            Button("取消", role: .cancel) {
                deleteShotId = nil
            }
        } message: {
            Text("删除后镜头内容无法恢复")
        }
    }

    private func save() {
        var s: Script
        if let existing {
            s = existing
            s.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            s.product = product.trimmingCharacters(in: .whitespacesAndNewlines)
            s.shots = shots
        } else {
            s = Script(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                product: product.trimmingCharacters(in: .whitespacesAndNewlines),
                shots: shots
            )
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

    @State private var refPromptCopied = false
    @State private var vidPromptCopied = false
    @State private var refCopyGen = 0
    @State private var vidCopyGen = 0
    @State private var promptToClear: PromptKind?

    private enum PromptKind {
        case reference, video
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("镜头 \(index)")
                    .font(.subheadline.bold())
                Spacer()
                fillStatusIcon
            }

            TextField("镜头标题", text: $shot.title)
                .textFieldStyle(.roundedBorder)

            promptSection(
                title: "参考图 Prompt",
                text: $shot.referencePrompt,
                copied: $refPromptCopied,
                generation: $refCopyGen,
                promptKind: .reference
            )

            promptSection(
                title: "视频 Prompt",
                text: $shot.videoPrompt,
                copied: $vidPromptCopied,
                generation: $vidCopyGen,
                promptKind: .video
            )
        }
        .padding(.vertical, 4)
        .confirmationDialog("确认清空 Prompt", isPresented: Binding(
            get: { promptToClear != nil },
            set: { if !$0 { promptToClear = nil } }
        ), titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                switch promptToClear {
                case .reference: shot.referencePrompt = ""
                case .video: shot.videoPrompt = ""
                case nil: break
                }
                promptToClear = nil
            }
            Button("取消", role: .cancel) {
                promptToClear = nil
            }
        } message: {
            Text("清空后内容无法恢复，确定要清空吗？")
        }
    }

    @ViewBuilder
    private func promptSection(
        title: String,
        text: Binding<String>,
        copied: Binding<Bool>,
        generation: Binding<Int>,
        promptKind: PromptKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(text.wrappedValue.count) 字符")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            HStack {
                Spacer()
                copyButton(text: text.wrappedValue, copied: copied, generation: generation)
                Button("清空", role: .destructive) {
                    promptToClear = promptKind
                }
                .disabled(text.wrappedValue.isEmpty)
                .controlSize(.small)
            }
        }
    }

    private func copyButton(text: String, copied: Binding<Bool>, generation: Binding<Int>) -> some View {
        Button {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(text, forType: .string) else { return }
            copied.wrappedValue = true
            let myGen = generation.wrappedValue + 1
            generation.wrappedValue = myGen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard generation.wrappedValue == myGen else { return }
                copied.wrappedValue = false
            }
        } label: {
            Label(copied.wrappedValue ? "已复制" : "复制",
                  systemImage: copied.wrappedValue ? "checkmark" : "doc.on.doc")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @ViewBuilder
    private var fillStatusIcon: some View {
        let refFilled = !shot.referencePrompt
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let vidFilled = !shot.videoPrompt
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if refFilled && vidFilled {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        } else if refFilled || vidFilled {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        } else {
            Image(systemName: "circle")
                .foregroundColor(.secondary.opacity(0.4))
                .font(.caption)
        }
    }
}
