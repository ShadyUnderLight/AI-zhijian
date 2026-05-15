import Foundation
import SwiftUI
import OSLog

// MARK: - Workflow Step Types

enum WorkflowStepType: String, Codable, CaseIterable {
    case textInput = "文本输入"
    case promptTemplate = "提示词模板"
    case imageGen = "图片生成"
    case videoGen = "视频生成"
    case resultOutput = "结果输出"

    var icon: String {
        switch self {
        case .textInput: return "text.cursor"
        case .promptTemplate: return "text.badge.plus"
        case .imageGen: return "photo.badge.plus"
        case .videoGen: return "video.badge.plus"
        case .resultOutput: return "arrow.down.to.line"
        }
    }

    var id: Self { self }
}

// MARK: - Workflow Step Config

struct WorkflowStepConfig: Codable {
    var text: String = ""
    var promptTemplate: String = ""
    var imageGenType: String = "gpt-image"
    var imageChannel: String = "official"
    var imageAspectRatio: String = "1:1"
    var imageResolution: String = "2k"
    var imageQuality: String = "medium"
    var imagePhotoReal: Bool = false
    var videoGenType: String = "veo"
    var videoChannel: String = "budget"
    var videoModel: String = "fast"
    var videoMode: String = "text"
    var videoAspectRatio: String = "9:16"
    var videoResolution: String = "720p"
    var videoDuration: String = "8"
    var videoGenerateAudio: Bool = false
    var outputLabel: String = "最终结果"
}

// MARK: - Workflow Step

struct WorkflowStep: Identifiable, Codable {
    var id: String = UUID().uuidString
    var type: WorkflowStepType
    var label: String
    var config: WorkflowStepConfig

    init(type: WorkflowStepType, label: String? = nil, config: WorkflowStepConfig = .init()) {
        self.type = type
        self.label = label ?? type.rawValue
        self.config = config
    }
}

// MARK: - Workflow

struct Workflow: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var steps: [WorkflowStep] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String = "未命名工作流", steps: [WorkflowStep] = []) {
        self.name = name
        self.steps = steps
    }
}

// MARK: - Step Run Status

enum StepRunStatus {
    case pending
    case running
    case succeeded
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .pending: return "等待中"
        case .running: return "执行中"
        case .succeeded: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .running: return "circle.dotted"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

// MARK: - Step Result

enum StepResult: Equatable {
    case none
    case text(String)
    case images([String])
    case bananaImage(Data)
    case video(String?)

    var textValue: String? {
        if case .text(let t) = self { return t }
        return nil
    }
    var imageUrls: [String]? {
        if case .images(let urls) = self { return urls }
        return nil
    }
    var description: String {
        switch self {
        case .none: return "无"
        case .text(let t): return String(t.prefix(50))
        case .images(let urls): return urls.isEmpty ? "无图片" : "\(urls.count) 张图片"
        case .bananaImage(let d): return "已生成图片 (\(ByteCountFormatter.string(fromByteCount: Int64(d.count), countStyle: .file)))"
        case .video(let url): return url != nil ? "视频已生成" : "无视频"
        }
    }
}

// MARK: - Run State

struct WorkflowRunState {
    var isRunning = false
    var stepStates: [String: StepRunStatus] = [:]
    var stepResults: [String: StepResult] = [:]
    var stepErrors: [String: String] = [:]
    var currentStepId: String?
    var overallStatus: StepRunStatus = .pending
}

// MARK: - Veo Capacity Table (moved to VeoRules)

// MARK: - Workflow Store

@MainActor
final class WorkflowStore: ObservableObject {
    @Published var workflows: [Workflow] = []
    @Published var selectedWorkflowId: String?
    @Published var runState = WorkflowRunState()

    private let api: APIService
    private let executor: GenerationTaskExecutor
    private let logger = Logger(subsystem: "AIZhijian", category: "WorkflowStore")
    private var runTask: Task<Void, Never>?
    private var activeTaskIds: [String] = []

