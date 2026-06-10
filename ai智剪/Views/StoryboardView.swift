import SwiftUI
import UniformTypeIdentifiers

// MARK: - Storyboard Display Model

struct StoryboardSceneDisplay: Identifiable {
    let id: String
    let sceneIndex: Int
    let prompt: String
    let taskId: String
    var imageUrl: String?
    var status: GenerationQueueStatus
    var errorMessage: String?
}

// MARK: - Storyboard View

struct StoryboardView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var worksStore: WorksStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator

    // MARK: - Mode

    @State private var isHDMode = false

    // MARK: - Common State

    @State private var productImage: FileRef?
    @State private var productImagePreview: NSImage?
    @State private var channel = "official"
    @State private var resolution = "2k"
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var currentBatchId: UUID?

    // MARK: - Standard Mode

    @State private var shotCount: Double = 4
    @State private var llmProvider = "deepseek"
    @State private var resolutionLevel = "high"
    @State private var imageModel = "gpt-image-2"
    @State private var supplementPrompt = ""

    // MARK: - HD Mode

    @State private var productDescription = ""
    @State private var segmentCount: Double = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Mode picker
                Picker("", selection: $isHDMode) {
                    Text("标准故事板").tag(false)
                    Text("高密度故事板").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .onChange(of: isHDMode) { _, _ in
                    errorMessage = nil
                }

                if isHDMode {
                    hdModeView
                } else {
                    standardModeView
                }
            }
            .padding(24)
        }
        .frame(minWidth: 500)
    }

    // MARK: - Standard Mode View

    private var standardModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            productImageRow

            VStack(alignment: .leading, spacing: 6) {
                Text("分镜数量: \(Int(shotCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $shotCount, in: 1...8, step: 1)
                    .frame(maxWidth: 280)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("补充提示词（可选）")
                    .font(.headline)
                TextEditor(text: $supplementPrompt)
                    .font(.body)
                    .frame(height: 60)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

            parameterRow

            // Generate
            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8)
                        Text("生成中...")
                    } else {
                        Label("生成故事板", systemImage: "rectangle.split.3x3")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(productImage == nil || isGenerating)
            }

            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption)
            }

            // Scenes display
            scenesGrid
        }
    }

    // MARK: - HD Mode View

    private var hdModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            productImageRow

            VStack(alignment: .leading, spacing: 6) {
                Text("产品描述（必填）")
                    .font(.headline)
                TextEditor(text: $productDescription)
                    .font(.body)
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("段落数: \(Int(segmentCount))（每段 6 镜头）")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $segmentCount, in: 1...4, step: 1)
                    .frame(maxWidth: 280)
            }

            HStack(spacing: 16) {
                optionPicker("渠道", selection: $channel, options: [
                    ("official", "官方"),
                    ("budget", "低价")
                ])
                optionPicker("分辨率", selection: $resolution, options: [
                    ("1k", "1K"), ("2k", "2K"), ("4k", "4K")
                ])
            }

            HStack {
                Button(action: startGeneration) {
                    if isGenerating {
                        ProgressView().scaleEffect(0.8)
                        Text("生成中...")
                    } else {
                        Label("生成高密度故事板", systemImage: "rectangle.stack.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(productImage == nil || productDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }

            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption)
            }

            // Scenes display
            hdScenesGrid
        }
    }

    // MARK: - Product Image Picker

    private var productImageRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("产品参考图").font(.headline)

            HStack(spacing: 8) {
                if let preview = productImagePreview {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Button("选择图片...") {
                        pickProductImage()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if let file = productImage {
                        Text(file.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Button("清除") {
                        productImage = nil
                        productImagePreview = nil
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(productImage == nil)
                }
            }
        }
    }

    private func pickProductImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            guard let contentType = values.contentType, contentType.conforms(to: .image) else {
                errorMessage = "请选择图片文件"
                return
            }
            let fileSize = values.fileSize ?? 0
            guard fileSize > 0 else {
                errorMessage = "文件为空"
                return
            }
            guard fileSize <= 25 * 1024 * 1024 else {
                errorMessage = "图片大小不能超过 25MB"
                return
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            productImage = FileRef(data: data, name: url.lastPathComponent, mime: url.mimeType())
            productImagePreview = NSImage(data: data)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Parameter Row

    private var parameterRow: some View {
        HStack(spacing: 16) {
            optionPicker("渠道", selection: $channel, options: [
                ("official", "官方"),
                ("budget", "低价")
            ])
            optionPicker("分辨率", selection: $resolution, options: [
                ("1k", "1K"), ("2k", "2K"), ("4k", "4K")
            ])
            optionPicker("精细度", selection: $resolutionLevel, options: [
                ("low", "低"), ("medium", "中"), ("high", "高")
            ])
            optionPicker("LLM", selection: $llmProvider, options: [
                ("deepseek", "DeepSeek"),
                ("gemini", "Gemini")
            ])
        }
    }

    // MARK: - Scenes Display (Standard)

    private var scenesGrid: some View {
        let scenes = displayScenes
        guard !scenes.isEmpty else { return AnyView(EmptyView()) }

        let total = scenes.count
        let completed = scenes.filter { $0.status == .succeeded }.count

        return AnyView(VStack(alignment: .leading, spacing: 12) {
            // Progress header
            HStack {
                Text("分镜结果")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if completed < total {
                    ProgressView(value: Double(completed), total: Double(total))
                        .frame(width: 80)
                }
            }

            // Scene cards
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300))], spacing: 12) {
                ForEach(scenes) { scene in
                    sceneCard(scene)
                }
            }

            // Action buttons
            if completed == total {
                HStack(spacing: 8) {
                    Button("全部重新生成") {
                        fullRetry()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        })
    }

    // MARK: - Scenes Display (HD)

    private var hdScenesGrid: some View {
        let scenes = displayScenes
        guard !scenes.isEmpty else { return AnyView(EmptyView()) }

        let total = scenes.count
        let completed = scenes.filter { $0.status == .succeeded }.count
        let segmentSize = 6

        return AnyView(VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("高密度分镜结果")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if completed < total {
                    ProgressView(value: Double(completed), total: Double(total))
                        .frame(width: 80)
                }
            }

            // Group by segment (every 6 scenes)
            let grouped = Dictionary(grouping: scenes) { $0.sceneIndex / segmentSize }
            ForEach(Array(grouped.keys.sorted()), id: \.self) { segment in
                let segmentScenes = grouped[segment]!.sorted { $0.sceneIndex < $1.sceneIndex }
                VStack(alignment: .leading, spacing: 8) {
                    Text("第 \(segment + 1) 段")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Divider()

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 260))], spacing: 10) {
                        ForEach(segmentScenes) { scene in
                            sceneCard(scene)
                        }
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }

            if completed == total {
                HStack(spacing: 8) {
                    Button("全部重新生成") {
                        fullRetry()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        })
    }

    // MARK: - Scene Card

    @ViewBuilder
    private func sceneCard(_ scene: StoryboardSceneDisplay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Scene index + status
            HStack {
                Text("镜头 \(scene.sceneIndex + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                statusBadge(scene.status)
            }

            // Image or placeholder
            if let imageUrl = scene.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .cornerRadius(6)
                    case .failure:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 100)
                            .overlay(Image(systemName: "photo.badge.exclamationmark").foregroundColor(.secondary))
                    case .empty:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 100)
                            .overlay(ProgressView().scaleEffect(0.8))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 100)
                    .overlay(
                        Group {
                            if scene.status == .polling {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if scene.status == .failed {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                    .cornerRadius(6)
            }

            // AI prompt
            Text(scene.prompt)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Error message
            if let error = scene.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            // Retry button
            if scene.status == .failed {
                Button("重试") {
                    retryScene(scene)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
    }

    // MARK: - Status Badge

    @ViewBuilder
    private func statusBadge(_ status: GenerationQueueStatus) -> some View {
        switch status {
        case .polling:
            Text("生成中")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(4)
        case .succeeded:
            Text("完成")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .cornerRadius(4)
        case .failed:
            Text("失败")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(4)
        default:
            Text(status.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .foregroundColor(.secondary)
                .cornerRadius(4)
        }
    }

    // MARK: - Display Scenes (computed from queue)

    private var displayScenes: [StoryboardSceneDisplay] {
        guard let batchId = currentBatchId else { return [] }
        let batchItems = queueStore.items.filter { $0.batchId == batchId }
        return batchItems.compactMap { item -> StoryboardSceneDisplay? in
            guard case .gptStoryboardScene(let p) = item.params else { return nil }
            return StoryboardSceneDisplay(
                id: item.id,
                sceneIndex: p.sceneIndex,
                prompt: p.scenePrompt,
                taskId: item.taskId ?? p.storyboardBatchId,
                imageUrl: item.resultUrls.first,
                status: item.status,
                errorMessage: item.errorMessage
            )
        }
        .sorted { $0.sceneIndex < $1.sceneIndex }
    }

    // MARK: - Generate

    private func startGeneration() {
        guard let productImage else {
            errorMessage = "请先选择产品参考图"
            return
        }

        isGenerating = true
        errorMessage = nil

        let batchId = UUID()

        Task {
            do {
                if isHDMode {
                    try await startHDGeneration(productImage: productImage, batchId: batchId)
                } else {
                    try await startStandardGeneration(productImage: productImage, batchId: batchId)
                }
            } catch {
                errorMessage = error.localizedDescription
                isGenerating = false
            }
        }
    }

    private func startStandardGeneration(productImage: FileRef, batchId: UUID) async throws {
        let response = try await api.generateStoryboard(
            productImage: productImage,
            prompt: supplementPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : supplementPrompt,
            productDescription: nil,
            shotCount: Int(shotCount),
            channel: channel,
            resolution: resolution,
            resolutionLevel: resolutionLevel,
            llmProvider: llmProvider,
            imageModel: imageModel
        )

        guard response.success, let scenes = response.scenes else {
            throw APIError.requestFailed(response.message ?? "故事板生成失败")
        }

        await MainActor.run {
            currentBatchId = batchId
            let items: [GenerationQueueItem] = scenes.map { scene in
                GenerationQueueItem(
                    kind: .gptStoryboardScene,
                    status: .polling,
                    taskId: scene.ourTaskId,
                    createdAt: Date(),
                    params: .gptStoryboardScene(GptStoryboardSceneJobParams(
                        sceneIndex: scene.sceneIndex,
                        scenePrompt: scene.prompt,
                        channel: channel,
                        resolution: resolution,
                        storyboardBatchId: batchId.uuidString,
                        referenceImages: [productImage]
                    ))
                )
            }
            queueStore.enqueueBatch(items, batchId: batchId, batchName: "故事板 - \(productImage.name)")
            isGenerating = false
        }
    }

    private func startHDGeneration(productImage: FileRef, batchId: UUID) async throws {
        let response = try await api.generateHDStoryboard(
            productImage: productImage,
            productDescription: productDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            segmentCount: Int(segmentCount),
            channel: channel,
            resolution: resolution,
            imageModel: imageModel
        )

        guard response.success, let scenes = response.scenes else {
            throw APIError.requestFailed(response.message ?? "高密度故事板生成失败")
        }

        await MainActor.run {
            currentBatchId = batchId
            let items: [GenerationQueueItem] = scenes.map { scene in
                GenerationQueueItem(
                    kind: .gptStoryboardScene,
                    status: .polling,
                    taskId: scene.ourTaskId,
                    createdAt: Date(),
                    params: .gptStoryboardScene(GptStoryboardSceneJobParams(
                        sceneIndex: scene.sceneIndex,
                        scenePrompt: scene.prompt,
                        channel: channel,
                        resolution: resolution,
                        storyboardBatchId: batchId.uuidString,
                        referenceImages: [productImage]
                    ))
                )
            }
            queueStore.enqueueBatch(items, batchId: batchId, batchName: "高密度故事板 - \(productImage.name)")
            isGenerating = false
        }
    }

    // MARK: - Retry

    private func retryScene(_ scene: StoryboardSceneDisplay) {
        // 单个分镜重试：创建一个新的 .gptImage 任务，使用分镜提示词 + 原产品图作为参考图
        guard let batchId = currentBatchId,
              let originalItem = queueStore.items.first(where: { $0.id == scene.id }),
              case .gptStoryboardScene(let params) = originalItem.params else {
            return
        }

        let newItem = GenerationQueueItem(
            kind: .gptImage,
            createdAt: Date(),
            params: .gptImage(GptImageJobParams(
                prompt: params.scenePrompt,
                channel: params.channel,
                aspectRatio: "16:9",
                resolution: params.resolution,
                quality: "high",
                photoReal: false,
                referenceImages: params.referenceImages
            ))
        )
        queueStore.enqueue(newItem)
    }

    private func fullRetry() {
        // 清除当前批次，重新生成
        if let batchId = currentBatchId {
            let itemsToCancel = queueStore.items.filter { $0.batchId == batchId && $0.isActive }
            for item in itemsToCancel {
                queueStore.cancelPendingItem(item.id)
            }
        }
        currentBatchId = nil
        startGeneration()
    }

    // MARK: - Helper

    private func optionPicker(_ label: String, selection: Binding<String>, options: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Picker(label, selection: selection) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 100)
        }
    }
}


