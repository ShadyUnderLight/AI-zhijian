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
    var imageAspectRatio: String = "9:16"
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
    var videoNegativePrompt: String = ""
    var videoCount: Int = 1
    var outputLabel: String = "最终结果"
}

// MARK: - Workflow Step

struct WorkflowStep: Identifiable, Codable {
    var id: String = UUID().uuidString
    var type: WorkflowStepType
    var label: String
    var config: WorkflowStepConfig

    init(id: String = UUID().uuidString, type: WorkflowStepType, label: String? = nil, config: WorkflowStepConfig = .init()) {
        self.id = id
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
    var definition: WorkflowDefinition? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String = "未命名工作流", steps: [WorkflowStep] = []) {
        self.name = name
        self.steps = steps
    }
}

// MARK: - Step Run Status

enum StepRunStatus: String, Codable {
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

// MARK: - Node Run Detail (per-node runtime info for monitoring UI)

struct WorkflowNodeRunDetail {
    var startedAt: Date?
    var completedAt: Date?
    var inputSummary: String?
    var outputSummary: String?

    var elapsedSeconds: Int? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return Int(end.timeIntervalSince(start))
    }

    var elapsedText: String? {
        guard let s = elapsedSeconds else { return nil }
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m\(s % 60)s"
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
    var nodeStatuses: [String: WorkflowNodeStatus] = [:]
    var nodeDetails: [String: WorkflowNodeRunDetail] = [:]

    /// Cached node outputs for retry: nodeId -> portId -> WorkflowValue
    var cachedNodeOutputs: [String: [String: WorkflowValue]] = [:]
    /// Structural fingerprint of the definition that produced cachedNodeOutputs
    var cachedStructuralFingerprint: Int?
    /// Config fingerprint of the definition that produced cachedNodeOutputs
    var cachedConfigFingerprint: Int?

    /// Logs per node: nodeId -> [log message]
    var nodeLogs: [String: [String]] = [:]
}

// MARK: - Veo Capacity Table (moved to VeoRules)

// MARK: - Workflow Store

@MainActor
final class WorkflowStore: ObservableObject {
    @Published var workflows: [Workflow] = []
    @Published var selectedWorkflowId: String?
    @Published var runState = WorkflowRunState()
    @Published var runHistory: [WorkflowRunSummary] = []

    private let api: APIService
    private let executor: GenerationTaskExecutor
    private let logger = Logger(subsystem: "AIZhijian", category: "WorkflowStore")
    private var runTask: Task<Void, Never>?
    private var activeTaskIds: [String] = []
    private var currentRunId: String?
    private var currentRunStartedAt: Date?
    private var currentWorkflow: Workflow?
    private var currentWorkflowId: String?   // tracks DAG workflow identity for cancel-on-delete
    private var currentWorkflowName: String?  // for cancel-run record saving
    private var currentDefinition: WorkflowDefinition?  // DAG run reference for cancel

    private static let persistenceKey = "WorkflowStore.workflows"
    private static let recentTemplatesKey = "WorkflowStore.recentTemplates"
    @Published var recentTemplateIds: [String] = []

    var selectedWorkflow: Workflow? {
        guard let id = selectedWorkflowId else { return nil }
        return workflows.first { $0.id == id }
    }

    init(api: APIService) {
        self.api = api
        self.executor = GenerationTaskExecutor(api: api)
        load()
        loadRecentTemplates()
    }

    // MARK: - CRUD

    func createWorkflow(name: String = "未命名工作流") -> Workflow {
        let wf = Workflow(name: name)
        workflows.append(wf)
        selectedWorkflowId = wf.id
        persist()
        return wf
    }

    func createWorkflow(from template: WorkflowTemplate) -> Workflow {
        var wf = Workflow(name: template.name)
        wf.definition = template.makeDefinition()
        workflows.append(wf)
        selectedWorkflowId = wf.id
        recordTemplateUsage(template.id)
        persist()
        return wf
    }