    private static let persistenceKey = "WorkflowStore.workflows"

    var selectedWorkflow: Workflow? {
        guard let id = selectedWorkflowId else { return nil }
        return workflows.first { $0.id == id }
    }

    init(api: APIService) {
        self.api = api
        self.executor = GenerationTaskExecutor(api: api)
        load()
    }

    // MARK: - CRUD

    func createWorkflow(name: String = "未命名工作流") -> Workflow {
        let wf = Workflow(name: name)
        workflows.append(wf)
        selectedWorkflowId = wf.id
        persist()
        return wf
    }

    func deleteWorkflow(_ id: String) {
        workflows.removeAll { $0.id == id }
        if selectedWorkflowId == id {
            selectedWorkflowId = workflows.first?.id
        }
        persist()
    }

    func saveWorkflow(_ wf: Workflow) {
        var modified = wf
        modified.updatedAt = Date()
        if let idx = workflows.firstIndex(where: { $0.id == wf.id }) {
            workflows[idx] = modified
        } else {
            workflows.append(modified)
        }
        persist()
    }

    // MARK: - Execution

    func runWorkflow(_ workflow: Workflow) {
        guard !runState.isRunning else { return }

        runState = WorkflowRunState()
        runState.isRunning = true
        runState.overallStatus = .running
        activeTaskIds.removeAll()

        for step in workflow.steps {
            runState.stepStates[step.id] = .pending
        }

        runTask = Task { [weak self] in
            guard let self else { return }
            await self.executeSteps(workflow.steps)
        }
    }

    func cancelRun() {
        runTask?.cancel()
        if let currentId = runState.currentStepId {
            runState.stepStates[currentId] = .cancelled
            removeActiveTask(for: currentId)
        }
        for (stepId, status) in runState.stepStates {
            if status == .pending {
                runState.stepStates[stepId] = .cancelled
            }
        }
        runState.currentStepId = nil
        runState.isRunning = false
        runState.overallStatus = .cancelled
    }

    // MARK: - Private Execution

    private func executeSteps(_ steps: [WorkflowStep]) async {
        defer {
            runState.isRunning = false
            runState.currentStepId = nil
            activeTaskIds.removeAll()
        }

        var lastText: String?
        var lastImages: [String]?
        var lastVideo: String?
        var lastBananaData: Data?

        for step in steps {
            guard !Task.isCancelled else {
                runState.stepStates[step.id] = .cancelled
                return
            }

            runState.currentStepId = step.id
            runState.stepStates[step.id] = .running

            do {
                let result = try await executeStep(step, lastText: lastText, lastImages: lastImages, lastVideo: lastVideo, lastBananaData: lastBananaData)
                runState.stepResults[step.id] = result
                runState.stepStates[step.id] = .succeeded

                switch result {
                case .text(let t): lastText = t
                case .images(let urls): lastImages = urls
                case .video(let url): if let url { lastVideo = url }
                case .bananaImage(let d): lastBananaData = d
                case .none: break
                }
            } catch {
                if Task.isCancelled {
                    runState.stepStates[step.id] = .cancelled
                    removeActiveTask(for: step.id)
                    return
                }
                runState.stepErrors[step.id] = error.localizedDescription
                runState.stepStates[step.id] = .failed
                runState.overallStatus = .failed
                removeActiveTask(for: step.id)
                return
            }
        }

        runState.overallStatus = .succeeded
    }

