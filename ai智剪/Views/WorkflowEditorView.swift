import SwiftUI

struct WorkflowEditorView: View {
    @EnvironmentObject var store: WorkflowStore
    @State private var workflowName: String = ""
    @State private var steps: [WorkflowStep] = []
    @State private var editingStep: WorkflowStep?
    @State private var showStepConfig = false
    @State private var showWorkflowList = false

    var body: some View {
        VStack(spacing: 0) {
            if let wf = store.selectedWorkflow {
                workflowContent(wf)
            } else {
                emptyState
            }
        }
        .onAppear {
            if store.selectedWorkflow == nil {
                _ = store.createWorkflow()
            }
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
        .sheet(isPresented: $showWorkflowList) {
            WorkflowListSheet()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("还没有工作流")
                .font(.title2)
            Text("点击「新建工作流」创建你的第一条自动化流程")
                .foregroundColor(.secondary)
            Button {
                _ = store.createWorkflow()
                syncFromStore()
            } label: {
                Label("新建工作流", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
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

            Button { showWorkflowList = true } label: {
                Label("打开", systemImage: "folder")
            }
            .help("打开已保存的工作流")

            Button { createNew() } label: {
                Label("新建", systemImage: "plus")
            }

            Button { saveCurrent() } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)

            if !steps.isEmpty {
                Button {
                    if store.runState.isRunning {
                        store.cancelRun()
                    } else {
                        saveCurrent()
                        store.runWorkflow(store.selectedWorkflow!)
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

        if store.runState.isRunning || store.runState.overallStatus == .succeeded || store.runState.overallStatus == .failed {
            Divider()
            RunStatusPanel()
                .frame(maxHeight: 200)
        }
    }

    // MARK: - Actions

    private func syncFromStore() {
        if let wf = store.selectedWorkflow {
            workflowName = wf.name
            steps = wf.steps
        }
    }

    private func createNew() {
        saveCurrent()
        _ = store.createWorkflow()
        syncFromStore()
    }

    private func saveCurrent() {
        guard var wf = store.selectedWorkflow else { return }
        wf.name = workflowName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "未命名工作流" : workflowName
        wf.steps = steps
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
    }

    private var stepLabelField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("步骤名称").font(.caption).foregroundColor(.secondary)
            TextField("", text: $label)
                .textFieldStyle(.roundedBorder)
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
                    Text("Budget").tag("budget")
                    Text("Official").tag("official")
                }
                .pickerStyle(.segmented)
                .onChange(of: config.videoChannel) { _, newChannel in
                    if newChannel == "budget" && config.videoModel == "lite" {
                        config.videoModel = "fast"
                    }
                    syncVeoMode()
                }

                Picker("模型", selection: $config.videoModel) {
                    if config.videoChannel == "budget" {
                        Text("Fast").tag("fast")
                        Text("Pro").tag("pro")
                    } else {
                        Text("Fast").tag("fast")
                        Text("Lite").tag("lite")
                        Text("Pro").tag("pro")
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: config.videoModel) { _, _ in
                    syncVeoMode()
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
                    Text("720p").tag("720p")
                    Text("1080p").tag("1080p")
                }
                .pickerStyle(.menu)

                Picker("时长", selection: $config.videoDuration) {
                    Text("4s").tag("4")
                    Text("6s").tag("6")
                    Text("8s").tag("8")
                    Text("12s").tag("12")
                }
                .pickerStyle(.menu)

                if config.videoChannel == "official" && config.videoModel != "lite" {
                    Toggle("生成音频", isOn: $config.videoGenerateAudio)
                }
            } else if config.videoGenType == "grok" {
                Picker("渠道", selection: $config.videoChannel) {
                    Text("Budget").tag("budget")
                    Text("Official").tag("official")
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

    private func syncVeoMode() {
        let allowed = veoWorkflowModeOptions.map(\.0)
        if !allowed.contains(config.videoMode) {
            config.videoMode = allowed.first ?? "text"
        }
        if !VeoRules.supportsAudio(channel: config.videoChannel, model: config.videoModel, mode: config.videoMode) {
            config.videoGenerateAudio = false
        }
    }

    private var resultOutputConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输出标签").font(.caption).foregroundColor(.secondary)
            TextField("", text: $config.outputLabel)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Run Status Panel

struct RunStatusPanel: View {
    @EnvironmentObject var store: WorkflowStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.headline)
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

            if let wf = store.selectedWorkflow {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(wf.steps) { step in
                            stepRunRow(step)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
    }

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
