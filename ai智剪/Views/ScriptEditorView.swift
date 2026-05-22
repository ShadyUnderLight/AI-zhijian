import SwiftUI
import OSLog
import UniformTypeIdentifiers

fileprivate enum ScriptEditorFocusedField: Hashable {
    case title
    case product
    case shotTitle(_ shotId: String)
    case referencePrompt(_ shotId: String)
    case videoPrompt(_ shotId: String)
}

struct ScriptEditorView: View {
    @EnvironmentObject var scriptStore: ScriptStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @Environment(\.dismiss) private var dismiss
    private let logger = Logger(subsystem: "AIZhijian", category: "ScriptEditor")

    private let existing: Script?

    @FocusState private var focusedField: ScriptEditorFocusedField?
    @State private var didClearInitialFocus = false

    @State private var title: String = ""
    @State private var product: String = ""
    @State private var shots: [ScriptShot] = []
    @State private var deleteShotId: String?
    @State private var exportError: String?
    @State private var sendValidationError: String?
    @State private var showDeleteConfirm = false

    private var currentTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validationErrorMessage: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写脚本标题"
        }
        if product.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写带货产品"
        }
        return nil
    }

    init(script: Script?) {
        existing = script
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("脚本信息") {
                    TextField("脚本标题", text: $title)
                        .focused($focusedField, equals: .title)
                    TextField("带货产品", text: $product)
                        .focused($focusedField, equals: .product)
                }

                Section("镜头列表") {
                    ForEach($shots) { $shot in
                        ShotEditorView(
                            index: (shots.firstIndex(where: { $0.id == shot.id }) ?? 0) + 1,
                            shot: $shot,
                            focusedField: $focusedField,
                            onSendToGen: { prompt, kind in
                                sendToGeneration(prompt: prompt, kind: kind)
                            }
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

                ToolbarItem(placement: .automatic) {
                    Button {
                        exportMarkdown()
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .help("导出为 Markdown")
                }

                if existing != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除脚本", systemImage: "trash")
                        }
                        .help("删除当前脚本")
                    }
                }
            }
            .onAppear {
                if let s = existing {
                    title = s.title
                    product = s.product
                    shots = normalizeShotIDs(s.shots)
                }

                guard !didClearInitialFocus else { return }
                didClearInitialFocus = true
                clearInitialFocus()
            }
        }
        .confirmationDialog("确认删除镜头", isPresented: Binding(
            get: { deleteShotId != nil },
            set: { if !$0 { deleteShotId = nil } }
        ), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let id = deleteShotId, let idx = shots.firstIndex(where: { $0.id == id }) {
                    shots.remove(at: idx)
                    deleteShotId = nil
                }
            }
            Button("取消", role: .cancel) {
                deleteShotId = nil
            }
        } message: {
            Text("删除后镜头内容无法恢复")
        }
        .confirmationDialog(
            (currentTitle.isEmpty ? existing?.title : currentTitle).map { "删除脚本「\($0)」" } ?? "",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let id = existing?.id {
                    scriptStore.delete(id)
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后脚本内容无法恢复")
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        ), actions: {
            Button("确定") { exportError = nil }
        }, message: {
            Text(exportError ?? "")
        })
        .alert("提示", isPresented: Binding(
            get: { sendValidationError != nil },
            set: { if !$0 { sendValidationError = nil } }
        ), actions: {
            Button("确定") { sendValidationError = nil }
        }, message: {
            Text(sendValidationError ?? "")
        })
    }

    private func clearInitialFocus() {
        focusedField = nil
        DispatchQueue.main.async {
            focusedField = nil
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

    private func exportMarkdown() {
        let md = Self.makeMarkdown(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            product: product.trimmingCharacters(in: .whitespacesAndNewlines),
            shots: shots
        )
        let filename = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let panel = NSSavePanel()
        panel.title = "导出脚本"
        panel.nameFieldStringValue = filename.isEmpty ? "未命名脚本.md" : "\(filename).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try md.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportError = "写入文件失败：\(error.localizedDescription)"
        }
    }

    static func makeMarkdown(title: String, product: String, shots: [ScriptShot]) -> String {
        var md = "# \(title)\n\n"
        if !product.isEmpty {
            md += "**带货产品**: \(product)\n\n"
        }
        for (i, shot) in shots.enumerated() {
            md += "## 镜头 \(i + 1)"
            if !shot.title.isEmpty { md += "：\(shot.title)" }
            md += "\n\n"
            if !shot.referencePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += "### 参考图 Prompt\n\n\(shot.referencePrompt)\n\n"
            }
            if !shot.videoPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += "### 视频 Prompt\n\n\(shot.videoPrompt)\n\n"
            }
        }
        return md
    }

    private func sendToGeneration(prompt: String, kind: GenerationJobKind) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let msg = validationErrorMessage {
            sendValidationError = msg
            return
        }
        save()
        let shotTitle = shots.first { $0.referencePrompt == prompt || $0.videoPrompt == prompt }?.title ?? ""
        editCoordinator.prefillPrompt = EditTaskCoordinator.PrefillPrompt(
            text: prompt, kind: kind, sourceShotTitle: shotTitle
        )
        editCoordinator.navigateToKind = kind
        dismiss()
    }

    private func normalizeShotIDs(_ shots: [ScriptShot]) -> [ScriptShot] {
        var seen = Set<String>()
        return shots.map { s in
            var shot = s
            if shot.id.isEmpty || seen.contains(shot.id) {
                shot.id = UUID().uuidString
            }
            seen.insert(shot.id)
            return shot
        }
    }
}