    private func executeStep(_ step: WorkflowStep, lastText: String?, lastImages: [String]?, lastVideo: String?, lastBananaData: Data?) async throws -> StepResult {
        switch step.type {
        case .textInput:
            let text = step.config.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw WorkflowError.stepFailed("文本输入步骤不能为空")
            }
            return .text(text)

        case .promptTemplate:
            let template = step.config.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !template.isEmpty else {
                throw WorkflowError.stepFailed("提示词模板不能为空")
            }
            var resolved = template
            if let prev = lastText {
                resolved = resolved.replacingOccurrences(of: "{{text}}", with: prev)
            }
            return .text(resolved)

        case .imageGen:
            guard let prompt = lastText, !prompt.isEmpty else {
                throw WorkflowError.stepFailed("图片生成需要前置步骤提供提示词文本")
            }

            if step.config.imageGenType == "banana" {
                let params = BananaJobParams(prompt: prompt, provider: "third_party", referenceImages: [])
                addActiveTask(for: step.id, type: "图片生成(Banana)", desc: String(prompt.prefix(30)))
                defer { removeActiveTask(for: step.id) }
                let output = try await exec(.banana(params), kind: .banana, label: "Banana 图片生成")
                if case .bananaImage(let data) = output { return .bananaImage(data) }
                throw WorkflowError.stepFailed("Banana 未返回图片数据")
            }

            let params = GptImageJobParams(
                prompt: prompt,
                channel: step.config.imageChannel,
                aspectRatio: step.config.imageAspectRatio,
                resolution: step.config.imageResolution,
                quality: step.config.imageQuality,
                photoReal: step.config.imagePhotoReal
            )
            addActiveTask(for: step.id, type: "图片生成(GPT)", desc: String(prompt.prefix(30)))
            defer { removeActiveTask(for: step.id) }
            let output = try await exec(.gptImage(params), kind: .gptImage, maxTicks: 60, label: "GPT 图片生成")
            if case .images(let urls) = output { return .images(urls) }
            throw WorkflowError.stepFailed("未获取到图片")

        case .videoGen:
            try await Task.sleep(nanoseconds: 500_000_000)

            switch step.config.videoGenType {
            case "veo":
                return try await executeVeoWithExecutor(step, lastText: lastText, lastImages: lastImages, lastBananaData: lastBananaData)
            case "grok":
                return try await executeGrokWithExecutor(step, lastText: lastText)
            case "seedance":
                return try await executeSeedanceWithExecutor(step, lastText: lastText)
            case "wan":
                throw WorkflowError.stepFailed("Wan 视频需要本地文件输入，暂不支持在工作流中使用")
            default:
                throw WorkflowError.stepFailed("不支持的视频生成类型: \(step.config.videoGenType)")
            }

        case .resultOutput:
            if let video = lastVideo { return .video(video) }
            if let images = lastImages { return .images(images) }
            if let bananaData = lastBananaData { return .bananaImage(bananaData) }
            if let text = lastText { return .text(text) }
            return .none
        }
    }

    // MARK: - Veo with Executor

    private func executeVeoWithExecutor(_ step: WorkflowStep, lastText: String?, lastImages: [String]?, lastBananaData: Data?) async throws -> StepResult {
        let config = step.config

        guard VeoRules.validModelValues(channel: config.videoChannel).contains(config.videoModel) else {
            throw WorkflowError.stepFailed("Veo 不支持该渠道/模型组合: \(config.videoChannel)/\(config.videoModel)")
        }
        guard VeoRules.validModeValues(channel: config.videoChannel, model: config.videoModel).contains(config.videoMode) else {
            throw WorkflowError.stepFailed("Veo 不支持该模式: \(config.videoMode) (渠道: \(config.videoChannel), 模型: \(config.videoModel))")
        }
        guard config.videoMode == "text" || config.videoMode == "image" else {
            throw WorkflowError.stepFailed("工作流暂不支持 Veo \(config.videoMode) 模式（需要本地素材），请使用文本或图生模式")
        }

        if config.videoMode != "extend" {
            let prompt = lastText ?? ""
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw WorkflowError.stepFailed("Veo 视频生成需要前置步骤提供提示词")
            }
            if config.videoChannel == "budget" && trimmed.count < 5 {
                throw WorkflowError.stepFailed("低价渠道提示词至少 5 个字符")
            }
            if trimmed.count > 8000 {
                throw WorkflowError.stepFailed("提示词过长，最多 8000 个字符")
            }
        }

