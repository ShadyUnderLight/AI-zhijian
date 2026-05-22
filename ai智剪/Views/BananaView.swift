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
    @State private var showBatchConfirm = false
    @StateObject private var preflight = GenerationPreflightService()

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
        .onAppear { applyEditIfNeeded(); applyRecordIfNeeded(); triggerPreflight() }
        .onChange(of: editCoordinator.editingItem?.id) { _, _ in applyEditIfNeeded() }
        .onChange(of: editCoordinator.applyRecord?.id) { _, _ in applyRecordIfNeeded() }
        .onChange(of: provider) { _, _ in triggerPreflight() }
        .onChange(of: isBatchMode) { _, _ in triggerPreflight() }
        .onChange(of: validBananaBatchPrompts.count) { _, _ in triggerPreflight() }
        .onChange(of: referenceImages.count) { _, _ in triggerPreflight() }
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

    private func applyRecordIfNeeded() {
        guard let record = editCoordinator.applyRecord else { return }
        defer { editCoordinator.applyRecord = nil }
        guard let snapshot = record.paramsSnapshot,
              let data = snapshot.data(using: .utf8),
              let params = try? JSONDecoder().decode(WorkRecordParams.self, from: data),
              case .banana(let providerVal) = params
        else { return }
        isBatchMode = false
        prompt = record.prompt
        provider = providerVal
        referenceImages = []
        errorMessage = nil
        resultImage = nil
        resultImageData = nil
        isGenerating = false
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

            preflightBanner()

            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8); Text("生成中...")
                    } else {
                        Label("生成", systemImage: "paintbrush")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || preflight.state.isBlocking)
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

            preflightBanner()

            HStack {
                Button(action: prepareBananaBatchConfirm) {
                    Label("加入批量队列 (\(validBananaBatchPrompts.count))", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validBananaBatchPrompts.isEmpty || preflight.state.isBlocking)
                .confirmationDialog(
                    "确认批量提交",
                    isPresented: $showBatchConfirm,
                    titleVisibility: .visible
                ) {
                    Button("确认提交 \(validBananaBatchPrompts.count) 条任务") {
                        enqueueBananaBatch()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("Banana 图片生成 · \(provider == "third_party" ? "第三方" : "官方")\n并发数: \(queueStore.concurrencyLimit)\n费用以实际扣费为准")
                }

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

    @ViewBuilder
    private func preflightBanner() -> some View {
        switch preflight.state {
        case .ready(let info):
            preflightReadyBanner(info)
        case .insufficient(let info):
            preflightInsufficientBanner(info)
        case .loading:
            preflightLoadingBanner()
        case .error(let message):
            preflightErrorBanner(message)
        case .unavailable, .idle:
            fallbackBanner()
        }
    }

    private func preflightReadyBanner(_ info: GenerationPreflightService.Result) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundColor(.green)
            let countText = info.itemCount > 1 ? "\(info.itemCount) 条 · " : ""
            Text("\(countText)预计费用: $\(info.estimatedPriceUsd)")
                .font(.caption2)
                .foregroundColor(.secondary)
            if info.estimatedDurationSeconds > 0 {
                Text("· 预计耗时: \(formatDuration(info.estimatedDurationSeconds))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("以实际扣费为准")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(Color.green.opacity(0.08))
        .cornerRadius(6)
    }

    private func preflightInsufficientBanner(_ info: GenerationPreflightService.Result) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundColor(.orange)
            Text("预计费用: $\(info.estimatedPriceUsd)")
                .font(.caption2)
                .foregroundColor(.secondary)
            if let reason = info.blockingReasons.first {
                Text("· \(reason)")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            Spacer()
            Text("请充值后再提交")
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .padding(6)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(6)
    }

    private func preflightLoadingBanner() -> some View {
        HStack(spacing: 4) {
            ProgressView().scaleEffect(0.6)
            Text("正在估算费用...")
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

    private func preflightErrorBanner(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text("费用以实际扣费为准")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(Color.orange.opacity(0.06))
        .cornerRadius(6)
    }

    private func fallbackBanner() -> some View {
        let providerName = provider == "official" ? "官方 Gemini" : "第三方 RunningHub"
        let batchPrefix: () -> String = {
            guard isBatchMode else { return "" }
            let count = validBananaBatchPrompts.count
            return count > 0 ? "\(count) 条 · " : ""
        }
        return HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(batchPrefix())提供商: \(providerName)")
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

    private func triggerPreflight() {
        let params = BananaJobParams(prompt: "", provider: provider, referenceImages: referenceImages)
        if isBatchMode {
            let count = validBananaBatchPrompts.count
            if count == 0 {
                preflight.reset()
                return
            }
            preflight.scheduleBatch(for: Array(repeating: .banana(params), count: count))
        } else {
            preflight.schedule(for: .banana(params))
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)秒" }
        if seconds < 3600 { return "\(seconds / 60)分\(seconds % 60)秒" }
        return "\(seconds / 3600)小时\(seconds % 3600 / 60)分"
    }

    private func prepareBananaBatchConfirm() {
        let invalidLines = invalidBananaBatchLines
        if !invalidLines.isEmpty {
            batchMessage = "第 \(invalidLines.map(String.init).joined(separator: ", ")) 行超过 8000 字符上限"
            return
        }
        let prompts = validBananaBatchPrompts
        guard !prompts.isEmpty else { return }

        let batchParams = prompts.map { prompt in
            JobParams.banana(BananaJobParams(prompt: prompt, provider: provider, referenceImages: referenceImages))
        }
        Task {
            let pfState = await preflight.preflightNowBatch(for: batchParams)
            if pfState.isBlocking {
                if case .insufficient(let info) = pfState {
                    batchMessage = "余额不足（预估 $\(info.estimatedPriceUsd)），请充值后再提交"
                } else if case .error(let msg) = pfState {
                    batchMessage = msg
                }
                return
            }
            batchMessage = nil
            showBatchConfirm = true
        }
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
                let pfParams = BananaJobParams(prompt: prompt, provider: provider, referenceImages: referenceImages)
                let pfState = await preflight.preflightNow(for: .banana(pfParams))
                if pfState.isBlocking {
                    if case .insufficient(let info) = pfState {
                        errorMessage = "余额不足（预估 $\(info.estimatedPriceUsd)），请充值后再提交"
                    } else if case .error(let msg) = pfState {
                        errorMessage = msg
                    }
                    isGenerating = false
                    return
                }

                if let data = try await api.generateBanana(
                    prompt: prompt, provider: provider,
                    referenceImages: referenceImages
                ) {
                    resultImageData = data
                    resultImage = NSImage(data: data)
                    let item = GenerationQueueItem(
                        kind: .banana,
                        createdAt: Date(),
                        params: .banana(BananaJobParams(
                            prompt: prompt,
                            provider: provider,
                            referenceImages: referenceImages
                        ))
                    )
                    queueStore.recordCompletedSingle(item, imageData: data)
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