private struct ShotEditorView: View {
    let index: Int
    @Binding var shot: ScriptShot
    var focusedField: FocusState<ScriptEditorFocusedField?>.Binding
    var onSendToGen: ((String, GenerationJobKind) -> Void)?

    @State private var isExpanded = true
    @State private var refPromptCopied = false
    @State private var vidPromptCopied = false
    @State private var refCopyGen = 0
    @State private var vidCopyGen = 0
    @State private var promptToClear: PromptKind?

    private enum PromptKind {
        case reference, video
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("镜头标题", text: $shot.title)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: .shotTitle(shot.id))

                promptSection(
                    title: "参考图 Prompt",
                    text: $shot.referencePrompt,
                    copied: $refPromptCopied,
                    generation: $refCopyGen,
                    promptKind: .reference,
                    shotId: shot.id,
                    genButton: referenceGenButton
                )

                promptSection(
                    title: "视频 Prompt",
                    text: $shot.videoPrompt,
                    copied: $vidPromptCopied,
                    generation: $vidCopyGen,
                    promptKind: .video,
                    shotId: shot.id,
                    genButton: videoGenButton
                )
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Text("镜头 \(index)")
                    .font(.subheadline.bold())
                if !shot.title.isEmpty {
                    Text("：\(shot.title)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                fillStatusIcon
            }
        }
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
    private var referenceGenButton: some View {
        let trimmed = shot.referencePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        Button {
            onSendToGen?(shot.referencePrompt, .gptImage)
        } label: {
            Label("用作参考图", systemImage: "photo.badge.plus")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(trimmed.isEmpty)
    }

    @ViewBuilder
    private var videoGenButton: some View {
        let trimmed = shot.videoPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        Menu {
            Button("Seedance 视频", systemImage: "video") {
                onSendToGen?(shot.videoPrompt, .seedance)
            }
            Button("Wan 视频", systemImage: "film") {
                onSendToGen?(shot.videoPrompt, .wan)
            }
            Button("Veo 视频", systemImage: "globe") {
                onSendToGen?(shot.videoPrompt, .veo)
            }
            Button("Grok 视频", systemImage: "brain") {
                onSendToGen?(shot.videoPrompt, .grok)
            }
        } label: {
            Label("用作视频", systemImage: "video.badge.plus")
                .font(.caption)
        }
        .disabled(trimmed.isEmpty)
    }

    @ViewBuilder
    private func promptSection(
        title: String,
        text: Binding<String>,
        copied: Binding<Bool>,
        generation: Binding<Int>,
        promptKind: PromptKind,
        shotId: String,
        genButton: some View
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
                .focused(focusedField, equals: promptKind == .reference ? .referencePrompt(shotId) : .videoPrompt(shotId))
                .font(.body)
                .frame(minHeight: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            HStack {
                genButton
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
                .accessibilityLabel("参考图和视频 Prompt 已填写")
        } else if refFilled || vidFilled {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
                .accessibilityLabel("参考图和视频 Prompt 部分填写")
        } else {
            Image(systemName: "circle")
                .foregroundColor(.secondary.opacity(0.4))
                .font(.caption)
                .accessibilityLabel("参考图和视频 Prompt 未填写")
        }
    }
}
