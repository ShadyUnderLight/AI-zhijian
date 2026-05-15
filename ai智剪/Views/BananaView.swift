import SwiftUI

struct BananaView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator
    @EnvironmentObject var presetStore: PresetStore

    @State private var prompt = ""
    @State private var provider = "third_party"
    @State private var referenceImages: [FileRef] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultImage: NSImage?
    @State private var resultImageData: Data?
    @State private var isBatchMode = false
    @State private var batchPrompts = ""
    @State private var batchMessage: String?
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var selectedPresetId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: $isBatchMode) {
                    Text("单条生成").tag(false)
                    Text("批量生成").tag(true)
                }
                .accessibilityIdentifier("banana-mode-picker")
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .onChange(of: isBatchMode) { _, _ in
                    errorMessage = nil
                    batchMessage = nil
                }

                if isBatchMode {
                    batchModeView
                } else {
                    singleModeView
                }
            }
            .padding(24)
        }
        .onAppear { applyEditIfNeeded() }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
    }

    private func applyEditIfNeeded() {
        guard let item = editCoordinator.editingItem else { return }
        guard case .banana(let p) = item.params else { return }
        isBatchMode = false
        prompt = p.prompt
        provider = p.provider
        referenceImages = p.referenceImages
        errorMessage = nil
        resultImage = nil
        resultImageData = nil
        isGenerating = false
        editCoordinator.editingItem = nil
    }

    private var singleModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("提示词").font(.headline)
                TextEditor(text: $prompt)
                    .font(.body).frame(height: 60)
                    .scrollContentBackground(.hidden).padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("提供商").font(.caption2).foregroundColor(.secondary).accessibilityIdentifier("banana-provider-label")
                    Picker("", selection: $provider) {
                        Text("官方 Gemini").tag("official")
                        Text("第三方 RunningHub").tag("third_party")
                    }.pickerStyle(.segmented)
                }
            }

            MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 3)

            presetRow

            bananaEstimateBanner

            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8); Text("生成中...")
                    } else {
                        Label("生成", systemImage: "paintbrush")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }

            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }

            if let img = resultImage {
                Divider().padding(.vertical, 4)
                LocalImageResultView(
                    image: img,
                    data: resultImageData,
                    suggestedFilename: "banana-result.png",
                    maxHeight: 400
                )
            }
        }
    }

    private var batchModeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("批量提示词").font(.headline)
                    Spacer()
                    Text("\(validBananaBatchPrompts.count) 条")
                        .font(.caption)
                        .foregroundColor(validBananaBatchPrompts.isEmpty ? .secondary : .accentColor)
                }
                TextEditor(text: $batchPrompts)
                    .font(.body).frame(height: 160)
                    .scrollContentBackground(.hidden).padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Text("每行一条提示词，共享当前提供商配置")
                    .font(.caption2).foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("提供商").font(.caption2).foregroundColor(.secondary)
                    Picker("", selection: $provider) {
                        Text("官方 Gemini").tag("official")
                        Text("第三方 RunningHub").tag("third_party")
                    }.pickerStyle(.segmented)
                }
            }

            presetRow

            bananaEstimateBanner

            HStack {
                Button(action: enqueueBananaBatch) {
                    Label("加入批量队列 (\(validBananaBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validBananaBatchPrompts.isEmpty)

                if !queueStore.items.isEmpty {
                    Text("队列: \(queueStore.pendingCount) 待提交")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let msg = batchMessage { Text(msg).font(.caption).foregroundColor(msg.contains("失败") ? .red : .green) }
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
        }
    }

    private var validBananaBatchPrompts: [String] {
        batchPrompts
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 8000 }
    }

    private var invalidBananaBatchLines: [Int] {
        let lines = batchPrompts.components(separatedBy: "\n")
        return lines.indices.compactMap { i in
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count > 8000 { return i + 1 }
            return nil
        }
    }

    private var bananaEstimateBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            let providerName = provider == "official" ? "官方 Gemini" : "第三方 RunningHub"
            let batchPrefix: String = {
                guard isBatchMode else { return "" }
                let count = validBananaBatchPrompts.count
                return count > 0 ? "\(count) 条 · " : ""
            }()
            Text("\(batchPrefix)提供商: \(providerName)")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text("费用以实际扣费为准")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    private func enqueueBananaBatch() {
        let invalidLines = invalidBananaBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validBananaBatchPrompts
        guard !prompts.isEmpty else { return }
        errorMessage = nil; batchMessage = nil

        let items = prompts.map { prompt in
            GenerationQueueItem(
                kind: .banana,
                createdAt: Date(),
                params: .banana(BananaJobParams(
                    prompt: prompt, provider: provider,
                    referenceImages: referenceImages
                ))
            )
        }
        queueStore.enqueueBatch(items)
        batchMessage = "已加入 \(items.count) 条 Banana 任务到队列"
    }

    private func startGeneration() {
        isGenerating = true; errorMessage = nil; resultImage = nil; resultImageData = nil
        Task {
            do {
                if let data = try await api.generateBanana(
                    prompt: prompt, provider: provider,
                    referenceImages: referenceImages
                ) {
                    resultImageData = data
                    resultImage = NSImage(data: data)
                } else {
                    errorMessage = "未返回图片数据"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    // MARK: - Preset

    private var presetRow: some View {
        let kind = PresetKind.banana
        let available = presetStore.presets(for: kind)
        return HStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.caption).foregroundColor(.secondary)
            if available.isEmpty {
                Text("暂无预设").font(.caption).foregroundColor(.secondary)
            } else {
                Picker("", selection: $selectedPresetId) {
                    Text("选择预设...").tag(nil as String?)
                    ForEach(available) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                }
                .pickerStyle(.menu).frame(maxWidth: 200)
                .onChange(of: selectedPresetId) { _, id in
                    guard let id, let preset = available.first(where: { $0.id == id }) else { return }
                    applyPreset(preset)
                }
            }
            Button("保存") { newPresetName = ""; showSavePresetAlert = true }
                .buttonStyle(.bordered).controlSize(.small).font(.caption)
            if let id = selectedPresetId, available.contains(where: { $0.id == id }) {
                Button("删除") { presetStore.delete(id); selectedPresetId = nil }
                    .buttonStyle(.borderless).controlSize(.small).font(.caption).foregroundColor(.red)
            }
        }
        .padding(6).background(Color.secondary.opacity(0.06)).cornerRadius(6)
        .alert("保存预设", isPresented: $showSavePresetAlert) {
            TextField("预设名称", text: $newPresetName)
            Button("取消", role: .cancel) {}
            Button("保存") {
                let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let params = PresetParams.banana(BananaPresetParams(
                    prompt: isBatchMode ? "" : prompt, provider: provider
                ))
                presetStore.save(name: name, params: params)
                selectedPresetId = presetStore.presets(for: kind).last?.id
            }
        } message: {
            Text(isBatchMode ? "仅保存当前参数配置（不包括 Prompt 和参考图片）" : "保存当前的 Prompt 和参数（不包括参考图片）")
        }
    }

    private func applyPreset(_ preset: Preset) {
        guard case .banana(let p) = preset.params else { return }
        if !isBatchMode { prompt = p.prompt }
        provider = p.provider
        errorMessage = nil; resultImage = nil; resultImageData = nil; isGenerating = false
    }
}