        var veoParams = VeoJobParams()
        veoParams.prompt = lastText ?? ""
        veoParams.channel = config.videoChannel
        veoParams.model = config.videoModel
        veoParams.mode = config.videoMode
        veoParams.aspectRatio = config.videoAspectRatio
        veoParams.resolution = config.videoResolution
        veoParams.duration = config.videoDuration
        veoParams.generateAudio = config.videoGenerateAudio

        if config.videoMode == "image" {
            if lastBananaData != nil {
                throw WorkflowError.stepFailed("Veo 图生视频不支持 Banana 输出，请使用 GPT-Image 生成的图片")
            }
            guard let imageUrl = lastImages?.first else {
                throw WorkflowError.stepFailed("Veo 图生视频需要前置步骤提供图片")
            }
            let imageData = try await downloadImageData(from: imageUrl)
            let maxBytes = VeoRules.imageReferenceMaxBytes(channel: config.videoChannel, model: config.videoModel, mode: config.videoMode)
            guard imageData.count <= maxBytes else {
                throw WorkflowError.stepFailed("参考图片不能超过 \(maxBytes / 1024 / 1024)MB")
            }
            veoParams.imageData = imageData
            veoParams.imageName = "workflow_image.png"
            veoParams.imageMime = "image/png"
        }