    func deleteWorkflow(_ id: String) {
        if currentWorkflow?.id == id || currentWorkflowId == id, runState.isRunning {
            cancelRun()
        }
        currentWorkflow = nil
        currentWorkflowId = nil
        currentWorkflowName = nil
        currentDefinition = nil
        currentRunId = nil
        currentRunStartedAt = nil

        workflows.removeAll { $0.id == id }
        if selectedWorkflowId == id {
            selectedWorkflowId = workflows.first?.id
        }
        WorkflowRunPersistence.deleteRuns(for: id)
        runHistory = WorkflowRunPersistence.loadIndex().runs
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

    /// Run a workflow using the legacy linear steps executor.
    /// Bypasses the DAG definition — used by simple mode to preserve
    /// {{text}} template resolution, Banana support, etc.
    @discardableResult
    func runLinearSteps(_ workflow: Workflow) -> Bool {
        guard !runState.isRunning else { return false }
        guard !workflow.steps.isEmpty else { return false }

        currentRunId = UUID().uuidString
        currentRunStartedAt = Date()
        currentWorkflow = workflow

        runState = WorkflowRunState()
        runState.isRunning = true
        runState.overallStatus = .running
        activeTaskIds.removeAll()

        for step in workflow.steps {
            runState.stepStates[step.id] = .pending
        }

        saveInitialRunRecord(workflow: workflow)

        runTask = Task { [weak self] in
            guard let self else { return }
            await self.executeSteps(workflow.steps)
        }
        return true
    }

    @discardableResult
    func runWorkflow(_ workflow: Workflow) -> Bool {
        guard !runState.isRunning else { return false }

        // If workflow has a DAG definition, run that instead
        if let definition = workflow.definition, !definition.nodes.isEmpty {
            return runWorkflowDefinition(definition, workflowId: workflow.id, workflowName: workflow.name)
        }

        currentRunId = UUID().uuidString
        currentRunStartedAt = Date()
        currentWorkflow = workflow

        runState = WorkflowRunState()
        runState.isRunning = true
        runState.overallStatus = .running
        activeTaskIds.removeAll()

        for step in workflow.steps {
            runState.stepStates[step.id] = .pending
        }

        saveInitialRunRecord(workflow: workflow)

        runTask = Task { [weak self] in
            guard let self else { return }
            await self.executeSteps(workflow.steps)
        }
        return true
    }

    @discardableResult
    func runWorkflowDefinition(_ definition: WorkflowDefinition, workflowId: String, workflowName: String) -> Bool {
        guard !runState.isRunning else { return false }

        let errors = definition.fullValidate()
        guard errors.isEmpty else {
            let messages = errors.compactMap(\.errorDescription).joined(separator: ", ")
            logger.warning("DAG validation failed: \(messages)")
            return false
        }

        currentRunId = UUID().uuidString
        currentRunStartedAt = Date()
        currentWorkflowId = workflowId
        currentWorkflowName = workflowName
        currentDefinition = definition

        runState = WorkflowRunState()
        runState.isRunning = true
        runState.overallStatus = .running
        runState.cachedStructuralFingerprint = definition.structuralFingerprint
        runState.cachedConfigFingerprint = definition.configFingerprint
        activeTaskIds.removeAll()

        for node in definition.nodes {
            runState.nodeStatuses[node.id] = .pending
        }

        saveInitialDAGRunRecord(definition: definition, workflowId: workflowId, workflowName: workflowName)

        runTask = Task { [weak self] in
            guard let self else { return }
            await self.executeDAG(definition, workflowId: workflowId, workflowName: workflowName)
        }
        return true
    }

    private func saveInitialDAGRunRecord(definition: WorkflowDefinition, workflowId: String, workflowName: String) {
        guard let runId = currentRunId, let startedAt = currentRunStartedAt else { return }
        let record = WorkflowRunRecord(
            runId: runId,
            workflowId: workflowId,
            workflowName: workflowName,
            stepsSnapshot: [],
            stepRecords: [],
            overallStatus: StepRunStatus.running.rawValue,
            startedAt: startedAt,
            completedAt: nil
        )
        WorkflowRunPersistence.saveRun(record)
    }

    private func saveInitialRunRecord(workflow: Workflow) {
        guard let runId = currentRunId, let startedAt = currentRunStartedAt else { return }
        let initialSteps = workflow.steps.map { step in
            WorkflowStepRunRecord(step: step, status: StepRunStatus.pending.rawValue)
        }
        let record = WorkflowRunRecord(
            runId: runId,
            workflowId: workflow.id,
            workflowName: workflow.name,
            stepsSnapshot: workflow.steps,
            stepRecords: initialSteps,
            overallStatus: StepRunStatus.running.rawValue,
            startedAt: startedAt,
            completedAt: nil
        )
        WorkflowRunPersistence.saveRun(record)
    }

    func cancelRun() {
        runTask?.cancel()
        if let currentId = runState.currentStepId {
            runState.stepStates[currentId] = .cancelled
            runState.nodeStatuses[currentId] = .cancelled
            removeActiveTask(for: currentId)
        }
        for (stepId, status) in runState.stepStates {
            if status == .pending {
                runState.stepStates[stepId] = .cancelled
            }
        }
        for (nodeId, status) in runState.nodeStatuses {
            if status == .pending {
                runState.nodeStatuses[nodeId] = .cancelled
            }
        }
        runState.currentStepId = nil
        runState.isRunning = false
        runState.overallStatus = .cancelled

        if let wf = currentWorkflow {
            buildAndSaveRunRecord(workflow: wf)
        } else if let def = currentDefinition, let wfId = currentWorkflowId {
            saveDAGRunRecord(definition: def, workflowId: wfId, workflowName: currentWorkflowName ?? def.name)
        }
    }

    // MARK: - Private Execution

    private func executeSteps(_ steps: [WorkflowStep]) async {
        defer {
            runState.isRunning = false
            runState.currentStepId = nil
            activeTaskIds.removeAll()
            if let wf = currentWorkflow {
                buildAndSaveRunRecord(workflow: wf)
            }
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

    private func executeDAG(_ definition: WorkflowDefinition, workflowId: String, workflowName: String, cachedOutputs: [String: [String: WorkflowValue]]? = nil) async {
        defer {
            runState.isRunning = false
            runState.currentStepId = nil
            activeTaskIds.removeAll()
            saveDAGRunRecord(definition: definition, workflowId: workflowId, workflowName: workflowName)
        }

        do {
            let sortedNodeIds = try definition.topologicalNodeIds()
            let context = WorkflowRunContext()

            // Restore cached outputs for retry
            if let cached = cachedOutputs {
                for (nodeId, portOutputs) in cached {
                    for (portId, value) in portOutputs {
                        context.setOutput(nodeId: nodeId, portId: portId, value: value)
                    }
                }
            }

            var wasCancelled = false

            for nodeId in sortedNodeIds {
                // Skip already-succeeded nodes when retrying
                if cachedOutputs != nil, runState.nodeStatuses[nodeId] == .succeeded {
                    continue
                }

                guard !Task.isCancelled else {
                    wasCancelled = true
                    runState.nodeStatuses[nodeId] = .cancelled
                    continue
                }

                guard let node = definition.nodes.first(where: { $0.id == nodeId }) else { continue }

                runState.currentStepId = nodeId
                runState.nodeStatuses[nodeId] = .running
                runState.nodeDetails[nodeId] = WorkflowNodeRunDetail(startedAt: Date())

                do {
                    let inputs = try context.inputValues(for: node, in: definition)
                    runState.nodeDetails[nodeId]?.inputSummary = Self.summarizeInputs(inputs, node: node)

                    try await executeDAGNode(node, inputs: inputs, context: context, definition: definition)

                    runState.nodeDetails[nodeId]?.completedAt = Date()
                    runState.nodeDetails[nodeId]?.outputSummary = Self.summarizeNodeOutput(nodeId: nodeId, context: context, node: node)
                    runState.nodeStatuses[nodeId] = .succeeded

                    // Sync logs from context to runState
                    let nodeLogLines = context.logLines.filter { $0.nodeId == nodeId }.map(\.message)
                    runState.nodeLogs[nodeId] = nodeLogLines

                    // Cache outputs for potential retry
                    var portOutputs: [String: WorkflowValue] = [:]
                    for port in node.outputPorts {
                        if let value = context.output(nodeId: nodeId, portId: port.id) {
                            portOutputs[port.id] = value
                        }
                    }
                    runState.cachedNodeOutputs[nodeId] = portOutputs
                } catch {
                    runState.nodeDetails[nodeId]?.completedAt = Date()
                    // Sync logs even on failure
                    let nodeLogLines = context.logLines.filter { $0.nodeId == nodeId }.map(\.message)
                    runState.nodeLogs[nodeId] = nodeLogLines

                    if Task.isCancelled {
                        wasCancelled = true
                        runState.nodeStatuses[nodeId] = .cancelled
                        continue
                    }
                    runState.stepErrors[nodeId] = error.localizedDescription
                    runState.nodeStatuses[nodeId] = .failed
                    runState.overallStatus = .failed
                    return
                }
            }

            if wasCancelled {
                runState.overallStatus = .cancelled
            } else {
                runState.overallStatus = .succeeded
            }
        } catch {
            runState.stepErrors["dag"] = error.localizedDescription
            runState.overallStatus = .failed
        }
    }

    // MARK: - Retry from failed node

    func retryFromFailedNode(_ definition: WorkflowDefinition, workflowId: String, workflowName: String) {
        guard !runState.isRunning else { return }
        guard runState.overallStatus == .failed else { return }

        // Invalidate cached outputs if the definition structure or config changed since the last run
        let currentFingerprint = definition.structuralFingerprint
        let currentConfigFingerprint = definition.configFingerprint
        let cacheInvalid = runState.cachedStructuralFingerprint != currentFingerprint
            || runState.cachedConfigFingerprint != currentConfigFingerprint

        if cacheInvalid {
            // Full reset: structure or config changed, cannot reuse any cached outputs
            runState.cachedNodeOutputs = [:]
            for nodeId in runState.nodeStatuses.keys {
                runState.nodeStatuses[nodeId] = .pending
                runState.stepErrors[nodeId] = nil
                runState.nodeDetails[nodeId] = nil
                runState.stepResults[nodeId] = nil
                runState.nodeLogs[nodeId] = nil
            }
        } else {
            // Partial retry: only reset failed/cancelled nodes, keep succeeded
            for (nodeId, status) in runState.nodeStatuses {
                if status == .failed || status == .cancelled {
                    runState.nodeStatuses[nodeId] = .pending
                    runState.stepErrors[nodeId] = nil
                    runState.nodeDetails[nodeId] = nil
                    runState.nodeLogs[nodeId] = nil
                }
            }
        }

        runState.overallStatus = .running
        runState.isRunning = true
        runState.currentStepId = nil

        // New run identity for this retry attempt
        currentRunId = UUID().uuidString
        currentRunStartedAt = Date()
        currentWorkflowId = workflowId
        currentWorkflowName = workflowName
        currentDefinition = definition
        runState.cachedStructuralFingerprint = currentFingerprint
        runState.cachedConfigFingerprint = currentConfigFingerprint
        saveInitialDAGRunRecord(definition: definition, workflowId: workflowId, workflowName: workflowName)

        // Pass nil when cache is invalidated so executeDAG doesn't skip succeeded nodes
        let cachedOutputs = cacheInvalid ? nil : runState.cachedNodeOutputs

        runTask = Task { [weak self] in
            guard let self else { return }
            await self.executeDAG(definition, workflowId: workflowId, workflowName: workflowName, cachedOutputs: cachedOutputs)
        }
    }

    // MARK: - Summary helpers

    private static func summarizeInputs(_ inputs: [String: WorkflowValue], node: WorkflowNode) -> String {
        var parts: [String] = []
        for port in node.inputPorts {
            if let value = inputs[port.id], value != .none {
                let brief: String
                switch value {
                case .text(let t): brief = String(t.prefix(20))
                case .image: brief = "图片"
                case .images(let imgs): brief = "\(imgs.count)张图"
                case .video: brief = "视频"
                case .file(let f): brief = f.name
                case .json: brief = "JSON"
                case .none: continue
                }
                parts.append("\(port.name):\(brief)")
            }
        }
        return parts.isEmpty ? "无输入" : parts.joined(separator: " | ")
    }

    private static func summarizeNodeOutput(nodeId: String, context: WorkflowRunContext, node: WorkflowNode) -> String {
        var parts: [String] = []
        for port in node.outputPorts {
            if let value = context.output(nodeId: nodeId, portId: port.id) {
                parts.append(safeSummary(for: value))
            }
        }
        return parts.isEmpty ? "无输出" : parts.joined(separator: " | ")
    }

    /// Summary with URL query/fragment stripped to avoid persisting signed tokens.
    nonisolated static func safeSummary(for value: WorkflowValue) -> String {
        switch value {
        case .image(let img):
            if let f = img.localFile { return "图片 (\(ByteCountFormatter.string(fromByteCount: Int64(f.data.count), countStyle: .file)))" }
            if let url = img.remoteURL { return "图片: \(stripURLSecrets(url))" }
            return "图片（无数据）"
        case .images(let imgs):
            return imgs.isEmpty ? "无图片" : "\(imgs.count) 张图片"
        case .video(let v):
            return "视频: \(stripURLSecrets(v.remoteURL))"
        default:
            return value.summary
        }
    }

    /// Strip query and fragment from a URL string to avoid leaking signed tokens.
    nonisolated static func stripURLSecrets(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        components.query = nil
        components.fragment = nil
        return components.string ?? urlString
    }

    private func saveDAGRunRecord(definition: WorkflowDefinition, workflowId: String, workflowName: String) {
        guard let runId = currentRunId, let startedAt = currentRunStartedAt else { return }

        var stepRecords: [WorkflowStepRunRecord] = []
        for node in definition.nodes {
            let status = runState.nodeStatuses[node.id] ?? .pending
            let error = runState.stepErrors[node.id]
            let result = runState.stepResults[node.id]
            let detail = runState.nodeDetails[node.id]

            var step = WorkflowStep(type: WorkflowStepType(rawValue: node.type.displayName) ?? .textInput, label: node.title)
            step.id = node.id   // use stable node id so history maps back to the node
            var record = WorkflowStepRunRecord(
                step: step,
                status: status.rawValue,
                error: error,
                result: result
            )
            if let detail {
                record.elapsedSeconds = detail.elapsedSeconds
                record.inputSummary = detail.inputSummary
                record.outputSummary = detail.outputSummary
            }
            stepRecords.append(record)
        }

        let record = WorkflowRunRecord(
            runId: runId,
            workflowId: workflowId,
            workflowName: workflowName,
            stepsSnapshot: [],
            stepRecords: stepRecords,
            overallStatus: runState.overallStatus.rawValue,
            startedAt: startedAt,
            completedAt: Date()
        )

        let runSaved = WorkflowRunPersistence.saveRun(record)

        var index = WorkflowRunPersistence.loadIndex()
        let summary = WorkflowRunSummary(
            runId: runId,
            workflowId: workflowId,
            workflowName: workflowName,
            overallStatus: runState.overallStatus.rawValue,
            startedAt: startedAt,
            completedAt: Date(),
            stepCount: definition.nodes.count,
            succeededCount: stepRecords.filter { $0.status == StepRunStatus.succeeded.rawValue }.count,
            firstError: stepRecords.first(where: { $0.status == StepRunStatus.failed.rawValue })?.errorMessage
        )
        let evicted = index.upsert(summary)
        let indexSaved = WorkflowRunPersistence.saveIndex(index)

        if runSaved, indexSaved {
            runHistory = index.runs
        }

        WorkflowRunPersistence.pruneEvictedRuns(evicted)

        currentRunId = nil
        currentRunStartedAt = nil
        currentWorkflowId = nil
        currentWorkflowName = nil
        currentDefinition = nil
    }

    private func executeDAGNode(_ node: WorkflowNode, inputs: [String: WorkflowValue], context: WorkflowRunContext, definition: WorkflowDefinition) async throws {
        switch node.config {
        case .textInput(let config):
            let text = config.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw WorkflowError.stepFailed("文本输入不能为空")
            }
            if let outputPort = node.outputPorts.first {
                context.setOutput(nodeId: node.id, portId: outputPort.id, value: .text(text))
            }

        case .promptTemplate(let config):
            let template = config.template.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !template.isEmpty else {
                throw WorkflowError.stepFailed("提示词模板不能为空")
            }
            let variableMap = WorkflowTemplateResolver.variableMap(from: inputs, ports: node.inputPorts)
            let resolved = WorkflowTemplateResolver.resolve(template, with: variableMap)
            if let outputPort = node.outputPorts.first {
                context.setOutput(nodeId: node.id, portId: outputPort.id, value: .text(resolved))
            }

        case .imageGen(let config):
            let promptPort = node.inputPorts.first(where: { $0.portType == .text })
            guard let promptPort, case .text(let prompt) = inputs[promptPort.id] ?? .none, !prompt.isEmpty else {
                throw WorkflowError.stepFailed("图片生成需要提示词输入")
            }

            addActiveTask(for: node.id, type: "图片生成", desc: String(prompt.prefix(30)))
            defer { removeActiveTask(for: node.id) }

            let params = GptImageJobParams(
                prompt: prompt,
                channel: config.channel.rawValue,
                aspectRatio: config.aspectRatio.rawValue,
                resolution: config.resolution.rawValue,
                quality: config.quality.rawValue,
                photoReal: config.photoReal
            )
            let output = try await exec(.gptImage(params), kind: .gptImage, maxTicks: 60, label: "图片生成")
            if case .images(let urls) = output, let outputPort = node.outputPorts.first {
                context.setOutput(nodeId: node.id, portId: outputPort.id, value: .images(urls.map { WorkflowImage(localFile: nil, remoteURL: $0) }))
                runState.stepResults[node.id] = .images(urls)
            } else {
                throw WorkflowError.stepFailed("图片生成未返回图片")
            }

        case .videoGen(let config):
            let promptPort = node.inputPorts.first(where: { $0.role == .prompt })
            let imagePort = node.inputPorts.first(where: { $0.role == .image })
            let firstFramePort = node.inputPorts.first(where: { $0.role == .firstFrame })
            let lastFramePort = node.inputPorts.first(where: { $0.role == .lastFrame })
            let prompt: String
            if let promptPort, case .text(let t) = inputs[promptPort.id] ?? .none {
                prompt = t
            } else {
                prompt = ""
            }

            addActiveTask(for: node.id, type: "视频生成(\(config.genType.rawValue))", desc: String(prompt.prefix(30)))
            defer { removeActiveTask(for: node.id) }

            let output: GenerationOutput
            switch config.genType {
            case .veo:
                var veoParams = VeoJobParams()
                veoParams.prompt = prompt
                veoParams.channel = config.channel.rawValue
                veoParams.model = config.model
                veoParams.mode = config.mode.rawValue
                veoParams.aspectRatio = config.aspectRatio.rawValue
                veoParams.resolution = config.resolution.rawValue
                veoParams.duration = config.duration
                veoParams.generateAudio = config.generateAudio
                let trimmedNegativePrompt = config.negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                veoParams.negativePrompt = VeoRules.supportsNegativePrompt(channel: veoParams.channel) && !trimmedNegativePrompt.isEmpty ? config.negativePrompt : nil

                if config.mode == .image {
                    guard let imagePort else {
                        throw WorkflowError.stepFailed("Veo 图生视频缺少图片输入端口")
                    }
                    let imageValue = inputs[imagePort.id] ?? .none
                    guard let urlString = imageValue.firstRemoteImageURL, !urlString.isEmpty else {
                        throw WorkflowError.stepFailed("Veo 图生视频需要图片输入端口提供图片")
                    }
                    let imageData = try await downloadImageData(from: urlString)
                    veoParams.imageData = imageData
                    veoParams.imageName = "input_image.png"
                    veoParams.imageMime = "image/png"
                }

                if config.mode == .startEnd {
                    guard let firstFramePort else {
                        throw WorkflowError.stepFailed("Veo 首尾帧模式缺少首帧图片输入端口")
                    }
                    let firstValue = inputs[firstFramePort.id] ?? .none
                    guard let firstURL = firstValue.firstRemoteImageURL, !firstURL.isEmpty else {
                        throw WorkflowError.stepFailed("Veo 首尾帧模式需要首帧图片")
                    }
                    veoParams.firstImageData = try await downloadImageData(from: firstURL)
                    veoParams.firstImageName = "first_frame.png"
                    veoParams.firstImageMime = "image/png"

                    if let lastFramePort {
                        let lastValue = inputs[lastFramePort.id] ?? .none
                        if let lastURL = lastValue.firstRemoteImageURL, !lastURL.isEmpty {
                            veoParams.lastImageData = try await downloadImageData(from: lastURL)
                            veoParams.lastImageName = "last_frame.png"
                            veoParams.lastImageMime = "image/png"
                        }
                    }
                }

                if config.mode == .reference {
                    guard let imagePort else {
                        throw WorkflowError.stepFailed("Veo 参考模式缺少图片输入端口")
                    }
                    let imageValue = inputs[imagePort.id] ?? .none
                    guard let urlString = imageValue.firstRemoteImageURL, !urlString.isEmpty else {
                        throw WorkflowError.stepFailed("Veo 参考模式需要参考图片")
                    }
                    let data = try await downloadImageData(from: urlString)
                    veoParams.ref1Data = (data: data, name: "ref_image.png", mime: "image/png")
                }

                output = try await exec(.veo(veoParams), kind: .veo, maxTicks: 120, label: "Veo 视频生成")

            case .grok:
                let grokParams = GrokJobParams(
                    prompt: prompt,
                    channel: config.channel.rawValue,
                    mode: config.mode.rawValue,
                    aspectRatio: config.aspectRatio.rawValue,
                    resolution: config.resolution.rawValue,
                    duration: config.duration,
                    imageFiles: [],
                    videoData: nil,
                    videoName: nil,
                    videoMime: nil
                )
                output = try await exec(.grok(grokParams), kind: .grok, maxTicks: 120, label: "Grok 视频生成")

            case .seedance:
                var seedanceAssets: [SeedanceAsset] = []
                if config.mode == .firstLast {
                    guard let firstFramePort else {
                        throw WorkflowError.stepFailed("Seedance 首尾帧模式缺少首帧图片输入端口")
                    }
                    let firstValue = inputs[firstFramePort.id] ?? .none
                    guard let firstURL = firstValue.firstRemoteImageURL, !firstURL.isEmpty else {
                        throw WorkflowError.stepFailed("Seedance 首尾帧模式需要首帧图片")
                    }
                    let firstData = try await downloadImageData(from: firstURL)
                    seedanceAssets.append(SeedanceAsset(type: "image", data: firstData, name: "first_frame.png", mime: "image/png", duration: 0))

                    if let lastFramePort {
                        let lastValue = inputs[lastFramePort.id] ?? .none
                        if let lastURL = lastValue.firstRemoteImageURL, !lastURL.isEmpty {
                            let lastData = try await downloadImageData(from: lastURL)
                            seedanceAssets.append(SeedanceAsset(type: "image", data: lastData, name: "last_frame.png", mime: "image/png", duration: 0))
                        }
                    }
                } else if config.mode == .reference, let imagePort {
                    let imageValue = inputs[imagePort.id] ?? .none
                    if let urlString = imageValue.firstRemoteImageURL, !urlString.isEmpty {
                        let data = try await downloadImageData(from: urlString)
                        seedanceAssets.append(SeedanceAsset(type: "image", data: data, name: "reference_image.png", mime: "image/png", duration: 0))
                    }
                }

                let seedanceParams = SeedanceJobParams(
                    prompt: prompt,
                    mode: config.mode.rawValue,
                    model: config.model,
                    ratio: config.aspectRatio.rawValue,
                    resolution: config.resolution.rawValue,
                    duration: Int(config.duration) ?? 5,
                    count: config.count,
                    generateAudio: config.generateAudio,
                    assets: seedanceAssets
                )
                output = try await exec(.seedance(seedanceParams), kind: .seedance, maxTicks: 120, label: "Seedance 视频生成")

            case .wan:
                throw WorkflowError.stepFailed("Wan 视频需要本地文件输入，暂不支持在工作流中使用")
            }

            if case .video(let url) = output, let url, let outputPort = node.outputPorts.first {
                context.setOutput(nodeId: node.id, portId: outputPort.id, value: .video(WorkflowVideo(remoteURL: url)))
                runState.stepResults[node.id] = .video(url)
            } else {
                throw WorkflowError.stepFailed("视频生成未返回视频")
            }

        case .resultOutput:
            let inputPort = node.inputPorts.first
            if let inputPort, let value = inputs[inputPort.id] {
                runState.stepResults[node.id] = value.asStepResult()
            }
        }
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
        let trimmedNegativePrompt = config.videoNegativePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        veoParams.negativePrompt = VeoRules.supportsNegativePrompt(channel: veoParams.channel) && !trimmedNegativePrompt.isEmpty ? config.videoNegativePrompt : nil

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
        let seedanceModels = ["dreamina-seedance-2-0-260128", "dreamina-seedance-2-0-fast-260128"]
        guard seedanceModels.contains(config.videoModel) else {
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
        guard config.videoCount >= 1, config.videoCount <= 4 else {
            throw WorkflowError.stepFailed("Seedance 数量需在 1-4 之间")
        }

        let params = SeedanceJobParams(
            prompt: prompt, mode: config.videoMode, model: config.videoModel,
            ratio: config.videoAspectRatio, resolution: config.videoResolution,
            duration: dur, count: config.videoCount, generateAudio: config.videoGenerateAudio, assets: []
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

    // MARK: - Run Record Persistence

    private func buildAndSaveRunRecord(workflow: Workflow) {
        guard let runId = currentRunId, let startedAt = currentRunStartedAt else { return }

        var stepRecords: [WorkflowStepRunRecord] = []
        for step in workflow.steps {
            let status = runState.stepStates[step.id] ?? .pending
            let result = runState.stepResults[step.id]
            let error = runState.stepErrors[step.id]

            var record = WorkflowStepRunRecord(
                step: step,
                status: status.rawValue,
                error: error,
                result: result
            )

            if case .bananaImage(let data) = result {
                if let path = WorkflowRunPersistence.saveAsset(data: data, name: "banana.png", runId: runId) {
                    record.attachAssetPath(path)
                }
            }

            stepRecords.append(record)
        }

        let runRecord = WorkflowRunRecord(
            runId: runId,
            workflowId: workflow.id,
            workflowName: workflow.name,
            stepsSnapshot: workflow.steps,
            stepRecords: stepRecords,
            overallStatus: runState.overallStatus.rawValue,
            startedAt: startedAt,
            completedAt: Date()
        )

        let runSaved = WorkflowRunPersistence.saveRun(runRecord)

        var index = WorkflowRunPersistence.loadIndex()
        let summary = WorkflowRunSummary(
            runId: runId,
            workflowId: workflow.id,
            workflowName: workflow.name,
            overallStatus: runRecord.overallStatus,
            startedAt: startedAt,
            completedAt: Date(),
            stepCount: workflow.steps.count,
            succeededCount: stepRecords.filter { $0.status == StepRunStatus.succeeded.rawValue }.count,
            firstError: stepRecords.first(where: { $0.status == StepRunStatus.failed.rawValue })?.errorMessage
        )
        let evicted = index.upsert(summary)
        let indexSaved = WorkflowRunPersistence.saveIndex(index)

        if runSaved, indexSaved {
            runHistory = index.runs
        } else {
            logger.warning("Run record persistence partially failed (run: \(runSaved), index: \(indexSaved))")
        }

        WorkflowRunPersistence.pruneEvictedRuns(evicted)

        currentRunId = nil
        currentRunStartedAt = nil
        currentWorkflow = nil
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(workflows) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    private func load() {
        var index = WorkflowRunPersistence.loadIndex()
        var indexChanged = false

        for i in index.runs.indices where index.runs[i].overallStatus == StepRunStatus.running.rawValue {
            if var record = WorkflowRunPersistence.loadRun(runId: index.runs[i].runId) {
                record.overallStatus = "interrupted"
                record.completedAt = Date()
                WorkflowRunPersistence.saveRun(record)
            }
            index.runs[i].overallStatus = "interrupted"
            index.runs[i].completedAt = Date()
            indexChanged = true
        }
        if indexChanged {
            WorkflowRunPersistence.saveIndex(index)
        }
        runHistory = index.runs

        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let decoded = try? JSONDecoder().decode([Workflow].self, from: data)
        else { return }
        workflows = decoded
        if selectedWorkflowId == nil {
            selectedWorkflowId = workflows.first?.id
        }
    }

    // MARK: - Recent Templates

    private func loadRecentTemplates() {
        guard let data = UserDefaults.standard.data(forKey: Self.recentTemplatesKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return }
        let validIds = Set(WorkflowDefinition.templates.map(\.id))
        var seen = Set<String>()
        var sanitized: [String] = []
        for id in decoded {
            guard validIds.contains(id), !seen.contains(id) else { continue }
            seen.insert(id)
            sanitized.append(id)
            if sanitized.count >= 5 { break }
        }
        recentTemplateIds = sanitized
    }

    private func saveRecentTemplates() {
        if let data = try? JSONEncoder().encode(recentTemplateIds) {
            UserDefaults.standard.set(data, forKey: Self.recentTemplatesKey)
        }
    }

    func recordTemplateUsage(_ templateId: String) {
        recentTemplateIds.removeAll { $0 == templateId }
        recentTemplateIds.insert(templateId, at: 0)
        if recentTemplateIds.count > 5 {
            recentTemplateIds = Array(recentTemplateIds.prefix(5))
        }
        saveRecentTemplates()
    }
}

// MARK: - StepResult <-> WorkflowValue Adapter

extension WorkflowValue {
    /// Convert from linear StepResult. Multi-image URLs become .images, single URL becomes .image.
    init(from result: StepResult) {
        switch result {
        case .none:
            self = .none
        case .text(let t):
            self = .text(t)
        case .images(let urls):
            if urls.isEmpty {
                self = .none
            } else if urls.count == 1 {
                self = .image(WorkflowImage(localFile: nil, remoteURL: urls[0]))
            } else {
                self = .images(urls.map { WorkflowImage(localFile: nil, remoteURL: $0) })
            }
        case .bananaImage(let d):
            self = .image(WorkflowImage(localFile: FileRef(data: d, name: "banana.png", mime: "image/png"), remoteURL: nil))
        case .video(let url):
            if let url {
                self = .video(WorkflowVideo(remoteURL: url))
            } else {
                self = .none
            }
        }
    }

    /// Convert back to linear StepResult. Best-effort: multi-image collapses to first URL or banana Data.
    func asStepResult() -> StepResult {
        switch self {
        case .none:
            return .none
        case .text(let t):
            return .text(t)
        case .image(let img):
            if let d = img.localFile?.data {
                return .bananaImage(d)
            }
            if let url = img.remoteURL {
                return .images([url])
            }
            return .none
        case .images(let imgs):
            let urls = imgs.compactMap { $0.remoteURL }
            if !urls.isEmpty { return .images(urls) }
            let data = imgs.compactMap { $0.localFile?.data }
            if let first = data.first { return .bananaImage(first) }
            return .none
        case .video(let v):
            if v.remoteURL.isEmpty { return .none }
            return .video(v.remoteURL)
        case .file(let f):
            return .bananaImage(f.data)
        case .json:
            return .text(summary)
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
