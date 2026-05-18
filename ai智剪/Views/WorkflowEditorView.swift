import SwiftUI

// MARK: - Editor Mode

enum EditorMode: String, CaseIterable {
    case linear = "线性"
    case canvas = "画布"

    var icon: String {
        switch self {
        case .linear: return "list.bullet"
        case .canvas: return "square.grid.3x3"
        }
    }
}

struct WorkflowEditorView: View {
    @EnvironmentObject var store: WorkflowStore
    @State private var workflowName: String = ""
    @State private var steps: [WorkflowStep] = []
    @State private var editingStep: WorkflowStep?
    @State private var editingNode: WorkflowNode?
    @State private var showStepConfig = false
    @State private var showNodeConfig = false
    @State private var showWorkflowList = false
    @State private var editorMode: EditorMode = {
        if let raw = UserDefaults.standard.string(forKey: Self.editorModeKey),
           let mode = EditorMode(rawValue: raw) {
            return mode
        }
        return .canvas
    }()
    @State private var dagDefinition: WorkflowDefinition = WorkflowDefinition(name: "未命名工作流")
    @State private var showOnboarding = false
    @State private var selectedRunNodeId: String?
    @State private var isRunInspectorPresented = false
    @State private var showNonLinearAlert = false
    @State private var pendingModeSwitch: EditorMode?
    /// True when in linear mode but the underlying DAG is non-linear (read-only fallback).
    @State private var linearModeUnsupported = false
    @State private var showRunErrorAlert = false
    @State private var runErrorMessage = ""

    private static let onboardingKey = "WorkflowEditor.hasSeenOnboarding"
    private static let editorModeKey = "WorkflowEditor.editorMode"

