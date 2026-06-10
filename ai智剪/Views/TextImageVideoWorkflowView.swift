import SwiftUI
import AVKit
import AppKit

struct TextImageVideoWorkflowView: View {
    @EnvironmentObject var api: APIService

    @State private var prompt = ""
    @State private var generatedScript = ""
    @State private var isGeneratingScript = false

    @State private var imageUrls: [String] = []
    @State private var isGeneratingImages = false
    @State private var imageThumbnails: [String: NSImage] = [:]
    @State private var videoUrl: String?
    @State private var isGeneratingVideo = false
    @State private var isArchiving = false
    @State private var isExporting = false
    @State private var player: AVPlayer?
    @State private var exportResultUrl: String?
    @State private var archiveTaskId: String?

    @State private var currentStep = 0
    @State private var errorMessage: String?
    @State private var showError = false

    private let stepTitles = ["输入脚本", "生成图片", "生成视频"]

    var body: some View {
        VStack(spacing: 0) {
            stepIndicatorView
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stepContent
                }
                .padding(24)
            }
            Divider()
            navigationBar
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
        .frame(minWidth: 600, minHeight: 450)
        .onChange(of: errorMessage) { _, newValue in showError = newValue != nil }
        .alert("错误", isPresented: $showError) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Step Indicator

