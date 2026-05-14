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

    var displayName: String {
        switch self {
        case .pending: return "等待中"
        case .running: return "执行中"
        case .succeeded: return "已完成"
        case .failed: return "失败"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .running: return "circle.dotted"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Step Result

enum StepResult: Equatable {
    case none
    case text(String)
    case images([String])
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

// MARK: - Workflow Store

@MainActor
final class WorkflowStore: ObservableObject {
    @Published var workflows: [Workflow] = []
    @Published var selectedWorkflowId: String?
    @Published var runState = WorkflowRunState()

    private let api: APIService
    private let logger = Logger(subsystem: "AIZhijian", category: "WorkflowStore")
    private var runTask: Task<Void, Never>?

    private static let persistenceKey = "WorkflowStore.workflows"

    var selectedWorkflow: Workflow? {
        guard let id = selectedWorkflowId else { return nil }
        return workflows.first { $0.id == id }
    }

    init(api: APIService) {
        self.api = api
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
        runState.isRunning = false
        runState.overallStatus = .failed
    }

    // MARK: - Private Execution

    private func executeSteps(_ steps: [WorkflowStep]) async {
        var lastText: String?
        var lastImages: [String]?

        for step in steps {
            guard !Task.isCancelled else { return }

            runState.currentStepId = step.id
            runState.stepStates[step.id] = .running

            do {
                let result = try await executeStep(step, lastText: lastText, lastImages: lastImages)
                runState.stepResults[step.id] = result
                runState.stepStates[step.id] = .succeeded

                switch result {
                case .text(let t): lastText = t
                case .images(let urls): lastImages = urls
                case .video: break
                case .none: break
                }
            } catch {
                if Task.isCancelled { return }
                runState.stepErrors[step.id] = error.localizedDescription
                runState.stepStates[step.id] = .failed
                runState.overallStatus = .failed
                runState.isRunning = false
                return
            }
        }

        runState.overallStatus = .succeeded
        runState.isRunning = false
        runState.currentStepId = nil
    }

    private func executeStep(_ step: WorkflowStep, lastText: String?, lastImages: [String]?) async throws -> StepResult {
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
                let data = try await api.generateBanana(
                    prompt: prompt, provider: "third_party", referenceImages: []
                )
                if data != nil {
                    return .images([])
                }
                throw WorkflowError.stepFailed("Banana 未返回图片数据")
            }

            let result = try await api.generateImage(
                prompt: prompt,
                channel: step.config.imageChannel,
                aspectRatio: step.config.imageAspectRatio,
                resolution: step.config.imageResolution,
                quality: step.config.imageQuality,
                photoReal: step.config.imagePhotoReal
            )
            guard let taskId = result.ourTaskId else {
                throw WorkflowError.stepFailed(result.message ?? "未能获取任务ID")
            }
            let pollResult = try await pollImageTask(taskId)
            return .images(pollResult.resultUrls ?? [])

        case .videoGen:
            try await Task.sleep(nanoseconds: 500_000_000)

            switch step.config.videoGenType {
            case "veo":
                return try await executeVeoStep(step, lastText: lastText, lastImages: lastImages)
            case "grok":
                return try await executeGrokStep(step, lastText: lastText)
            case "seedance":
                return try await executeSeedanceStep(step, lastText: lastText)
            case "wan":
                throw WorkflowError.stepFailed("Wan 视频需要本地文件输入，暂不支持在工作流中使用")
            default:
                throw WorkflowError.stepFailed("不支持的视频生成类型: \(step.config.videoGenType)")
            }

        case .resultOutput:
            if let text = lastText { return .text(text) }
            if let images = lastImages { return .images(images) }
            return .none
        }
    }

    private func executeVeoStep(_ step: WorkflowStep, lastText: String?, lastImages: [String]?) async throws -> StepResult {
        var veoParams = VeoParams()
        veoParams.channel = step.config.videoChannel
        veoParams.model = step.config.videoModel
        veoParams.mode = step.config.videoMode
        veoParams.aspectRatio = step.config.videoAspectRatio
        veoParams.resolution = step.config.videoResolution
        veoParams.duration = step.config.videoDuration
        veoParams.generateAudio = step.config.videoGenerateAudio
        veoParams.prompt = lastText ?? ""

        if step.config.videoMode == "image", let imageUrl = lastImages?.first {
            let imageData = try await downloadImageData(from: imageUrl)
            veoParams.imageData = imageData
            veoParams.imageName = "workflow_image.png"
            veoParams.imageMime = "image/png"
        }

        let result = try await api.generateVeoVideo(params: veoParams)
        guard let taskId = result.ourTaskId else {
            throw WorkflowError.stepFailed(result.message ?? "未能获取任务ID")
        }
        let pollResult = try await pollVeoTask(taskId)
        return .video(pollResult.videoUrl)
    }

    private func executeGrokStep(_ step: WorkflowStep, lastText: String?) async throws -> StepResult {
        let prompt = lastText ?? ""
        let result = try await api.generateGrokVideo(
            prompt: prompt,
            channel: step.config.videoChannel,
            mode: step.config.videoMode,
            aspectRatio: step.config.videoAspectRatio,
            resolution: step.config.videoResolution,
            duration: step.config.videoDuration,
            imageFiles: [],
            videoData: nil, videoName: nil, videoMime: nil
        )
        guard let taskId = result.taskId else {
            throw WorkflowError.stepFailed(result.message ?? "未能获取任务ID")
        }
        let pollResult = try await pollGrokTask(taskId)
        return .video(pollResult.outputUrl)
    }

    private func executeSeedanceStep(_ step: WorkflowStep, lastText: String?) async throws -> StepResult {
        let prompt = lastText ?? ""
        let result = try await api.generateSeedanceVideo(
            prompt: prompt,
            mode: step.config.videoMode,
            model: step.config.videoModel,
            ratio: step.config.videoAspectRatio,
            resolution: step.config.videoResolution,
            duration: Int(step.config.videoDuration) ?? 8,
            count: 1,
            generateAudio: step.config.videoGenerateAudio,
            assets: []
        )
        guard let taskId = result.ourTaskId ?? result.tasks?.first?.ourTaskId else {
            throw WorkflowError.stepFailed(result.message ?? "未能获取任务ID")
        }
        let pollResult = try await pollSeedanceTask(taskId)
        return .video(pollResult.videoUrl)
    }

    // MARK: - Polling Helpers

    private func pollImageTask(_ taskId: String) async throws -> TaskPollResponse {
        for _ in 0..<60 {
            guard !Task.isCancelled else { throw CancellationError() }
            let result = try await api.pollImageTask(taskId)
            let status = (result.dbStatus ?? "").uppercased()
            if status == "SUCCESS" { return result }
            if status == "FAILED" || status == "CANCELLED" {
                throw WorkflowError.stepFailed(result.errorMessage ?? "图片生成失败")
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw WorkflowError.stepFailed("图片生成超时")
    }

    private func pollVeoTask(_ taskId: String) async throws -> TaskPollResponse {
        for _ in 0..<120 {
            guard !Task.isCancelled else { throw CancellationError() }
            let result = try await api.pollVeoTask(taskId)
            let status = (result.dbStatus ?? "").uppercased()
            if status == "SUCCESS" { return result }
            if status == "FAILED" || status == "CANCELLED" || status == "ERROR" {
                throw WorkflowError.stepFailed(result.errorMessage ?? "视频生成失败")
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw WorkflowError.stepFailed("视频生成超时")
    }

    private func pollSeedanceTask(_ taskId: String) async throws -> TaskPollResponse {
        for _ in 0..<120 {
            guard !Task.isCancelled else { throw CancellationError() }
            let result = try await api.pollSeedanceTask(taskId)
            let status = (result.dbStatus ?? "").uppercased()
            if status == "SUCCESS" { return result }
            if status == "FAILED" || status == "CANCELLED" || status == "ERROR" {
                throw WorkflowError.stepFailed(result.errorMessage ?? "视频生成失败")
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw WorkflowError.stepFailed("视频生成超时")
    }

    private func pollGrokTask(_ taskId: String) async throws -> TaskPollResponse {
        for _ in 0..<120 {
            guard !Task.isCancelled else { throw CancellationError() }
            let result = try await api.pollGrokTask(taskId)
            let status = (result.status ?? "").uppercased()
            if status == "SUCCESS" { return result }
            if status == "FAILED" || status == "CANCELLED" || status == "ERROR" {
                throw WorkflowError.stepFailed(result.errorMessage ?? "视频生成失败")
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw WorkflowError.stepFailed("视频生成超时")
    }

    // MARK: - Helpers

    private func downloadImageData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw WorkflowError.stepFailed("无效的图片URL")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WorkflowError.stepFailed("下载图片失败")
        }
        return data
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
