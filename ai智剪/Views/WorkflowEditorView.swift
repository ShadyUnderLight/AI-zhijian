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
    @State private var editorMode: EditorMode = .canvas
    @State private var dagDefinition: WorkflowDefinition = WorkflowDefinition(name: "未命名工作流")

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
        }
        .onChange(of: store.selectedWorkflowId) { _, _ in
            syncFromStore()
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
                ForEach(WorkflowDefinition.templates) { template in
                    Button {
                        createFromTemplate(template)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: template.icon)
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor)
                            Text(template.name)
                                .font(.headline)
                            Text(template.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
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
                }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func workflowContent(_ wf: Workflow) -> some View {
        HStack {
            TextField("工作流名称", text: $workflowName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .onSubmit { saveCurrent() }

            Spacer()

            // Editor Mode Picker
            Picker("编辑模式", selection: $editorMode) {
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
                ForEach(WorkflowDefinition.templates) { template in
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
                        saveCurrent()
                        if editorMode == .canvas {
                            store.runWorkflowDefinition(dagDefinition, workflowId: store.selectedWorkflow?.id ?? "", workflowName: workflowName)
                        } else {
                            store.runWorkflow(store.selectedWorkflow!)
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

        if store.runState.isRunning || store.runState.overallStatus == .succeeded || store.runState.overallStatus == .failed {
            Divider()
            RunStatusPanel(editorMode: editorMode, dagDefinition: dagDefinition)
                .frame(maxHeight: 240)
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
                guard !store.runState.isRunning else { return }
                editingNode = node
                showNodeConfig = true
            },
            onNodeDelete: { nodeId in
                if editingNode?.id == nodeId {
                    editingNode = nil
                    showNodeConfig = false
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
        }
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

                Picker("宽高比", selection: $config.imageAspectRatio) {
                    Text("1:1").tag("1:1")
                    Text("9:16").tag("9:16")
                    Text("16:9").tag("16:9")
                    Text("3:4").tag("3:4")
                    Text("4:3").tag("4:3")
                }
                .pickerStyle(.menu)

                Toggle("照片真实感", isOn: $config.imagePhotoReal)
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

                Picker("时长", selection: $config.videoDuration) {
                    ForEach(VeoRules.workflowDurationOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)

                if VeoRules.supportsAudio(channel: config.videoChannel, model: config.videoModel, mode: config.videoMode) {
                    Toggle("生成音频", isOn: $config.videoGenerateAudio)
                }
            } else if config.videoGenType == "grok" {
                Picker("渠道", selection: $config.videoChannel) {
                    Text("低价渠道").tag("budget")
                    Text("官方稳定渠道").tag("official")
                    Text("Grok 官方 API").tag("xai")
                }
                .pickerStyle(.segmented)

                Picker("模式", selection: $config.videoMode) {
                    Text("文生视频").tag("text")
                }
                .pickerStyle(.segmented)

                Picker("宽高比", selection: $config.videoAspectRatio) {
                    Text("9:16").tag("9:16")
                    Text("16:9").tag("16:9")
                    Text("1:1").tag("1:1")
                }
                .pickerStyle(.menu)

                Picker("分辨率", selection: $config.videoResolution) {
                    Text("720p").tag("720p")
                    Text("1080p").tag("1080p")
                }
                .pickerStyle(.menu)

                Picker("时长", selection: $config.videoDuration) {
                    Text("6s").tag("6")
                    Text("8s").tag("8")
                    Text("10s").tag("10")
                    Text("30s").tag("30")
                }
                .pickerStyle(.menu)
            } else if config.videoGenType == "seedance" {
                Picker("模式", selection: $config.videoMode) {
                    Text("Reference").tag("reference")
                    Text("首尾帧").tag("first_last")
                }
                .pickerStyle(.segmented)

                Picker("模型", selection: $config.videoModel) {
                    Text("Seedance 2.0").tag("dreamina-seedance-2-0-260128")
                }
                .pickerStyle(.menu)

                Picker("比例", selection: $config.videoAspectRatio) {
                    Text("自适应").tag("adaptive")
                    Text("9:16").tag("9:16")
                    Text("16:9").tag("16:9")
                    Text("1:1").tag("1:1")
                }
                .pickerStyle(.menu)

                Picker("分辨率", selection: $config.videoResolution) {
                    Text("720p").tag("720p")
                    Text("1080p").tag("1080p")
                }
                .pickerStyle(.menu)

                Picker("时长", selection: $config.videoDuration) {
                    Text("4s").tag("4")
                    Text("5s").tag("5")
                    Text("8s").tag("8")
                    Text("10s").tag("10")
                    Text("15s").tag("15")
                }
                .pickerStyle(.menu)

                Toggle("生成音频", isOn: $config.videoGenerateAudio)
            }
        }
    }

    /// Workflow-safe Veo modes: only modes that don't require local file uploads
    private var veoWorkflowModeOptions: [(String, String)] {
        let workflowSafe: Set<String> = ["text", "image"]
        return VeoRules.validModes(channel: config.videoChannel, model: config.videoModel).filter { workflowSafe.contains($0.0) }
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
}

// MARK: - Node Config Sheet

struct NodeConfigSheet: View {
    let node: WorkflowNode
    let onSave: (WorkflowNode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var config: WorkflowNodeConfig
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case title
        case text
        case promptTemplate
        case videoModel
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

            Picker("比例", selection: imageAspectRatio) {
                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                    Text(ratio.rawValue).tag(ratio)
                }
            }
            .pickerStyle(.segmented)

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

            Toggle("照片真实感", isOn: imagePhotoReal)
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

            Picker("渠道", selection: videoChannel) {
                Text("Official").tag(VideoChannel.official)
                Text("Budget").tag(VideoChannel.budget)
                Text("Google").tag(VideoChannel.google)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                Text("模型").font(.caption).foregroundColor(.secondary)
                TextField("", text: videoModel)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .videoModel)
            }

            Picker("模式", selection: videoMode) {
                Text("文生").tag(VideoMode.text)
                Text("图生").tag(VideoMode.image)
                Text("参考图").tag(VideoMode.reference)
                Text("首尾帧").tag(VideoMode.firstLast)
            }
            .pickerStyle(.segmented)

            Picker("比例", selection: videoAspectRatio) {
                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                    Text(ratio.rawValue).tag(ratio)
                }
            }
            .pickerStyle(.segmented)

            Picker("分辨率", selection: videoResolution) {
                Text("720p").tag(VideoResolution.p720)
                Text("1080p").tag(VideoResolution.p1080)
            }
            .pickerStyle(.segmented)

            Picker("时长", selection: videoDuration) {
                ForEach(["4", "5", "6", "8", "10", "15", "30"], id: \.self) { duration in
                    Text("\(duration)s").tag(duration)
                }
            }
            .pickerStyle(.menu)

            Toggle("生成音频", isOn: videoGenerateAudio)
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
}

// MARK: - Run Status Panel

struct RunStatusPanel: View {
    @EnvironmentObject var store: WorkflowStore
    let editorMode: EditorMode
    let dagDefinition: WorkflowDefinition
    @State private var previewItem: TaskMediaPreviewItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            ScrollView {
                VStack(spacing: 2) {
                    if editorMode == .canvas {
                        ForEach(dagDefinition.nodes) { node in
                            dagNodeRunRow(node)
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
        }
        .sheet(item: $previewItem) { item in
            switch item.kind {
            case .image:
                RemoteImagePreviewSheet(url: item.url)
            case .video:
                RemoteVideoPreviewSheet(url: item.url)
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

#Preview {
    WorkflowEditorView()
        .environmentObject(WorkflowStore(api: APIService.shared))
}