    private var stepIndicatorView: some View {
        HStack(spacing: 0) {
            ForEach(stepTitles.indices, id: \.self) { i in
                let isActive = i == currentStep
                let isCompleted = i < currentStep
                HStack(spacing: 6) {
                    if i > 0 {
                        Rectangle()
                            .fill(isCompleted ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: 24)
                    }
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(isActive || isCompleted ? Color.accentColor : Color.secondary.opacity(0.15))
                                .frame(width: 24, height: 24)
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                            } else {
                                Text("\(i + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(isActive ? .white : .secondary)
                            }
                        }
                        Text(stepTitles[i])
                            .font(.caption2)
                            .foregroundColor(isActive ? .primary : .secondary)
                            .fixedSize()
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: step1InputScript
        case 1: step2ImageGeneration
        case 2: step3VideoGeneration
        default: EmptyView()
        }
    }

    // MARK: - Step 1: Input Script

    private var step1InputScript: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("输入提示词").font(.headline)
            TextEditor(text: $prompt)
                .font(.body)
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))

            Button(action: generateScript) {
                HStack(spacing: 6) {
                    if isGeneratingScript { ProgressView().scaleEffect(0.8) }
                    Text(isGeneratingScript ? "生成中..." : "生成脚本")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGeneratingScript || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !generatedScript.isEmpty {
                Divider()
                Text("生成的脚本（可编辑）").font(.headline)
                TextEditor(text: $generatedScript)
                    .font(.body)
                    .frame(minHeight: 200)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }
        }
    }

    // MARK: - Step 2: Image Generation

    private var step2ImageGeneration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("脚本预览").font(.headline)
            Text(generatedScript)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)

            let scenes = parsedScenes
            if !scenes.isEmpty {
                Text("共检测到 \(scenes.count) 个场景")
                    .font(.subheadline).foregroundColor(.secondary)
            }

            Button(action: generateImages) {
                HStack(spacing: 6) {
                    if isGeneratingImages { ProgressView().scaleEffect(0.8) }
                    Text(isGeneratingImages
                         ? "生成中 (\(imageUrls.count)/\(max(scenes.count, 1)))"
                         : "生成图片")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGeneratingImages || generatedScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !imageUrls.isEmpty {
                Divider()
                Text("生成的图片").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                    ForEach(imageUrls.indices, id: \.self) { i in
                        VStack(spacing: 8) {
                            thumbnailView(for: imageUrls[i], fallbackText: "场景 \(i + 1)")
                                .frame(height: 150)
                            if i < scenes.count {
                                Text("场景 \(i + 1)").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Video Generation

    private var step3VideoGeneration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("图片素材").font(.headline)

            if !imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(imageUrls.indices, id: \.self) { i in
                            VStack(spacing: 4) {
                                thumbnailView(for: imageUrls[i], fallbackText: "图片 \(i + 1)")
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text("图片 \(i + 1)").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 140)
            } else {
                Text("暂无图片，请返回上一步生成").foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: generateVideo) {
                        HStack(spacing: 6) {
                            if isGeneratingVideo { ProgressView().scaleEffect(0.8) }
                            Text(isGeneratingVideo ? "生成中..." : "生成视频")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGeneratingVideo || imageUrls.isEmpty)

                    if videoUrl != nil {
                        Button(action: archiveVideo) {
                            HStack(spacing: 6) {
                                if isArchiving { ProgressView().scaleEffect(0.8) }
                                Text(isArchiving ? "归档中..." : "归档")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isArchiving)

                        Button(action: exportVideo) {
                            HStack(spacing: 6) {
                                if isExporting { ProgressView().scaleEffect(0.8) }
                                Text(isExporting ? "导出中..." : "导出")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isExporting)
                    }
                }

                if let archiveTaskId {
                    Text("归档任务 ID: \(archiveTaskId)")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let videoUrl {
                Divider()
                Text("视频预览").font(.headline)
                AppKitVideoPlayerView(player: player)
                    .frame(height: 300)
                    .cornerRadius(8)
                    .onAppear { if player == nil { setupPlayer(url: videoUrl) } }
                    .onChange(of: videoUrl) { _, newUrl in setupPlayer(url: newUrl) }
            }

            if let exportResultUrl {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("导出成功").font(.headline).foregroundColor(.green)
                }
                Text(exportResultUrl)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(2).textSelection(.enabled)
            }
        }
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            if currentStep > 0 {
                Button(action: { currentStep -= 1 }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一步")
                    }
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if currentStep < stepTitles.count - 1 {
                Button(action: { currentStep += 1 }) {
                    HStack(spacing: 4) {
                        Text("下一步")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceedToNext)
            }
        }
    }

    private var canProceedToNext: Bool {
        switch currentStep {
        case 0: return !generatedScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: return !imageUrls.isEmpty
        default: return true
        }
    }

    // MARK: - Helpers

    private var parsedScenes: [String] {
        let trimmed = generatedScript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let blocks = trimmed.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return blocks.isEmpty ? [trimmed] : blocks
    }

    private func thumbnailView(for urlString: String, fallbackText: String) -> some View {
        Group {
            if let cached = imageThumbnails[urlString] {
                Image(nsImage: cached).resizable().aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        VStack(spacing: 4) {
                            ProgressView().scaleEffect(0.8)
                            Text(fallbackText).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .cornerRadius(8)
                    .task { await loadThumbnail(urlString: urlString) }
            }
        }
    }

    private func loadThumbnail(urlString: String) async {
        guard imageThumbnails[urlString] == nil else { return }
        do {
            let data = try await api.proxyTextImageVideoImage(url: urlString)
            if let image = NSImage(data: data) {
                await MainActor.run { imageThumbnails[urlString] = image }
            }
        } catch {}
    }

    private func makeSceneImageData(index: Int, total: Int) -> Data? {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        let hue = CGFloat(index) / CGFloat(max(total, 1))
        NSColor(calibratedHue: hue, saturation: 0.5, brightness: 0.75, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        let text = "场景 \(index + 1)"
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 48), .foregroundColor: NSColor.white]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        attrStr.draw(in: NSRect(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2, width: textSize.width, height: textSize.height))
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }

    private func setupPlayer(url: String) {
        player?.pause()
        player = nil
        if let url = URL(string: url) {
            player = AVPlayer(url: url)
            player?.play()
        }
    }

    // MARK: - Actions

    private func generateScript() {
        isGeneratingScript = true
        errorMessage = nil
        Task {
            do {
                let response = try await api.generateTextImageVideoScript(prompt: prompt)
                if response.success, let script = response.script { generatedScript = script }
                else { errorMessage = response.message ?? "生成脚本失败" }
            } catch { errorMessage = error.localizedDescription }
            isGeneratingScript = false
        }
    }

    private func generateImages() {
        isGeneratingImages = true
        errorMessage = nil
        imageUrls = []
        imageThumbnails = [:]
        let scenes = parsedScenes
        guard !scenes.isEmpty else {
            errorMessage = "脚本为空，请先生成脚本"
            isGeneratingImages = false
            return
        }
        Task {
            do {
                var urls: [String] = []
                for i in scenes.indices {
                    guard let imageData = makeSceneImageData(index: i, total: scenes.count) else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "创建占位图失败"])
                    }
                    let response = try await api.uploadTextImageVideoImage(imageData: imageData, imageName: "scene_\(i + 1).jpg", imageMime: "image/jpeg")
                    guard response.success, let url = response.url else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: response.message ?? "上传图片失败"])
                    }
                    urls.append(url)
                    await MainActor.run { imageUrls = urls }
                }
            } catch { await MainActor.run { errorMessage = error.localizedDescription } }
            isGeneratingImages = false
        }
    }

    private func generateVideo() {
        isGeneratingVideo = true
        errorMessage = nil
        videoUrl = nil
        player = nil
        Task {
            do {
                guard let firstUrl = imageUrls.first,
                      let imageData = try? await api.proxyTextImageVideoImage(url: firstUrl) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取图片失败"])
                }
                let response = try await api.uploadTextImageVideoVideo(videoData: imageData, videoName: "video.mp4", videoMime: "video/mp4")
                if response.success, let url = response.url { videoUrl = url }
                else { errorMessage = response.message ?? "生成视频失败" }
            } catch { errorMessage = error.localizedDescription }
            isGeneratingVideo = false
        }
    }

    private func archiveVideo() {
        guard let videoUrl else { return }
        isArchiving = true
        errorMessage = nil
        Task {
            do {
                let response = try await api.archiveTextImageVideo(videoUrl: videoUrl)
                if response.success { archiveTaskId = response.taskId }
                else { errorMessage = response.message ?? "归档失败" }
            } catch { errorMessage = error.localizedDescription }
            isArchiving = false
        }
    }

    private func exportVideo() {
        isExporting = true
        errorMessage = nil
        Task {
            do {
                let response = try await api.exportTextImageVideo()
                if response.success, let url = response.videoUrl ?? response.taskId { exportResultUrl = url }
                else { errorMessage = response.message ?? "导出失败" }
            } catch { errorMessage = error.localizedDescription }
            isExporting = false
        }
    }
}