        addActiveTask(for: step.id, type: "视频生成(Veo)", desc: String((lastText ?? "").prefix(30)))
        defer { removeActiveTask(for: step.id) }
        let output = try await exec(.veo(veoParams), kind: .veo, maxTicks: 120, label: "Veo 视频生成")
        if case .video(let url) = output { return .video(url) }
        throw WorkflowError.stepFailed("未获取到视频")
    }

    // MARK: - Grok with Executor

    private func executeGrokWithExecutor(_ step: WorkflowStep, lastText: String?) async throws -> StepResult {
        let config = step.config
        let prompt = lastText ?? ""

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw WorkflowError.stepFailed("Grok 视频生成需要前置步骤提供提示词")
        }
        guard trimmed.count <= 8000 else {
            throw WorkflowError.stepFailed("提示词过长，最多 8000 个字符")
        }
        guard ["text"].contains(config.videoMode) else {
            throw WorkflowError.stepFailed("Grok 工作流仅支持文生视频模式")
        }

        let params = GrokJobParams(
            prompt: prompt, channel: config.videoChannel, mode: config.videoMode,
            aspectRatio: config.videoAspectRatio, resolution: config.videoResolution,
            duration: config.videoDuration,
            imageFiles: [], videoData: nil, videoName: nil, videoMime: nil
        )
        addActiveTask(for: step.id, type: "视频生成(Grok)", desc: String(prompt.prefix(30)))
        defer { removeActiveTask(for: step.id) }
        let output = try await exec(.grok(params), kind: .grok, maxTicks: 120, label: "Grok 视频生成")
        if case .video(let url) = output { return .video(url) }
        throw WorkflowError.stepFailed("未获取到视频")
    }

    // MARK: - Seedance with Executor

    private func executeSeedanceWithExecutor(_ step: WorkflowStep, lastText: String?) async throws -> StepResult {
        let config = step.config
        let prompt = lastText ?? ""

        guard ["reference", "first_last"].contains(config.videoMode) else {
            throw WorkflowError.stepFailed("Seedance 模式无效，仅支持 reference / first_last")
        }
        guard config.videoModel == "dreamina-seedance-2-0-260128" else {
            throw WorkflowError.stepFailed("Seedance 模型无效，请重置步骤配置")
        }
        if config.videoMode == "first_last" {
            throw WorkflowError.stepFailed("Seedance 首尾帧模式需要本地图片，暂不支持在工作流中使用，请切换到 Reference 模式")
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw WorkflowError.stepFailed("Seedance 视频生成需要前置步骤提供提示词")
        }
        guard trimmed.count <= 8000 else {
            throw WorkflowError.stepFailed("提示词过长，最多 8000 个字符")
        }
        guard let dur = Int(config.videoDuration), dur >= 4, dur <= 15 else {
            throw WorkflowError.stepFailed("Seedance 时长需在 4-15 秒之间")
        }

        let params = SeedanceJobParams(
            prompt: prompt, mode: config.videoMode, model: config.videoModel,
            ratio: config.videoAspectRatio, resolution: config.videoResolution,
            duration: dur, count: 1, generateAudio: config.videoGenerateAudio, assets: []
        )
        addActiveTask(for: step.id, type: "视频生成(Seedance)", desc: String(prompt.prefix(30)))
        defer { removeActiveTask(for: step.id) }
        let output = try await exec(.seedance(params), kind: .seedance, maxTicks: 120, label: "Seedance 视频生成")
        if case .video(let url) = output { return .video(url) }
        throw WorkflowError.stepFailed("未获取到视频")
    }

    // MARK: - Executor helper with error context

    private func exec(_ params: JobParams, kind: GenerationJobKind, maxTicks: Int = 120, label: String) async throws -> GenerationOutput {
        do {
            return try await executor.executeFully(params, kind: kind, maxTicks: maxTicks)
        } catch {
            throw WorkflowError.stepFailed("\(label)失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Download Helper (with security)

    private func downloadImageData(from urlString: String) async throws -> Data {
        guard ExternalURL.sanitizedURL(urlString) != nil else {
            throw WorkflowError.stepFailed("不安全的图片 URL，仅允许 https 或受信主机")
        }
        guard let url = URL(string: urlString) else {
            throw WorkflowError.stepFailed("无效的图片URL")
        }
        // Pre-check expected content length via HEAD before downloading full body
        var headReq = URLRequest(url: url)
        headReq.httpMethod = "HEAD"
        headReq.timeoutInterval = 15
        let (_, headResponse) = try await URLSession.shared.data(for: headReq)
        if let httpResp = headResponse as? HTTPURLResponse {
            guard (200...299).contains(httpResp.statusCode) else {
                throw WorkflowError.stepFailed("下载图片失败 (HTTP \(httpResp.statusCode))")
            }
            if let lengthStr = httpResp.value(forHTTPHeaderField: "Content-Length"),
               let length = Int64(lengthStr), length > 30 * 1024 * 1024 {
                throw WorkflowError.stepFailed("图片大小超过 30MB 上限")
            }
            let ct = httpResp.value(forHTTPHeaderField: "Content-Type") ?? ""
            if !ct.isEmpty, !ct.hasPrefix("image/") {
                throw WorkflowError.stepFailed("下载内容不是图片类型 (Content-Type: \(ct))")
            }
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WorkflowError.stepFailed("下载图片失败")
        }
        guard data.count <= 30 * 1024 * 1024 else {
            throw WorkflowError.stepFailed("下载图片超过 30MB 上限")
        }
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard contentType.hasPrefix("image/") else {
            throw WorkflowError.stepFailed("下载内容不是图片类型 (Content-Type: \(contentType))")
        }
        return data
    }

    // MARK: - Active Task Sync

    private func addActiveTask(for stepId: String, type: String, desc: String) {
        api.addTask(id: stepId, type: type, desc: desc)
        activeTaskIds.append(stepId)
    }

    private func removeActiveTask(for stepId: String) {
        api.removeTask(id: stepId)
        activeTaskIds.removeAll { $0 == stepId }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(workflows) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let decoded = try? JSONDecoder().decode([Workflow].self, from: data)
        else { return }
        workflows = decoded
        if selectedWorkflowId == nil {
            selectedWorkflowId = workflows.first?.id
        }
    }
}

// MARK: - Errors

enum WorkflowError: LocalizedError {
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .stepFailed(let msg): return msg
        }
    }
}
