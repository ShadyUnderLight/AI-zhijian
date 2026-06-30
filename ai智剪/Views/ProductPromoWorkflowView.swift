import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers

// MARK: - Type Contracts

/// 促销工作流输入
struct PromoPromptInput {
    let background: String
    let placementSurface: String

    var isValid: Bool {
        !background.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !placementSurface.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// 提示词模板 — enum for immutability
enum PromoPromptTemplates {
    static let gptImage: String = """
【任务目标】
根据我提供的产品参考图，生成一张真实感产品展示图。

【主体内容】
将每一个产品摆放一份，并排放在【摆放平面】上，三袋完正面朝向镜头，间距自然，构图居中，像短视频带货里的产品展示定格画面。

【背景场景】
背景为【背景】。
整体环境要真实、干净、生活化，像普通人日常拍摄的短视频场景。

【产品一致性要求】
必须严格保持参考图中的产品包装一致，包括品牌、颜色、袋型结构、图案、文字区域、产品名称和整体外观。
不要改包装，不要换颜色，不要变形，
三份产品必须是对应产品的完全相同复制版本，外观一致、尺寸一致、包装一致。

【产品尺寸要求】
注意产品尺寸必须真实合理，符合正常袋装茶商品大小，与【摆放平面】、周围物体和背景空间的比例自然可信。
不要把产品做得过大，不要像巨型展示样品。
也不要把产品做得过小，不要像迷你模型或玩具。
产品大小应接近真实可手持袋装茶商品的尺寸。

【构图与镜头要求】
产品位于画面中下部或中部区域，主体清晰突出。
镜头正对产品，轻微生活化透视即可。
背景可以柔和一些，但不要过度虚化，仍然要保留真实空间感。

【画面风格要求】
整体风格真实、清爽、生活化，像 TikTok / 短视频平台里的产品展示画面。
不要奢华棚拍感，不要过度商业广告感，不要电影感，不要夸张打光。

【禁止内容】
不要任何文字贴片、折扣标签、促销文案、倒计时、emoji、字幕、水印、评论区、账号名或界面元素。
不要无关人物，不要无关产品，不要杂乱道具喧宾夺主。
"""

    static let defaultVeoPromptA: String = """
参考图生成视频：保持产品、包装、数量、位置、场景、背景和光线不变。三袋产品先静止摆放在原位置，随后一只手从画面侧面自然伸入，依次在三袋产品前方各点一下，像在逐个介绍这三袋产品。手部动作从左到右依次完成，每次只在对应包装前轻轻点一下，不要触碰、推动或遮挡产品太久。产品始终完整可见，不变形、不换包装、不晃动、不破损、不消失。动作结束后手自然离开画面，镜头保持稳定，整体像真实短视频里自然展示产品的画面。
"""

    static let defaultVeoPromptB: String = """
参考图生成视频：保持产品、包装、数量、位置、场景、背景和光线不变。三袋产品先静止摆放在原位置，随后一个人站在产品后方，对着镜头自然出镜，手里拿着一杯已经泡好的茶。人物先把茶杯举到嘴边自然喝一口，再把茶杯放低，面对镜头露出满意的表情并竖起大拇指点赞。人物动作自然流畅，不要夸张表演，不要长时间遮挡产品。产品始终完整可见，不变形、不换包装、不晃动、不破损、不消失。镜头保持稳定，整体像真实短视频里自然展示饮用体验的画面。
"""

    static func assembleGPTImagePrompt(from input: PromoPromptInput) -> String {
        gptImage
            .replacingOccurrences(of: "【背景】", with: input.background.trimmingCharacters(in: .whitespacesAndNewlines))
            .replacingOccurrences(of: "【摆放平面】", with: input.placementSurface.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Veo 参数默认值 — enum for immutability
enum PromoVeoDefaults {
    static let channel = "official"
    static let model = "lite"
    static let mode = "image"
    static let aspectRatio = "9:16"
    static let resolution = "720p"
    static let duration = "8"

    static func params(prompt: String, imageData: Data) -> VeoParams {
        var p = VeoParams()
        p.channel = channel
        p.model = model
        p.mode = mode
        p.aspectRatio = aspectRatio
        p.resolution = resolution
        p.duration = duration
        p.prompt = prompt
        p.imageData = imageData
        p.imageName = "first_frame.jpg"
        p.imageMime = "image/jpeg"
        return p
    }
}

// MARK: - 促销工作流 View

struct ProductPromoWorkflowView: View {
    @EnvironmentObject var api: APIService

    // MARK: - Step 1 State

    @State private var background = ""
    @State private var placementSurface = ""
    @State private var productImageRefs: [FileRef] = []
    @State private var firstFrameUrl: String?
    @State private var firstFrameImageData: Data?
    @State private var isGeneratingFirstFrame = false

    // MARK: - Step 2 State

    @State private var veoPromptA = PromoPromptTemplates.defaultVeoPromptA
    @State private var veoPromptB = PromoPromptTemplates.defaultVeoPromptB
    @State private var isGeneratingVideos = false
    @State private var videoATaskId: String?
    @State private var videoBTaskId: String?
    @State private var videoAUrl: String?
    @State private var videoBUrl: String?

    // MARK: - Step 3 State

    @State private var playerA: AVPlayer?
    @State private var playerB: AVPlayer?
    @State private var isExportingA = false
    @State private var isExportingB = false

    // MARK: - General

    @State private var currentStep = 0
    @State private var errorMessage: String?
    @State private var showError = false

    private let stepTitles = ["输入参数", "生成视频", "预览导出"]

    // MARK: - Body

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
        .frame(minWidth: 640, minHeight: 520)
        .onDisappear { playerA?.pause(); playerB?.pause() }
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

    // MARK: - Step Content Router

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: step1InputParams
        case 1: step2GenerateVideos
        case 2: step3PreviewExport
        default: EmptyView()
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
        case 0: return firstFrameUrl != nil
        case 1: return videoAUrl != nil && videoBUrl != nil
        default: return true
        }
    }

    // MARK: - Step 1: Input Parameters

    private var step1InputParams: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("输入参数").font(.title3).bold()

            VStack(alignment: .leading, spacing: 6) {
                Text("背景描述").font(.headline)
                TextEditor(text: $background)
                    .font(.body)
                    .frame(minHeight: 56, maxHeight: 76)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if background.isEmpty {
                            Text("例：木质桌面、白色墙壁、自然光线下")
                                .font(.body).foregroundColor(.secondary).padding(10).allowsHitTesting(false)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("摆放平面").font(.headline)
                TextEditor(text: $placementSurface)
                    .font(.body)
                    .frame(minHeight: 56, maxHeight: 76)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if placementSurface.isEmpty {
                            Text("例：干净的木质桌面")
                                .font(.body).foregroundColor(.secondary).padding(10).allowsHitTesting(false)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("产品参考图（1-3 张）").font(.headline)
                HStack(spacing: 8) {
                    ForEach(productImageRefs.indices, id: \.self) { i in
                        if let nsImage = NSImage(data: productImageRefs[i].data) {
                            Image(nsImage: nsImage)
                                .resizable().aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    Button(action: pickProductImages) {
                        Label(
                            productImageRefs.isEmpty ? "选择图片" : "重新选择",
                            systemImage: "photo.on.rectangle.angled"
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !productImageRefs.isEmpty {
                Button(action: generateFirstFrame) {
                    HStack(spacing: 6) {
                        if isGeneratingFirstFrame { ProgressView().scaleEffect(0.8) }
                        Text(isGeneratingFirstFrame ? "生成中..." : "生成首帧参考图")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGeneratingFirstFrame ||
                           background.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                           placementSurface.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let firstFrameUrl {
                Divider()
                Text("首帧参考图").font(.headline)
                AsyncImage(url: URL(string: firstFrameUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300).cornerRadius(8)
                    case .failure:
                        Text("加载失败").foregroundColor(.red)
                    default:
                        ProgressView()
                    }
                }
            }
        }
    }

    // MARK: - File Picker

    private func pickProductImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.begin { response in
            guard response == .OK else { return }
            let urls = Array(panel.urls.prefix(3))
            var refs: [FileRef] = []
            for url in urls {
                if let ref = try? FileRef.loadImage(from: url) {
                    refs.append(ref)
                }
            }
            guard !refs.isEmpty else {
                errorMessage = "无法读取所选图片，请重试"
                return
            }
            productImageRefs = refs
        }
    }

    // MARK: - Generate First Frame

    private func generateFirstFrame() {
        let input = PromoPromptInput(background: background, placementSurface: placementSurface)
        guard input.isValid, !productImageRefs.isEmpty else {
            errorMessage = "请填写背景、摆放平面并选择产品参考图"
            return
        }
        isGeneratingFirstFrame = true
        errorMessage = nil
        firstFrameUrl = nil
        firstFrameImageData = nil
        videoAUrl = nil
        videoBUrl = nil
        videoATaskId = nil
        videoBTaskId = nil

        let prompt = PromoPromptTemplates.assembleGPTImagePrompt(from: input)

        Task {
            do {
                let submitResponse = try await api.generateImageToImage(
                    prompt: prompt,
                    channel: "official",
                    aspectRatio: "9:16",
                    resolution: "2k",
                    quality: "medium",
                    referenceImages: productImageRefs
                )
                guard let taskId = submitResponse.ourTaskId ?? submitResponse.taskId else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片生成任务提交失败"])
                }
                let imageUrl = try await pollImageUntilDone(taskId: taskId)
                if let url = URL(string: imageUrl),
                   let (data, _) = try? await URLSession.shared.data(from: url) {
                    await MainActor.run { firstFrameImageData = data }
                }
                await MainActor.run { firstFrameUrl = imageUrl }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isGeneratingFirstFrame = false }
        }
    }

    private func pollImageUntilDone(taskId: String) async throws -> String {
        var lastUrl: String?
        for _ in 0..<60 {
            let poll = try await api.pollImageTask(taskId)
            if poll.isTerminalSuccess(for: .image) {
                if let url = poll.imageResultUrls.first { return url }
                lastUrl = poll.imageResultUrls.first
                break
            }
            if poll.isTerminalFailure(for: .image) {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: poll.errorMessage ?? "图片生成失败"])
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        if let url = lastUrl { return url }
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片生成超时（3分钟），请重试"])
    }

    // MARK: - Step 2: Generate Videos

    private var step2GenerateVideos: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("首帧参考图").font(.title3).bold()

            if let firstFrameUrl {
                AsyncImage(url: URL(string: firstFrameUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 260).cornerRadius(8)
                    case .failure:
                        Text("加载失败").foregroundColor(.red)
                    default:
                        ProgressView()
                    }
                }
            } else {
                Text("请先返回上一步生成首帧图").foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("视频 A 提示词（手部展示）").font(.headline)
                TextEditor(text: $veoPromptA)
                    .font(.body)
                    .frame(minHeight: 80, maxHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("视频 B 提示词（人物展示）").font(.headline)
                TextEditor(text: $veoPromptB)
                    .font(.body)
                    .frame(minHeight: 80, maxHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }

            Button(action: generateBothVideos) {
                HStack(spacing: 6) {
                    if isGeneratingVideos { ProgressView().scaleEffect(0.8) }
                    Text(isGeneratingVideos ? "生成中..." : "生成两个视频")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGeneratingVideos || firstFrameImageData == nil ||
                       veoPromptA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                       veoPromptB.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if isGeneratingVideos {
                if let taskIdA = videoATaskId {
                    Text("视频 A 任务: \(taskIdA.prefix(8))...").font(.caption).foregroundColor(.secondary)
                }
                if let taskIdB = videoBTaskId {
                    Text("视频 B 任务: \(taskIdB.prefix(8))...").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Generate Both Videos (Parallel)

    private func generateBothVideos() {
        guard let imageData = firstFrameImageData else {
            errorMessage = "缺少首帧图片数据，请返回上一步重新生成"
            return
        }
        isGeneratingVideos = true
        errorMessage = nil
        videoATaskId = nil
        videoBTaskId = nil
        videoAUrl = nil
        videoBUrl = nil

        let promptA = veoPromptA.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptB = veoPromptB.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                // Submit both tasks
                async let taskIdA: String = submitVeoVideo(prompt: promptA, imageData: imageData)
                async let taskIdB: String = submitVeoVideo(prompt: promptB, imageData: imageData)
                let (idA, idB) = try await (taskIdA, taskIdB)
                await MainActor.run {
                    videoATaskId = idA
                    videoBTaskId = idB
                }

                // Poll both independently — each failure is tracked separately
                async let urlA: String = pollVeoVideoUntilDone(taskId: idA)
                async let urlB: String = pollVeoVideoUntilDone(taskId: idB)

                var errors: [String] = []
                do {
                    let result = try await urlA
                    await MainActor.run { videoAUrl = result }
                } catch {
                    errors.append("视频A: \(error.localizedDescription)")
                }
                do {
                    let result = try await urlB
                    await MainActor.run { videoBUrl = result }
                } catch {
                    errors.append("视频B: \(error.localizedDescription)")
                }

                if !errors.isEmpty {
                    await MainActor.run { errorMessage = errors.joined(separator: "\n") }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isGeneratingVideos = false }
        }
    }

    private func submitVeoVideo(prompt: String, imageData: Data) async throws -> String {
        let veoParams = PromoVeoDefaults.params(prompt: prompt, imageData: imageData)
        let submitResponse = try await api.generateVeoVideo(params: veoParams)
        guard let taskId = submitResponse.ourTaskId ?? submitResponse.taskId else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "视频生成任务提交失败"])
        }
        return taskId
    }

    private func pollVeoVideoUntilDone(taskId: String) async throws -> String {
        for _ in 0..<120 {
            let poll = try await api.pollVeoTask(taskId)
            if poll.isTerminalSuccess(for: .veo) {
                if let url = poll.videoResultUrl { return url }
                break
            }
            if poll.isTerminalFailure(for: .veo) {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: poll.errorMessage ?? "视频生成失败"])
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "视频生成超时（6分钟），请重试"])
    }

    // MARK: - Step 3: Preview & Export

    private var step3PreviewExport: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频预览").font(.title3).bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("视频 A — 手部展示").font(.headline)
                if let videoAUrl {
                    AppKitVideoPlayerView(player: playerA)
                        .frame(height: 280)
                        .cornerRadius(8)
                        .onAppear { if playerA == nil { setupPlayerA(url: videoAUrl) } }
                        .onChange(of: videoAUrl) { _, newUrl in setupPlayerA(url: newUrl) }
                    Button(action: exportVideoA) {
                        HStack(spacing: 6) {
                            if isExportingA { ProgressView().scaleEffect(0.8) }
                            Text(isExportingA ? "导出中..." : "导出视频 A")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isExportingA)
                } else {
                    Text("视频 A 尚未生成").foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("视频 B — 人物展示").font(.headline)
                if let videoBUrl {
                    AppKitVideoPlayerView(player: playerB)
                        .frame(height: 280)
                        .cornerRadius(8)
                        .onAppear { if playerB == nil { setupPlayerB(url: videoBUrl) } }
                        .onChange(of: videoBUrl) { _, newUrl in setupPlayerB(url: newUrl) }
                    Button(action: exportVideoB) {
                        HStack(spacing: 6) {
                            if isExportingB { ProgressView().scaleEffect(0.8) }
                            Text(isExportingB ? "导出中..." : "导出视频 B")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isExportingB)
                } else {
                    Text("视频 B 尚未生成").foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Player Setup

    private func setupPlayerA(url: String) {
        playerA?.pause(); playerA = nil
        if let u = URL(string: url) { playerA = AVPlayer(url: u); playerA?.play() }
    }

    private func setupPlayerB(url: String) {
        playerB?.pause(); playerB = nil
        if let u = URL(string: url) { playerB = AVPlayer(url: u); playerB?.play() }
    }

    // MARK: - Export

    private func exportVideo(label: String, urlString: String?, isExporting: Binding<Bool>) {
        guard let urlString, let url = URL(string: urlString) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "促销视频-\(label)-\(df.string(from: Date())).mp4"
        panel.begin { response in
            if response == .OK, let dest = panel.url {
                isExporting.wrappedValue = true
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        try data.write(to: dest)
                    } catch {
                        await MainActor.run { errorMessage = "导出失败: \(error.localizedDescription)" }
                    }
                    await MainActor.run { isExporting.wrappedValue = false }
                }
            }
        }
    }

    private func exportVideoA() { exportVideo(label: "A", urlString: videoAUrl, isExporting: $isExportingA) }
    private func exportVideoB() { exportVideo(label: "B", urlString: videoBUrl, isExporting: $isExportingB) }
}

// MARK: - Preview

#Preview {
    ProductPromoWorkflowView()
        .environmentObject(APIService.shared)
}