    /// Custom binding that validates mode switch for non-linear DAGs.
    private var editorModeBinding: Binding<EditorMode> {
        Binding(
            get: { editorMode },
            set: { newMode in
                if newMode == .linear && !dagDefinition.isLinearChain && !dagDefinition.nodes.isEmpty {
                    // Non-linear DAG: show warning before switching
                    pendingModeSwitch = newMode
                    showNonLinearAlert = true
                } else {
                    editorMode = newMode
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let wf = store.selectedWorkflow {
                workflowContent(wf)
            } else {
                emptyState
            }
        }
        .onAppear {
            syncFromStore()
            if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        }) {
            OnboardingView {
                showOnboarding = false
            }
        }
        .onChange(of: store.selectedWorkflowId) { _, _ in
            syncFromStore()
        }
        .onChange(of: editorMode) { _, newMode in
            UserDefaults.standard.set(newMode.rawValue, forKey: Self.editorModeKey)
            if newMode == .canvas && !steps.isEmpty && !linearModeUnsupported {
                // Only convert steps→DAG when user explicitly switches from a
                // supported linear view.  Skip when returning from unsupported
                // mode (non-linear DAG was preserved, stale steps must not overwrite).
                dagDefinition = WorkflowDefinition.fromLinearSteps(steps, name: workflowName)
            }
            syncModeData()
        }
        .alert("切换到简单模式", isPresented: $showNonLinearAlert) {
            Button("取消", role: .cancel) {
                pendingModeSwitch = nil
            }
            Button("继续切换") {
                if let mode = pendingModeSwitch {
                    editorMode = mode
                    pendingModeSwitch = nil
                }
            }
        } message: {
            Text("当前工作流包含分支或并行节点，无法在简单模式中完整展示。切换后将显示空白步骤列表，画布中的工作流不受影响。")
        }
        .alert("运行失败", isPresented: $showRunErrorAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(runErrorMessage)
        }
        .sheet(isPresented: $showStepConfig) {
            if let step = editingStep {
                StepConfigSheet(step: step) { updated in
                    updateStep(updated)
                }
            }
        }
        .sheet(isPresented: $showNodeConfig) {
            if let node = editingNode {
                NodeConfigSheet(node: node) { updated in
                    updateNode(updated)
                }
            }
        }
        .sheet(isPresented: $showWorkflowList) {
            WorkflowListSheet()
        }
    }

    private var sortedTemplates: [WorkflowTemplate] {
        let templates = WorkflowDefinition.templates
        let recentIds = store.recentTemplateIds
        return templates.enumerated().sorted { a, b in
            let aRecent = recentIds.firstIndex(of: a.element.id) ?? Int.max
            let bRecent = recentIds.firstIndex(of: b.element.id) ?? Int.max
            if aRecent != bRecent { return aRecent < bRecent }
            return a.offset < b.offset
        }.map(\.element)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("还没有工作流")
                .font(.title2)
            Text("从模板开始，或创建空白工作流")
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                // 空白工作流卡片
                Button {
                    _ = store.createWorkflow()
                    syncFromStore()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "doc")
                            .font(.system(size: 28))
                        Text("空白工作流")
                            .font(.headline)
                        Text("从零开始搭建")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 160, height: 120)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // 模板卡片
                ForEach(sortedTemplates) { template in
                    Button {
                        createFromTemplate(template)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: template.icon)
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            Text(template.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text(template.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            HStack(spacing: 12) {
                                Label("\(template.nodeCount) 节点", systemImage: "circle.grid.3x3")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Label(template.outputType, systemImage: "arrow.right.circle")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 180, height: 140)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func workflowContent(_ wf: Workflow) -> some View {
        VStack(spacing: 0) {
            HStack {
                TextField("工作流名称", text: $workflowName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .onSubmit { saveCurrent() }

                Spacer()

                // Editor Mode Picker
                Picker("编辑模式", selection: editorModeBinding) {
                    ForEach(EditorMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .help("切换编辑模式")

                Button { showWorkflowList = true } label: {
                    Label("打开", systemImage: "folder")
                }
                .help("打开已保存的工作流")

                Menu {
                    Button {
                        createNew()
                    } label: {
                        Label("空白工作流", systemImage: "doc")
                    }
                    Divider()
                    ForEach(sortedTemplates) { template in
                        Button {
                            createFromTemplate(template)
                        } label: {
                            Label(template.name, systemImage: template.icon)
                        }
                    }
                } label: {
                    Label("新建", systemImage: "plus")
                }

                Button { saveCurrent() } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)

                if editorMode == .canvas ? !dagDefinition.nodes.isEmpty : !steps.isEmpty {
                    Button {
                        if store.runState.isRunning {
                            store.cancelRun()
                        } else {
                            var started = false
                            if editorMode == .canvas {
                                saveCurrent()
                                started = store.runWorkflowDefinition(dagDefinition, workflowId: store.selectedWorkflow?.id ?? "", workflowName: workflowName)
                            } else if let wf = store.selectedWorkflow {
                                // Linear mode: run legacy steps executor directly.
                                // Do NOT saveCurrent() — it would persist a DAG that
                                // bypasses the steps executor (missing {{text}} resolution,
                                // Banana support, etc.)
                                // Save just the steps so the workflow has the latest edits.
                                var updatedWf = wf
                                let trimmedName = workflowName.trimmingCharacters(in: .whitespacesAndNewlines)
                                updatedWf.name = trimmedName.isEmpty ? "未命名工作流" : trimmedName
                                updatedWf.steps = steps
                                store.saveWorkflow(updatedWf)
                                started = store.runLinearSteps(updatedWf)
                            }
                            // Only auto-open inspector if run actually started
                            if started && editorMode == .canvas {
                                isRunInspectorPresented = true
                                selectedRunNodeId = dagDefinition.nodes.first?.id
                            }
                        }
                    } label: {
                        if store.runState.isRunning {
                            Label("停止", systemImage: "stop.fill")
                        } else {
                            Label("运行", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.runState.isRunning ? .red : .green)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider().padding(.top, 8)

            // Content based on editor mode
            switch editorMode {
            case .linear:
                linearEditor
            case .canvas:
                canvasEditor
            }

            // Linear mode: show run status as bottom panel
            if editorMode == .linear && (store.runState.isRunning || store.runState.overallStatus == .succeeded || store.runState.overallStatus == .failed) {
                Divider()
                RunStatusPanel(
                    editorMode: editorMode,
                    dagDefinition: dagDefinition,
                    selectedNodeId: $selectedRunNodeId
                )
                .frame(maxHeight: 240)
            }
        }
        // Canvas mode: show run status as inspector
        .inspector(isPresented: editorMode == .canvas ? $isRunInspectorPresented : .constant(false)) {
            if editorMode == .canvas {
                RunStatusPanel(
                    editorMode: editorMode,
                    dagDefinition: dagDefinition,
                    selectedNodeId: $selectedRunNodeId
                )
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            }
        }
    }

    // MARK: - Linear Editor

    private var linearEditor: some View {
        VStack(spacing: 0) {
            List {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    StepRow(
                        step: step,
                        index: index,
                        isRunning: store.runState.isRunning,
                        runStatus: store.runState.stepStates[step.id],
                        runResult: store.runState.stepResults[step.id],
                        runError: store.runState.stepErrors[step.id]
                    )
                    .onTapGesture {
                        guard !store.runState.isRunning else { return }
                        editingStep = step
                        showStepConfig = true
                    }
                }
                .onMove { from, to in
                    steps.move(fromOffsets: from, toOffset: to)
                    saveCurrent()
                }
                .onDelete { offsets in
                    steps.remove(atOffsets: offsets)
                    saveCurrent()
                }
            }
            .listStyle(.inset)

            HStack {
                Menu {
                    ForEach(WorkflowStepType.allCases, id: \.self) { type in
                        Button {
                            addStep(type: type)
                        } label: {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                } label: {
                    Label("添加步骤", systemImage: "plus.circle")
                }
                .disabled(store.runState.isRunning)
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Text("共 \(steps.count) 个步骤")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Canvas Editor

    private var canvasEditor: some View {
        WorkflowCanvasView(
            definition: $dagDefinition,
            nodeStatuses: store.runState.nodeStatuses,
            isRunning: store.runState.isRunning,
            onNodeSelect: { node in
                // If has any run state (running, succeeded, failed, cancelled), open inspector
                let hasRunState = store.runState.isRunning || !store.runState.nodeStatuses.isEmpty
                if hasRunState {
                    selectedRunNodeId = node.id
                    isRunInspectorPresented = true
                } else {
                    // No run state, open node config
                    editingNode = node
                    showNodeConfig = true
                }
            },
            onNodeDelete: { nodeId in
                if editingNode?.id == nodeId {
                    editingNode = nil
                    showNodeConfig = false
                }
                if selectedRunNodeId == nodeId {
                    selectedRunNodeId = nil
                }
                saveCurrent()
            }
        )
    }

    // MARK: - Actions

    private func syncFromStore() {
        if let wf = store.selectedWorkflow {
            workflowName = wf.name
            steps = wf.steps
            if let def = wf.definition {
                dagDefinition = def
            } else {
                dagDefinition = WorkflowDefinition(name: wf.name)
            }
        }
        // P2-2: If persisted mode is linear but DAG is non-linear, force to canvas.
        // Set linearModeUnsupported *before* changing editorMode so the onChange
        // handler sees it and skips steps→DAG conversion.
        // Do NOT call syncModeData() here — onChange will call it, and calling
        // it now would clear linearModeUnsupported before onChange fires.
        if editorMode == .linear && !dagDefinition.isLinearChain && !dagDefinition.nodes.isEmpty {
            linearModeUnsupported = true
            editorMode = .canvas
            UserDefaults.standard.set(editorMode.rawValue, forKey: Self.editorModeKey)
        } else {
            syncModeData()
        }
    }

    /// Synchronize data when switching between linear and canvas modes.
    /// Only converts steps→DAG on explicit mode switch, not on store load.
    private func syncModeData() {
        switch editorMode {
        case .linear:
            if dagDefinition.isLinearChain && !dagDefinition.nodes.isEmpty {
                // Safe: convert DAG to linear steps
                steps = dagDefinition.toLinearSteps()
                linearModeUnsupported = false
            } else if !dagDefinition.nodes.isEmpty {
                // Non-linear DAG: keep existing steps, mark as unsupported
                linearModeUnsupported = true
            } else {
                linearModeUnsupported = false
            }
        case .canvas:
            linearModeUnsupported = false
            // Only convert steps→DAG if canvas is currently empty.
            // If canvas already has nodes (loaded from store or edited),
            // don't overwrite with stale steps.
            if dagDefinition.nodes.isEmpty && !steps.isEmpty {
                dagDefinition = WorkflowDefinition.fromLinearSteps(steps, name: workflowName)
            }
        }
    }

    private func createNew() {
        saveCurrent()
        _ = store.createWorkflow()
        syncFromStore()
    }

    private func createFromTemplate(_ template: WorkflowTemplate) {
        saveCurrent()
        _ = store.createWorkflow(from: template)
        syncFromStore()
    }

    private func saveCurrent() {
        guard var wf = store.selectedWorkflow else { return }
        wf.name = workflowName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "未命名工作流" : workflowName
        wf.steps = steps
        if editorMode == .canvas {
            dagDefinition.name = wf.name
            wf.definition = dagDefinition
        } else if !linearModeUnsupported {
            // Only overwrite definition when the linear chain was safely converted
            dagDefinition = WorkflowDefinition.fromLinearSteps(steps, name: wf.name)
            wf.definition = dagDefinition
        }
        // When linearModeUnsupported, preserve the original definition
        store.saveWorkflow(wf)
    }

    private func addStep(type: WorkflowStepType) {
        let step = WorkflowStep(type: type, label: type.rawValue)
        steps.append(step)
        saveCurrent()
    }

    private func updateStep(_ updated: WorkflowStep) {
        guard let idx = steps.firstIndex(where: { $0.id == updated.id }) else { return }
        steps[idx] = updated
        saveCurrent()
    }

    private func updateNode(_ updated: WorkflowNode) {
        guard let idx = dagDefinition.nodes.firstIndex(where: { $0.id == updated.id }) else { return }
        dagDefinition.nodes[idx] = updated
        saveCurrent()
    }
}

// MARK: - Step Row

struct StepRow: View {
    let step: WorkflowStep
    let index: Int
    let isRunning: Bool
    let runStatus: StepRunStatus?
    let runResult: StepResult?
    let runError: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: step.type.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.body)
                Text(stepConfigSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isRunning, let status = runStatus {
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .foregroundColor(status.color)
                    Text(status.displayName)
                        .font(.caption)
                        .foregroundColor(status.color)
                }
            }

            if let error = runError, runStatus == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .help(error)
            }

            if let result = runResult, runStatus == .succeeded {
                Text(result.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var stepConfigSummary: String {
        switch step.type {
        case .textInput:
            let t = step.config.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "未配置" : String(t.prefix(40))
        case .promptTemplate:
            let t = step.config.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "未配置" : String(t.prefix(40))
        case .imageGen:
            return "\(step.config.imageGenType) · \(step.config.imageChannel) · \(step.config.imageAspectRatio)"
        case .videoGen:
            return "\(step.config.videoGenType) · \(step.config.videoMode) · \(step.config.videoDuration)s"
        case .resultOutput:
            return step.config.outputLabel
        }
    }
}

// MARK: - Step Config Sheet

struct StepConfigSheet: View {
    let step: WorkflowStep
    let onSave: (WorkflowStep) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var config: WorkflowStepConfig
    @State private var label: String
    @FocusState private var focusedField: FocusedField?
    @AppStorage("workflow.advanced.imageGen.expanded") private var isImageAdvancedExpanded = false
    @AppStorage("workflow.advanced.videoGen.expanded") private var isVideoAdvancedExpanded = false

    private enum FocusedField: Hashable {
        case label
        case text
        case promptTemplate
        case outputLabel
    }

    init(step: WorkflowStep, onSave: @escaping (WorkflowStep) -> Void) {
        self.step = step
        self.onSave = onSave
        _config = State(initialValue: step.config)
        _label = State(initialValue: step.label)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("配置步骤: \(step.type.rawValue)")
                    .font(.headline)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("保存") {
                    var updated = step
                    updated.label = label
                    updated.config = config
                    onSave(updated)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stepLabelField
                    stepContent
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
        .onAppear {
            clearInitialFocus()
        }
    }

    private var stepLabelField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("步骤名称").font(.caption).foregroundColor(.secondary)
            TextField("", text: $label)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .label)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step.type {
        case .textInput:
            textInputConfig
        case .promptTemplate:
            promptTemplateConfig
        case .imageGen:
            imageGenConfig
        case .videoGen:
            videoGenConfig
        case .resultOutput:
            resultOutputConfig
        }
    }

    private var textInputConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文本内容").font(.caption).foregroundColor(.secondary)
            TextEditor(text: $config.text)
                .font(.body)
                .focused($focusedField, equals: .text)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
    }

    private var promptTemplateConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提示词模板").font(.caption).foregroundColor(.secondary)
            Text("使用 {{text}} 引用前一步的文本输出")
                .font(.caption2)
                .foregroundColor(.secondary)
            TextEditor(text: $config.promptTemplate)
                .font(.body)
                .focused($focusedField, equals: .promptTemplate)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
    }

    private var imageGenConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("生成类型", selection: $config.imageGenType) {
                Text("GPT-Image-2").tag("gpt-image")
                Text("Banana").tag("banana")
            }
            .pickerStyle(.segmented)

            if config.imageGenType == "gpt-image" {
                Picker("渠道", selection: $config.imageChannel) {
                    Text("Official").tag("official")
                    Text("Budget").tag("budget")
                }
                .pickerStyle(.segmented)

                Picker("宽高比", selection: $config.imageAspectRatio) {
                    ForEach(Self.imageAspectRatioOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)

                DisclosureGroup("高级参数", isExpanded: $isImageAdvancedExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("分辨率", selection: $config.imageResolution) {
                            Text("1K").tag("1k")
                            Text("2K").tag("2k")
                            Text("4K").tag("4k")
                        }
                        .pickerStyle(.segmented)

                        Picker("画质", selection: $config.imageQuality) {
                            Text("低").tag("low")
                            Text("中").tag("medium")
                            Text("高").tag("high")
                        }
                        .pickerStyle(.segmented)

                        Toggle("真实感增强", isOn: $config.imagePhotoReal)
                    }
                }
            }
        }
    }

    private var videoGenConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("视频类型", selection: $config.videoGenType) {
                Text("Veo").tag("veo")
                Text("Grok").tag("grok")
                Text("Seedance").tag("seedance")
            }
            .pickerStyle(.segmented)
            .onChange(of: config.videoGenType) { _, newType in
                switch newType {
                case "veo":
                    config.videoMode = "text"
                    config.videoModel = "fast"
                    config.videoChannel = "budget"
                    config.videoAspectRatio = "9:16"
                    config.videoResolution = "720p"
                    config.videoDuration = "8"
                    config.videoGenerateAudio = false
                case "grok":
                    config.videoMode = "text"
                    config.videoChannel = "budget"
                    config.videoAspectRatio = "9:16"
                    config.videoResolution = "720p"
                    config.videoDuration = "8"
                case "seedance":
                    config.videoMode = "reference"
                    config.videoModel = "dreamina-seedance-2-0-260128"
                    config.videoAspectRatio = "adaptive"
                    config.videoResolution = "720p"
                    config.videoDuration = "5"
                    config.videoGenerateAudio = true
                default:
                    break
                }
            }

            if config.videoGenType == "veo" {
                Picker("渠道", selection: $config.videoChannel) {
                    ForEach(VeoRules.channels, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: config.videoChannel) { _, _ in
                    syncVeoConfig()
                }

                let models = VeoRules.validModels(channel: config.videoChannel).map { ($0.1, $0.0) }
                Picker("模型", selection: $config.videoModel) {
                    ForEach(models, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: config.videoModel) { _, _ in
                    syncVeoConfig()
                }

                Picker("模式", selection: $config.videoMode) {
                    ForEach(veoWorkflowModeOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Picker("时长", selection: $config.videoDuration) {
                    ForEach(VeoRules.workflowDurationOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)

                DisclosureGroup("高级参数", isExpanded: $isVideoAdvancedExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("宽高比", selection: $config.videoAspectRatio) {
                            Text("9:16").tag("9:16")
                            Text("16:9").tag("16:9")
                            Text("1:1").tag("1:1")
                        }
                        .pickerStyle(.menu)

                        Picker("分辨率", selection: $config.videoResolution) {
                            ForEach(VeoRules.validResolutions(channel: config.videoChannel, model: config.videoModel, mode: config.videoMode), id: \.0) { value, label in
                                Text(label).tag(value)
                            }
                        }
                        .pickerStyle(.menu)

                        if VeoRules.supportsAudio(channel: config.videoChannel, model: config.videoModel, mode: config.videoMode) {
                            Toggle("生成音频", isOn: $config.videoGenerateAudio)
                        }

                        if VeoRules.supportsNegativePrompt(channel: config.videoChannel) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("反向提示词").font(.caption).foregroundColor(.secondary)
                                TextField("不希望出现的内容...", text: $config.videoNegativePrompt)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
            } else if config.videoGenType == "grok" {
                Picker("渠道", selection: $config.videoChannel) {
                    Text("低价渠道").tag("budget")
                    Text("官方稳定渠道").tag("official")
                    Text("Grok 官方 API").tag("xai")
                }
                .pickerStyle(.segmented)
                .onChange(of: config.videoChannel) { _, _ in
                    syncGrokConfig()
                }

                Picker("模式", selection: $config.videoMode) {
                    ForEach(grokWorkflowModeOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: config.videoMode) { _, _ in
                    syncGrokConfig()
                }

                Picker("时长", selection: $config.videoDuration) {
                    ForEach(grokDurationOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)

                DisclosureGroup("高级参数", isExpanded: $isVideoAdvancedExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("宽高比", selection: $config.videoAspectRatio) {
                            ForEach(grokAspectRatioOptions, id: \.0) { value, label in
                                Text(label).tag(value)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("分辨率", selection: $config.videoResolution) {
                            Text("720p").tag("720p")
                            Text("480p").tag("480p")
                        }
                        .pickerStyle(.menu)
                    }
                }
            } else if config.videoGenType == "seedance" {
                Picker("模式", selection: $config.videoMode) {
                    Text("Reference").tag("reference")
                    Text("首尾帧").tag("first_last")
                }
                .pickerStyle(.segmented)

                Picker("模型", selection: $config.videoModel) {
                    Text("标准版").tag("dreamina-seedance-2-0-260128")
                    Text("快速版").tag("dreamina-seedance-2-0-fast-260128")
                }
                .pickerStyle(.menu)

                Picker("时长", selection: $config.videoDuration) {
                    ForEach((4...15).map { "\($0)" }, id: \.self) { duration in
                        Text("\(duration)s").tag(duration)
                    }
                }
                .pickerStyle(.menu)

                DisclosureGroup("高级参数", isExpanded: $isVideoAdvancedExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("比例", selection: $config.videoAspectRatio) {
                            Text("自适应").tag("adaptive")
                            Text("9:16").tag("9:16")
                            Text("16:9").tag("16:9")
                            Text("4:3").tag("4:3")
                            Text("1:1").tag("1:1")
                            Text("3:4").tag("3:4")
                            Text("21:9").tag("21:9")
                        }
                        .pickerStyle(.menu)

                        Picker("分辨率", selection: $config.videoResolution) {
                            Text("480p").tag("480p")
                            Text("720p").tag("720p")
                            Text("1080p").tag("1080p")
                        }
                        .pickerStyle(.menu)

                        Picker("数量", selection: $config.videoCount) {
                            ForEach(1...4, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("生成音频", isOn: $config.videoGenerateAudio)
                    }
                }
            }
        }
    }

    /// Workflow-safe Veo modes: only modes that don't require local file uploads
    private var veoWorkflowModeOptions: [(String, String)] {
        let workflowSafe: Set<String> = ["text", "image"]
        return VeoRules.validModes(channel: config.videoChannel, model: config.videoModel).filter { workflowSafe.contains($0.0) }
    }

    private var grokWorkflowModeOptions: [(String, String)] {
        if config.videoChannel == "budget" {
            return [("text", "文生视频")]
        }
        return [("text", "文生视频")]
    }

    private var grokAspectRatioOptions: [(String, String)] {
        [("9:16", "9:16"), ("16:9", "16:9"), ("1:1", "1:1"), ("2:3", "2:3"), ("3:2", "3:2")]
    }

    private var grokDurationOptions: [(String, String)] {
        if config.videoChannel == "official" || config.videoChannel == "xai" {
            return [("6", "6s"), ("10", "10s")]
        }
        return [("6", "6s"), ("8", "8s"), ("10", "10s"), ("12", "12s"), ("15", "15s"), ("20", "20s"), ("30", "30s")]
    }

    private func syncVeoConfig() {
        let validModels = VeoRules.validModelValues(channel: config.videoChannel)
        if !validModels.isEmpty, !validModels.contains(config.videoModel) {
            config.videoModel = validModels.first ?? "fast"
        }
        let allowed = veoWorkflowModeOptions.map(\.0)
        if !allowed.contains(config.videoMode) {
            config.videoMode = allowed.first ?? "text"
        }
        if !VeoRules.supportsAudio(channel: config.videoChannel, model: config.videoModel, mode: config.videoMode) {
            config.videoGenerateAudio = false
        }
        let resolutions = VeoRules.validResolutions(channel: config.videoChannel, model: config.videoModel, mode: config.videoMode)
        if !resolutions.contains(where: { $0.0 == config.videoResolution }) {
            config.videoResolution = resolutions.first?.0 ?? "720p"
        }
    }

    private func syncGrokConfig() {
        let allowedModes = grokWorkflowModeOptions.map(\.0)
        if !allowedModes.contains(config.videoMode) {
            config.videoMode = allowedModes.first ?? "text"
        }
        let allowedDurations = grokDurationOptions.map(\.0)
        if !allowedDurations.contains(config.videoDuration) {
            config.videoDuration = allowedDurations.first ?? "6"
        }
        if config.videoResolution != "720p", config.videoResolution != "480p" {
            config.videoResolution = "720p"
        }
    }

    private var resultOutputConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输出标签").font(.caption).foregroundColor(.secondary)
            TextField("", text: $config.outputLabel)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .outputLabel)
        }
    }

    private func clearInitialFocus() {
        focusedField = nil
        DispatchQueue.main.async {
            focusedField = nil
        }
    }

    private static let imageAspectRatioOptions: [(String, String)] = [
        ("9:16", "9:16"), ("16:9", "16:9"), ("1:1", "1:1"),
        ("2:3", "2:3"), ("3:2", "3:2"), ("4:3", "4:3"),
        ("3:4", "3:4"), ("4:5", "4:5"), ("5:4", "5:4"), ("21:9", "21:9")
    ]
}

// MARK: - Node Config Sheet

struct NodeConfigSheet: View {
    let node: WorkflowNode
    let onSave: (WorkflowNode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var config: WorkflowNodeConfig
    @FocusState private var focusedField: FocusedField?
    @AppStorage("workflow.advanced.imageGen.expanded") private var isImageAdvancedExpanded = false
    @AppStorage("workflow.advanced.videoGen.expanded") private var isVideoAdvancedExpanded = false

    private enum FocusedField: Hashable {
        case title
        case text
        case promptTemplate
        case videoModel
        case negativePrompt
        case outputLabel
    }

    init(node: WorkflowNode, onSave: @escaping (WorkflowNode) -> Void) {
        self.node = node
        self.onSave = onSave
        _title = State(initialValue: node.title)
        _config = State(initialValue: node.config)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("配置节点: \(node.type.displayName)")
                    .font(.headline)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("保存") {
                    var updated = node
                    updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? node.type.displayName
                        : title
                    updated.config = config
                    onSave(updated)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nodeTitleField
                    nodeContent
                }
                .padding()
            }
        }
        .frame(width: 520, height: 520)
        .onAppear {
            clearInitialFocus()
        }
    }

    private var nodeTitleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("节点名称").font(.caption).foregroundColor(.secondary)
            TextField("", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title)
        }
    }

    @ViewBuilder
    private var nodeContent: some View {
        switch config {
        case .textInput:
            textInputConfig
        case .promptTemplate:
            promptTemplateConfig
        case .imageGen:
            imageGenConfig
        case .videoGen:
            videoGenConfig
        case .resultOutput:
            resultOutputConfig
        }
    }

    private var textInputConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文本内容").font(.caption).foregroundColor(.secondary)
            TextEditor(text: textInputText)
                .font(.body)
                .focused($focusedField, equals: .text)
                .frame(minHeight: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
    }

    private var promptTemplateConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提示词模板").font(.caption).foregroundColor(.secondary)
            Text("使用 {{text}} 引用输入文本")
                .font(.caption2)
                .foregroundColor(.secondary)
            TextEditor(text: promptTemplateText)
                .font(.body)
                .focused($focusedField, equals: .promptTemplate)
                .frame(minHeight: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
    }

    private var imageGenConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("生成类型", selection: imageGenType) {
                Text("GPT-Image").tag(ImageGenType.gptImage)
                Text("Banana").tag(ImageGenType.banana)
            }
            .pickerStyle(.segmented)
            .onChange(of: imageGenType.wrappedValue) { _, _ in
                syncImageConfig()
            }

            if imageGenType.wrappedValue == .gptImage {
                Picker("渠道", selection: imageChannel) {
                    Text("官方").tag(ImageChannel.official)
                    Text("低价").tag(ImageChannel.budget)
                }
                .pickerStyle(.segmented)

                Picker("比例", selection: imageAspectRatio) {
                    ForEach(Self.imageAspectRatios, id: \.self) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                .pickerStyle(.menu)

                DisclosureGroup("高级参数", isExpanded: $isImageAdvancedExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("分辨率", selection: imageResolution) {
                            ForEach(ImageResolution.allCases, id: \.self) { resolution in
                                Text(resolution.rawValue.uppercased()).tag(resolution)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("画质", selection: imageQuality) {
                            Text("低").tag(ImageQuality.low)
                            Text("中").tag(ImageQuality.medium)
                            Text("高").tag(ImageQuality.high)
                        }
                        .pickerStyle(.segmented)

                        Toggle("真实感增强", isOn: imagePhotoReal)
                    }
                }
            }
        }
    }

    private var videoGenConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("视频类型", selection: videoGenType) {
                Text("Veo").tag(VideoGenType.veo)
                Text("Grok").tag(VideoGenType.grok)
                Text("Seedance").tag(VideoGenType.seedance)
            }
            .pickerStyle(.segmented)
            .onChange(of: videoGenType.wrappedValue) { _, _ in
                syncVideoConfig()
            }

            if !videoChannelOptions.isEmpty {
                Picker("渠道", selection: videoChannel) {
                    ForEach(videoChannelOptions, id: \.0) { channel, label in
                        Text(label).tag(channel)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: videoChannel.wrappedValue) { _, _ in
                    syncVideoConfig()
                }
            }

            if videoGenType.wrappedValue == .veo {
                Picker("模型", selection: videoModel) {
                    ForEach(VeoRules.validModels(channel: videoChannel.wrappedValue.rawValue), id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: videoModel.wrappedValue) { _, _ in
                    syncVideoConfig()
                }
            } else if videoGenType.wrappedValue == .seedance {
                Picker("模型", selection: videoModel) {
                    Text("标准版").tag("dreamina-seedance-2-0-260128")
                    Text("快速版").tag("dreamina-seedance-2-0-fast-260128")
                }
                .pickerStyle(.segmented)
            }

            Picker("模式", selection: videoMode) {
                ForEach(videoModeOptions, id: \.0) { mode, label in
                    Text(label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: videoMode.wrappedValue) { _, _ in
                syncVideoConfig()
            }

            if showVideoDuration {
                Picker("时长", selection: videoDuration) {
                    ForEach(videoDurationOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)
            } else if let fixed = fixedVideoDuration {
                HStack {
                    Text("时长").font(.caption).foregroundColor(.secondary)
                    Text("固定 \(fixed)s").font(.caption).foregroundColor(.secondary)
                }
            }

            DisclosureGroup("高级参数", isExpanded: $isVideoAdvancedExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    if showVideoAspectRatio {
                        Picker("比例", selection: videoAspectRatio) {
                            ForEach(videoAspectRatioOptions, id: \.self) { ratio in
                                Text(ratio.rawValue == "adaptive" ? "智能" : ratio.rawValue).tag(ratio)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Picker("分辨率", selection: videoResolution) {
                        ForEach(videoResolutionOptions, id: \.self) { resolution in
                            Text(resolution.rawValue.uppercased()).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)

                    if videoGenType.wrappedValue == .seedance {
                        Picker("数量", selection: videoCount) {
                            ForEach(1...4, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if showVideoAudio {
                        Toggle("生成音频", isOn: videoGenerateAudio)
                    }

                    if videoGenType.wrappedValue == .veo && VeoRules.supportsNegativePrompt(channel: videoChannel.wrappedValue.rawValue) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("反向提示词").font(.caption).foregroundColor(.secondary)
                            TextField("不希望出现的内容...", text: videoNegativePrompt)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .negativePrompt)
                        }
                    }
                }
            }
        }
    }

    private var resultOutputConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输出标签").font(.caption).foregroundColor(.secondary)
            TextField("", text: resultOutputLabel)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .outputLabel)
        }
    }

    private func clearInitialFocus() {
        focusedField = nil
        DispatchQueue.main.async {
            focusedField = nil
        }
    }

    private var textInputText: Binding<String> {
        Binding(
            get: {
                if case .textInput(let current) = config { return current.text }
                return ""
            },
            set: { newValue in
                if case .textInput(var current) = config {
                    current.text = newValue
                    config = .textInput(current)
                }
            }
        )
    }

    private var promptTemplateText: Binding<String> {
        Binding(
            get: {
                if case .promptTemplate(let current) = config { return current.template }
                return ""
            },
            set: { newValue in
                if case .promptTemplate(var current) = config {
                    current.template = newValue
                    config = .promptTemplate(current)
                }
            }
        )
    }

    private var imageGenType: Binding<ImageGenType> {
        imageBinding(\.genType) { $0.genType = $1 }
    }

    private var imageChannel: Binding<ImageChannel> {
        imageBinding(\.channel) { $0.channel = $1 }
    }

    private var imageAspectRatio: Binding<AspectRatio> {
        imageBinding(\.aspectRatio) { $0.aspectRatio = $1 }
    }

    private var imageResolution: Binding<ImageResolution> {
        imageBinding(\.resolution) { $0.resolution = $1 }
    }

    private var imageQuality: Binding<ImageQuality> {
        imageBinding(\.quality) { $0.quality = $1 }
    }

    private var imagePhotoReal: Binding<Bool> {
        imageBinding(\.photoReal) { $0.photoReal = $1 }
    }

    private var videoGenType: Binding<VideoGenType> {
        videoBinding(\.genType) { $0.genType = $1 }
    }

    private var videoChannel: Binding<VideoChannel> {
        videoBinding(\.channel) { $0.channel = $1 }
    }

    private var videoModel: Binding<String> {
        videoBinding(\.model) { $0.model = $1 }
    }

    private var videoMode: Binding<VideoMode> {
        videoBinding(\.mode) { $0.mode = $1 }
    }

    private var videoAspectRatio: Binding<AspectRatio> {
        videoBinding(\.aspectRatio) { $0.aspectRatio = $1 }
    }

    private var videoResolution: Binding<VideoResolution> {
        videoBinding(\.resolution) { $0.resolution = $1 }
    }

    private var videoDuration: Binding<String> {
        videoBinding(\.duration) { $0.duration = $1 }
    }

    private var videoGenerateAudio: Binding<Bool> {
        videoBinding(\.generateAudio) { $0.generateAudio = $1 }
    }

    private var videoNegativePrompt: Binding<String> {
        videoBinding(\.negativePrompt) { $0.negativePrompt = $1 }
    }

    private var videoCount: Binding<Int> {
        videoBinding(\.count) { $0.count = $1 }
    }

    private var resultOutputLabel: Binding<String> {
        Binding(
            get: {
                if case .resultOutput(let current) = config { return current.label }
                return ""
            },
            set: { newValue in
                if case .resultOutput(var current) = config {
                    current.label = newValue
                    config = .resultOutput(current)
                }
            }
        )
    }

    private func imageBinding<Value>(
        _ keyPath: KeyPath<ImageGenNodeConfig, Value>,
        _ update: @escaping (inout ImageGenNodeConfig, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: {
                if case .imageGen(let current) = config { return current[keyPath: keyPath] }
                fatalError("Invalid image node binding")
            },
            set: { newValue in
                if case .imageGen(var current) = config {
                    update(&current, newValue)
                    config = .imageGen(current)
                }
            }
        )
    }

    private func videoBinding<Value>(
        _ keyPath: KeyPath<VideoGenNodeConfig, Value>,
        _ update: @escaping (inout VideoGenNodeConfig, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: {
                if case .videoGen(let current) = config { return current[keyPath: keyPath] }
                fatalError("Invalid video node binding")
            },
            set: { newValue in
                if case .videoGen(var current) = config {
                    update(&current, newValue)
                    config = .videoGen(current)
                }
            }
        )
    }

    private static let imageAspectRatios: [AspectRatio] = [
        .portrait, .landscape, .square, .twoThree, .threeTwo,
        .fourThree, .threeFour, .fourFive, .fiveFour, .twentyOneNine
    ]

    private func syncImageConfig() {
        if imageGenType.wrappedValue == .banana {
            imageChannel.wrappedValue = .budget
            imagePhotoReal.wrappedValue = false
            return
        }
        if !Self.imageAspectRatios.contains(imageAspectRatio.wrappedValue) {
            imageAspectRatio.wrappedValue = .portrait
        }
    }

    private var videoChannelOptions: [(VideoChannel, String)] {
        switch videoGenType.wrappedValue {
        case .veo:
            return VeoRules.channels.compactMap { value, label in
                VideoChannel(rawValue: value).map { ($0, label) }
            }
        case .grok:
            return [(.budget, "低价渠道"), (.official, "官方稳定"), (.xai, "Grok API")]
        case .seedance:
            return []
        case .wan:
            return []
        }
    }

    private var videoModeOptions: [(VideoMode, String)] {
        switch videoGenType.wrappedValue {
        case .veo:
            return VeoRules.validModes(channel: videoChannel.wrappedValue.rawValue, model: videoModel.wrappedValue)
                .filter { $0.0 != "extend" }
                .compactMap { value, label in
                    VideoMode(rawValue: value).map { ($0, label) }
                }
        case .grok:
            return [(.text, "文生视频")]
        case .seedance:
            return [(.reference, "全能参考"), (.firstLast, "首尾帧")]
        case .wan:
            return []
        }
    }

    private var showVideoAspectRatio: Bool {
        switch videoGenType.wrappedValue {
        case .veo:
            return VeoRules.supportsAspectRatio(mode: videoMode.wrappedValue.rawValue)
        case .grok:
            return true
        case .seedance:
            return true
        case .wan:
            return false
        }
    }

    private var videoAspectRatioOptions: [AspectRatio] {
        switch videoGenType.wrappedValue {
        case .veo:
            return [.portrait, .landscape, .square]
        case .grok:
            return [.portrait, .landscape, .square, .twoThree, .threeTwo]
        case .seedance:
            return [.adaptive, .portrait, .landscape, .fourThree, .square, .threeFour, .twentyOneNine]
        case .wan:
            return []
        }
    }

    private var videoResolutionOptions: [VideoResolution] {
        switch videoGenType.wrappedValue {
        case .veo:
            return VeoRules.validResolutions(
                channel: videoChannel.wrappedValue.rawValue,
                model: videoModel.wrappedValue,
                mode: videoMode.wrappedValue.rawValue
            ).compactMap { VideoResolution(rawValue: $0.0) }
        case .grok:
            return [.p720, .p480]
        case .seedance:
            return [.p480, .p720, .p1080]
        case .wan:
            return []
        }
    }

    private var showVideoDuration: Bool {
        switch videoGenType.wrappedValue {
        case .veo:
            return VeoRules.supportsDuration(
                channel: videoChannel.wrappedValue.rawValue,
                model: videoModel.wrappedValue,
                mode: videoMode.wrappedValue.rawValue
            )
        case .grok, .seedance:
            return true
        case .wan:
            return false
        }
    }

    private var fixedVideoDuration: String? {
        guard videoGenType.wrappedValue == .veo else { return nil }
        return VeoRules.fixedDuration(
            channel: videoChannel.wrappedValue.rawValue,
            model: videoModel.wrappedValue,
            mode: videoMode.wrappedValue.rawValue
        )
    }

    private var videoDurationOptions: [(String, String)] {
        switch videoGenType.wrappedValue {
        case .veo:
            return VeoRules.adjustableDurationOptions
        case .grok:
            if videoChannel.wrappedValue == .official || videoChannel.wrappedValue == .xai {
                return [("6", "6s"), ("10", "10s")]
            }
            return [("6", "6s"), ("8", "8s"), ("10", "10s"), ("12", "12s"), ("15", "15s"), ("20", "20s"), ("30", "30s")]
        case .seedance:
            return (4...15).map { ("\($0)", "\($0)s") }
        case .wan:
            return []
        }
    }

    private var showVideoAudio: Bool {
        switch videoGenType.wrappedValue {
        case .veo:
            return VeoRules.supportsAudio(
                channel: videoChannel.wrappedValue.rawValue,
                model: videoModel.wrappedValue,
                mode: videoMode.wrappedValue.rawValue
            )
        case .seedance:
            return true
        case .grok, .wan:
            return false
        }
    }

    private func syncVideoConfig() {
        switch videoGenType.wrappedValue {
        case .veo:
            if videoChannel.wrappedValue == .xai {
                videoChannel.wrappedValue = .budget
            }
            let validModels = VeoRules.validModelValues(channel: videoChannel.wrappedValue.rawValue)
            if !validModels.contains(videoModel.wrappedValue) {
                videoModel.wrappedValue = validModels.first ?? "fast"
            }
        case .grok:
            if videoChannel.wrappedValue == .google || videoChannel.wrappedValue == .yunwu {
                videoChannel.wrappedValue = .budget
            }
            videoModel.wrappedValue = ""
            videoMode.wrappedValue = .text
        case .seedance:
            videoChannel.wrappedValue = .budget
            if !["dreamina-seedance-2-0-260128", "dreamina-seedance-2-0-fast-260128"].contains(videoModel.wrappedValue) {
                videoModel.wrappedValue = "dreamina-seedance-2-0-260128"
            }
            if ![VideoMode.reference, .firstLast].contains(videoMode.wrappedValue) {
                videoMode.wrappedValue = .reference
            }
        case .wan:
            break
        }

        let allowedModes = videoModeOptions.map(\.0)
        if !allowedModes.isEmpty, !allowedModes.contains(videoMode.wrappedValue) {
            videoMode.wrappedValue = allowedModes.first ?? .text
        }
        let allowedRatios = videoAspectRatioOptions
        if !allowedRatios.isEmpty, !allowedRatios.contains(videoAspectRatio.wrappedValue) {
            videoAspectRatio.wrappedValue = allowedRatios.first ?? .portrait
        }
        let allowedResolutions = videoResolutionOptions
        if !allowedResolutions.isEmpty, !allowedResolutions.contains(videoResolution.wrappedValue) {
            videoResolution.wrappedValue = allowedResolutions.first ?? .p720
        }
        let allowedDurations = videoDurationOptions.map(\.0)
        if !allowedDurations.isEmpty, !allowedDurations.contains(videoDuration.wrappedValue) {
            videoDuration.wrappedValue = allowedDurations.first ?? "8"
        }
        if !showVideoAudio {
            videoGenerateAudio.wrappedValue = false
        }
        videoCount.wrappedValue = min(max(videoCount.wrappedValue, 1), 4)
    }
}

// MARK: - Run Status Panel

struct RunStatusPanel: View {
    @EnvironmentObject var store: WorkflowStore
    let editorMode: EditorMode
    let dagDefinition: WorkflowDefinition
    @Binding var selectedNodeId: String?
    @State private var previewItem: TaskMediaPreviewItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status header
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.headline)

                if store.runState.overallStatus == .failed, editorMode == .canvas {
                    Button {
                        store.retryFromFailedNode(dagDefinition, workflowId: store.selectedWorkflow?.id ?? "", workflowName: store.selectedWorkflow?.name ?? "")
                    } label: {
                        Label("从失败处重试", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                if store.runState.isRunning {
                    Button("停止") { store.cancelRun() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Timeline section
            ScrollView {
                VStack(spacing: 2) {
                    if editorMode == .canvas {
                        ForEach(dagDefinition.nodes) { node in
                            dagNodeRunRow(node)
                                .onTapGesture {
                                    selectedNodeId = node.id
                                }
                                .background(
                                    selectedNodeId == node.id
                                        ? Color.accentColor.opacity(0.1)
                                        : Color.clear
                                )
                                .cornerRadius(4)
                        }
                    } else if let wf = store.selectedWorkflow {
                        ForEach(wf.steps) { step in
                            stepRunRow(step)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)

            // Node detail section - only for canvas mode
            if editorMode == .canvas {
                Divider()

                if let nodeId = selectedNodeId {
                    nodeDetailSection(nodeId: nodeId)
                } else {
                    VStack {
                        Spacer()
                        Text("点击节点查看详情")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(item: $previewItem) { item in
            switch item.kind {
            case .image:
                RemoteImagePreviewSheet(url: item.url)
            case .video:
                RemoteVideoPreviewSheet(url: item.url)
            }
        }
        .onChange(of: store.runState.currentStepId) { _, newStepId in
            if let stepId = newStepId, store.runState.isRunning {
                selectedNodeId = stepId
            }
        }
    }

    // MARK: - Status helpers

    private var statusIcon: String {
        switch store.runState.overallStatus {
        case .pending: return "circle"
        case .running: return "circle.dotted"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    private var statusColor: Color {
        store.runState.overallStatus.color
    }

    private var statusText: String {
        switch store.runState.overallStatus {
        case .pending: return "等待运行"
        case .running: return "运行中..."
        case .succeeded: return "运行完成"
        case .failed: return "运行失败"
        case .cancelled: return "已取消"
        }
    }

    // MARK: - Node detail section

    @ViewBuilder
    private func nodeDetailSection(nodeId: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Find node info
                if let node = dagDefinition.nodes.first(where: { $0.id == nodeId }) {
                    // Node header
                    HStack {
                        Image(systemName: node.type.icon)
                            .foregroundColor(.accentColor)
                        Text(node.title)
                            .font(.headline)
                        Spacer()
                        let status = store.runState.nodeStatuses[nodeId] ?? .pending
                        Image(systemName: status == .running ? "circle.dotted" : status.icon)
                            .foregroundColor(status.color)
                    }

                    // Status and timing
                    if let detail = store.runState.nodeDetails[nodeId] {
                        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                            GridRow {
                                Text("状态:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let status = store.runState.nodeStatuses[nodeId] ?? .pending
                                Text(status.displayName)
                                    .font(.caption)
                                    .foregroundColor(status.color)
                            }
                            if let startedAt = detail.startedAt {
                                GridRow {
                                    Text("开始时间:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(startedAt, style: .time)
                                        .font(.caption)
                                }
                            }
                            if let elapsed = detail.elapsedText {
                                GridRow {
                                    Text("耗时:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(elapsed)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Error message
                    if let error = store.runState.stepErrors[nodeId],
                       store.runState.nodeStatuses[nodeId] == .failed {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("错误信息")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // Input summary
                    if let detail = store.runState.nodeDetails[nodeId],
                       let input = detail.inputSummary, input != "无输入" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("输入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(input)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }

                    // Output summary
                    if let detail = store.runState.nodeDetails[nodeId],
                       let output = detail.outputSummary, output != "无输出" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("输出")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(output)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }

                    // Logs
                    if let logs = store.runState.nodeLogs[nodeId], !logs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("日志")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }

                    // Result preview
                    if let result = store.runState.stepResults[nodeId] {
                        nodeResultPreview(node: node, result: result)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func nodeResultPreview(node: WorkflowNode, result: StepResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("结果预览")
                .font(.caption)
                .foregroundColor(.secondary)

            switch node.type {
            case .imageGen:
                if let urlString = result.imageUrls?.first, let url = ExternalURL.sanitizedURL(urlString) {
                    Button {
                        previewItem = TaskMediaPreviewItem(url: url, kind: .image)
                    } label: {
                        Label("预览图片", systemImage: "eye")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            case .videoGen:
                if case .video(let urlString?) = result, let url = ExternalURL.sanitizedURL(urlString) {
                    Button {
                        previewItem = TaskMediaPreviewItem(url: url, kind: .video)
                    } label: {
                        Label("预览视频", systemImage: "play.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            default:
                EmptyView()
            }
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(6)
    }

    // MARK: - DAG node row

    @ViewBuilder
    private func dagNodeRunRow(_ node: WorkflowNode) -> some View {
        let status = store.runState.nodeStatuses[node.id] ?? .pending
        let detail = store.runState.nodeDetails[node.id]
        let error = store.runState.stepErrors[node.id]
        let result = store.runState.stepResults[node.id]

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: node.type.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                Image(systemName: status == .running ? "circle.dotted" : status.icon)
                    .foregroundColor(status.color)
                    .font(.caption)

                Text(node.title)
                    .font(.caption)
                    .fontWeight(status == .running ? .semibold : .regular)
                    .lineLimit(1)

                if let elapsed = detail?.elapsedText {
                    Text(elapsed)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                if let error, status == .failed {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                // Preview buttons for image/video results
                if status == .succeeded {
                    nodeResultActions(node: node, result: result)
                }
            }

            // Input/output summary row
            if let detail, status == .succeeded || status == .failed {
                HStack(spacing: 12) {
                    if let input = detail.inputSummary, input != "无输入" {
                        Label(input, systemImage: "arrow.left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if let output = detail.outputSummary, output != "无输出" {
                        Label(output, systemImage: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func nodeResultActions(node: WorkflowNode, result: StepResult?) -> some View {
        HStack(spacing: 4) {
            switch node.type {
            case .imageGen:
                if let urlString = result?.imageUrls?.first, let url = ExternalURL.sanitizedURL(urlString) {
                    Button {
                        previewItem = TaskMediaPreviewItem(url: url, kind: .image)
                    } label: {
                        Image(systemName: "eye")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help("预览图片")
                }
            case .videoGen:
                if case .video(let urlString?) = result, let url = ExternalURL.sanitizedURL(urlString) {
                    Button {
                        previewItem = TaskMediaPreviewItem(url: url, kind: .video)
                    } label: {
                        Image(systemName: "play.circle")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help("预览视频")
                }
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Linear step row

    @ViewBuilder
    private func stepRunRow(_ step: WorkflowStep) -> some View {
        let status = store.runState.stepStates[step.id] ?? .pending
        let result = store.runState.stepResults[step.id]
        let error = store.runState.stepErrors[step.id]

        HStack(spacing: 8) {
            Image(systemName: step.type.icon)
                .frame(width: 20)

            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.caption)

            Text(step.label)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            if let result, status == .succeeded {
                Text(result.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if let error, status == .failed {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Workflow List Sheet

struct WorkflowListSheet: View {
    @EnvironmentObject var store: WorkflowStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("已保存的工作流")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding()

            Divider()

            if store.workflows.isEmpty {
                VStack(spacing: 12) {
                    Text("暂无保存的工作流")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            } else {
                List {
                    ForEach(store.workflows) { wf in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wf.name)
                                    .font(.body)
                                Text("\(wf.steps.count) 个步骤 · \(wf.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if wf.id == store.selectedWorkflowId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectedWorkflowId = wf.id
                            dismiss()
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.workflows[$0].id }
                        for id in ids { store.deleteWorkflow(id) }
                    }
                }
            }
        }
        .frame(width: 400, height: 400)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("欢迎使用工作流")
                .font(.title)

            VStack(spacing: 16) {
                OnboardingStepView(
                    icon: "text.cursor",
                    title: "输入",
                    description: "添加文本输入或提示词模板节点"
                )
                OnboardingStepView(
                    icon: "photo.badge.plus",
                    title: "生成",
                    description: "连接图片或视频生成节点"
                )
                OnboardingStepView(
                    icon: "arrow.down.to.line",
                    title: "输出",
                    description: "添加结果输出节点查看生成内容"
                )
            }

            Text("从模板开始，或创建空白工作流自己搭建")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("开始使用") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(width: 400)
    }
}

struct OnboardingStepView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    WorkflowEditorView()
        .environmentObject(WorkflowStore(api: APIService.shared))
}
