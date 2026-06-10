import SwiftUI
import AVKit

// MARK: - 软广工作流 View

struct SoftAdWorkflowView: View {
    @EnvironmentObject var api: APIService

    // MARK: - Project List State

    @State private var projects: [SoftAdProject] = []
    @State private var selectedProject: SoftAdProject?

    // MARK: - Create / Edit Form State

    @State private var showCreateForm = false
    @State private var showEditForm = false
    @State private var editName = ""
    @State private var editProductInfo = ""
    @State private var editTarget = ""
    @State private var editingProjectId: Int?

    // MARK: - Wizard State

    @State private var currentStep = 0
    @State private var generatedScript = ""
    @State private var isGeneratingScript = false

    // Step 3: Image generation
    @State private var sceneDescs: [String] = []
    @State private var sceneImageUrls: [String: [String]] = [:]
    @State private var imageTaskIds: [String: String] = [:]
    @State private var isSubmittingImages = false

    // Step 4: Video generation
    @State private var sceneVideoUrls: [String: String] = [:]
    @State private var videoTaskIds: [String: String] = [:]
    @State private var isSubmittingVideos = false

    // Step 5: Concat
    @State private var concatVideoUrl: String?
    @State private var isConcatting = false

    // Step 6: Export
    @State private var exportUrl: String?
    @State private var isExporting = false

    // MARK: - General

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var player: AVPlayer?

    private let stepTitles = ["项目信息", "生成分镜脚本", "图片生成", "视频生成", "拼接", "导出"]

    // MARK: - Body

    var body: some View {
        Group {
            if selectedProject == nil {
                projectListView
            } else {
                wizardView
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { loadProjects() }
        .onChange(of: errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("错误", isPresented: $showError) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showCreateForm) {
            createEditForm(isCreate: true)
        }
        .sheet(isPresented: $showEditForm) {
            createEditForm(isCreate: false)
        }
    }

    // MARK: - Project List

    private var projectListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("软广项目")
                    .font(.title2).bold()
                Spacer()
                Button(action: {
                    editName = ""
                    editProductInfo = ""
                    editTarget = ""
                    showCreateForm = true
                }) {
                    Label("新建项目", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if isLoading && projects.isEmpty {
                Spacer()
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if projects.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "bag")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无项目")
                        .foregroundColor(.secondary)
                    Text("点击「新建项目」开始创建")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(projects) { project in
                    Button(action: { selectedProject = project }) {
                        projectRow(project)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("编辑") {
                            editProject(project)
                        }
                        Button("删除", role: .destructive) {
                            deleteProject(project)
                        }
                    }
                }
                .listStyle(.plain)
            }

            if isLoading && !projects.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func projectRow(_ project: SoftAdProject) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.headline)
            HStack(spacing: 12) {
                if let info = project.productInfo, !info.isEmpty {
                    Text(info)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(project.status)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            if let date = project.updatedAt ?? project.createdAt {
                Text(date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadProjects() {
        isLoading = true
        Task {
            do {
                let resp = try await api.fetchSoftAdProjects()
                await MainActor.run {
                    projects = resp.projects ?? []
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func deleteProject(_ project: SoftAdProject) {
        isLoading = true
        Task {
            do {
                _ = try await api.deleteSoftAdProject(id: project.id)
                await MainActor.run {
                    projects.removeAll { $0.id == project.id }
                    if selectedProject?.id == project.id {
                        selectedProject = nil
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func editProject(_ project: SoftAdProject) {
        editingProjectId = project.id
        editName = project.name
        editProductInfo = project.productInfo ?? ""
        editTarget = project.target ?? ""
        showEditForm = true
    }

    // MARK: - Create / Edit Form

    private func createEditForm(isCreate: Bool) -> some View {
        VStack(spacing: 16) {
            Text(isCreate ? "新建项目" : "编辑项目")
                .font(.title2).bold()
                .padding(.top, 20)

            Form {
                TextField("项目名称", text: $editName)
                TextField("产品信息", text: $editProductInfo)
                TextField("推广目标 / 要求", text: $editTarget)
            }
            .formStyle(.grouped)
            .frame(minWidth: 400, minHeight: 200)

            HStack(spacing: 12) {
                Button("取消") {
                    if isCreate {
                        showCreateForm = false
                    } else {
                        showEditForm = false
                    }
                }
                .keyboardShortcut(.escape)

                Button(isCreate ? "创建" : "保存") {
                    if isCreate {
                        createProject()
                    } else {
                        updateProject()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 20)
        }
        .padding()
    }

    private func createProject() {
        isLoading = true
        showCreateForm = false
        Task {
            do {
                let resp = try await api.createSoftAdProject(
                    name: editName.trimmingCharacters(in: .whitespaces),
                    productInfo: editProductInfo.trimmingCharacters(in: .whitespaces),
                    target: editTarget.trimmingCharacters(in: .whitespaces)
                )
                await MainActor.run {
                    if let project = resp.project {
                        projects.append(project)
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func updateProject() {
        isLoading = true
        showEditForm = false
        guard let projectId = editingProjectId else { return }
        Task {
            do {
                let resp = try await api.updateSoftAdProject(
                    id: projectId,
                    name: editName.trimmingCharacters(in: .whitespaces),
                    productInfo: editProductInfo.trimmingCharacters(in: .whitespaces),
                    target: editTarget.trimmingCharacters(in: .whitespaces)
                )
                await MainActor.run {
                    if let updated = resp.project {
                        if let idx = projects.firstIndex(where: { $0.id == updated.id }) {
                            projects[idx] = updated
                        }
                        if selectedProject?.id == updated.id {
                            selectedProject = updated
                        }
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Wizard

    private var wizardView: some View {
        VStack(spacing: 0) {
            // Top bar with back button
            HStack {
                Button(action: {
                    selectedProject = nil
                    currentStep = 0
                    resetWizardState()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回项目列表")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                if let project = selectedProject {
                    Text(project.name)
                        .font(.headline)
                }

                Spacer()

                // Edit project button
                if let project = selectedProject {
                    Button("编辑项目") {
                        editProject(project)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

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
    }

    private func resetWizardState() {
        currentStep = 0
        generatedScript = ""
        sceneDescs = []
        sceneImageUrls = [:]
        imageTaskIds = [:]
        sceneVideoUrls = [:]
        videoTaskIds = [:]
        concatVideoUrl = nil
        exportUrl = nil
        player?.pause()
        player = nil
        isGeneratingScript = false
        isSubmittingImages = false
        isSubmittingVideos = false
        isConcatting = false
        isExporting = false
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
        if currentStep == 0 {
            step1ProjectInfo
        } else if currentStep == 1 {
            step2GenerateScript
        } else if currentStep == 2 {
            step3ImageGeneration
        } else if currentStep == 3 {
            step4VideoGeneration
        } else if currentStep == 4 {
            step5Concat
        } else if currentStep == 5 {
            step6Export
        }
    }

    // MARK: - Step 1: 项目信息

    private var step1ProjectInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("项目基本信息")
                .font(.headline)

            if let project = selectedProject {
                Group {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("项目名称").font(.subheadline).foregroundColor(.secondary)
                        Text(project.name).font(.body)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("产品信息").font(.subheadline).foregroundColor(.secondary)
                        Text(project.productInfo ?? "未填写")
                            .font(.body)
                            .foregroundColor(project.productInfo == nil ? .secondary : .primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("推广目标").font(.subheadline).foregroundColor(.secondary)
                        Text(project.target ?? "未填写")
                            .font(.body)
                            .foregroundColor(project.target == nil ? .secondary : .primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("状态").font(.subheadline).foregroundColor(.secondary)
                        Text(project.status).font(.body)
                    }
                }

                Divider()

                Text("确认信息无误后，进入下一步开始生成分镜脚本。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Step 2: 生成分镜脚本

    private var step2GenerateScript: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("分镜脚本")
                    .font(.headline)
                Spacer()
                Button(action: generateScript) {
                    if isGeneratingScript {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isGeneratingScript ? "生成中..." : "生成脚本")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGeneratingScript)
            }

            if generatedScript.isEmpty && !isGeneratingScript {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("点击「生成脚本」按钮，AI 将根据项目信息自动生成分镜脚本")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if isGeneratingScript {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("AI 正在生成分镜脚本...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                TextEditor(text: $generatedScript)
                    .font(.body)
                    .frame(minHeight: 300)
                    .border(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }

    private func generateScript() {
        guard let project = selectedProject else { return }
        isGeneratingScript = true
        Task {
            do {
                let resp = try await api.generateSoftAdScript(projectId: project.id)
                await MainActor.run {
                    if let script = resp.script {
                        generatedScript = script
                    }
                    isGeneratingScript = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGeneratingScript = false
                }
            }
        }
    }

    // MARK: - Step 3: 图片生成

    private var step3ImageGeneration: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("场景图片生成")
                    .font(.headline)
                Spacer()
                if !sceneDescs.isEmpty && sceneImageUrls.isEmpty {
                    Button(action: submitImages) {
                        if isSubmittingImages {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSubmittingImages ? "提交中..." : "提交图片生成")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmittingImages)
                }
            }

            if generatedScript.isEmpty {
                Text("请先在第二步生成分镜脚本。")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else if sceneDescs.isEmpty && sceneImageUrls.isEmpty {
                VStack(spacing: 12) {
                    Text("检测到 \(countScenes()) 个场景")
                        .font(.subheadline)
                    Button("解析脚本并开始生成图片") {
                        parseScriptAndStartImages()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if isSubmittingImages {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在生成图片，请稍候...")
                        .foregroundColor(.secondary)
                    if !imageTaskIds.isEmpty {
                        Text("已提交 \(imageTaskIds.count) 个任务")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if !sceneImageUrls.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("共 \(sceneImageUrls.count) 个场景的图片已生成")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(sceneImageUrls.keys.sorted(by: numericSort), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("场景 \(key)")
                                .font(.subheadline).bold()
                            if let urls = sceneImageUrls[key] {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(urls, id: \.self) { urlStr in
                                            AsyncImage(url: URL(string: urlStr)) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 120, height: 120)
                                                        .cornerRadius(8)
                                                case .failure:
                                                    Image(systemName: "photo")
                                                        .frame(width: 120, height: 120)
                                                        .background(Color.secondary.opacity(0.1))
                                                        .cornerRadius(8)
                                                case .empty:
                                                    ProgressView()
                                                        .frame(width: 120, height: 120)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else if sceneDescs.isEmpty {
                Text("请先在第二步生成分镜脚本。")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
    }

    private func countScenes() -> Int {
        let scenes = parseScenes(from: generatedScript)
        return max(scenes.count, 1)
    }

    private func parseScriptAndStartImages() {
        sceneDescs = parseScenes(from: generatedScript)
        if sceneDescs.isEmpty {
            // Use entire script as single scene
            sceneDescs = [generatedScript]
        }
        submitImages()
    }

    private func parseScenes(from script: String) -> [String] {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Try splitting by "场景" pattern first
        let scenePattern = try? NSRegularExpression(pattern: "(?<=^|\n)\\s*[场景场景]\\s*[0-9一二三四五六七八九十]+", options: .anchorsMatchLines)
        if let pattern = scenePattern {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = pattern.matches(in: trimmed, range: range)
            if matches.count >= 2 {
                var scenes: [String] = []
                for i in 0..<matches.count {
                    let start = matches[i].range
                    let end = (i + 1 < matches.count) ? matches[i + 1].range : NSRange(location: trimmed.utf16.count, length: 0)
                    let startIdx = Range(start, in: trimmed)!
                    let endIdx = Range(end, in: trimmed)!
                    let sceneText = String(trimmed[startIdx.lowerBound..<endIdx.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sceneText.isEmpty {
                        scenes.append(sceneText)
                    }
                }
                if !scenes.isEmpty { return scenes }
            }
        }

        // Fallback: split by double newlines
        let paragraphs = trimmed.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if paragraphs.count >= 2 {
            return paragraphs
        }

        // Fallback: split by single newline
        let lines = trimmed.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if lines.count >= 2 {
            return lines
        }

        return [trimmed]
    }

    private func numericSort(_ a: String, _ b: String) -> Bool {
        let aNum = Int(a) ?? Int.max
        let bNum = Int(b) ?? Int.max
        return aNum < bNum
    }

    private func submitImages() {
        guard let project = selectedProject, !sceneDescs.isEmpty else { return }
        isSubmittingImages = true
        imageTaskIds = [:]
        sceneImageUrls = [:]

        Task {
            do {
                let resp = try await api.submitSoftAdImages(projectId: project.id, scenePrompts: sceneDescs)
                await MainActor.run {
                    if let tasks = resp.tasks {
                        for task in tasks {
                            if let index = task.sceneIndex {
                                imageTaskIds["\(index)"] = task.taskId
                            }
                        }
                    }
                }

                // Start polling
                try await pollAllImages(projectId: project.id)

                await MainActor.run {
                    isSubmittingImages = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmittingImages = false
                }
            }
        }
    }

    private func pollAllImages(projectId: Int) async throws {
        var allDone = false
        while !allDone {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

            var stillPolling = false
            var tempUrls: [String: [String]] = [:]

            for (sceneKey, taskId) in imageTaskIds {
                do {
                    let pollResp = try await api.pollSoftAdImage(projectId: projectId, taskId: taskId)
                    await MainActor.run {
                        if pollResp.status == "completed" || pollResp.status == "success" {
                            if let urls = pollResp.imageUrls, !urls.isEmpty {
                                tempUrls[sceneKey] = urls
                            }
                        } else if pollResp.status == "failed" {
                            // Mark as failed but continue
                            errorMessage = "场景 \(sceneKey) 图片生成失败"
                        } else {
                            stillPolling = true
                        }
                    }
                } catch {
                    stillPolling = true
                }
            }

            await MainActor.run {
                if !tempUrls.isEmpty {
                    sceneImageUrls.merge(tempUrls) { current, _ in current }
                }
            }

            if sceneImageUrls.count >= imageTaskIds.count {
                allDone = true
            }
            allDone = !stillPolling && sceneImageUrls.count >= imageTaskIds.count
        }
    }

    // MARK: - Step 4: 视频生成

    private var step4VideoGeneration: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("场景视频生成")
                    .font(.headline)
                Spacer()
                if !sceneImageUrls.isEmpty && sceneVideoUrls.isEmpty {
                    Button(action: submitVideos) {
                        if isSubmittingVideos {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSubmittingVideos ? "提交中..." : "提交视频生成")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmittingVideos)
                }
            }

            if sceneImageUrls.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "video")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("请先在第三步生成场景图片。")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if isSubmittingVideos {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在生成视频，请稍候...")
                        .foregroundColor(.secondary)
                    if !videoTaskIds.isEmpty {
                        Text("已提交 \(videoTaskIds.count) 个任务")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if !sceneVideoUrls.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("共 \(sceneVideoUrls.count) 个场景的视频已生成")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(sceneVideoUrls.keys.sorted(by: numericSort), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("场景 \(key)")
                                .font(.subheadline).bold()
                            if let urlStr = sceneVideoUrls[key], let url = URL(string: urlStr) {
                                let avPlayer = AVPlayer(url: url)
                                AppKitVideoPlayerView(player: avPlayer)
                                    .frame(height: 180)
                                    .cornerRadius(8)
                                    .onDisappear {
                                        avPlayer.pause()
                                    }
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("已解析 \(sceneImageUrls.count) 个场景的图片")
                        .font(.subheadline)
                    Button("开始生成视频") {
                        submitVideos()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    private func submitVideos() {
        guard let project = selectedProject, !sceneImageUrls.isEmpty else { return }
        isSubmittingVideos = true
        videoTaskIds = [:]
        sceneVideoUrls = [:]

        // Build a single list of image URLs (one per scene)
        let sortedKeys = sceneImageUrls.keys.sorted(by: numericSort)
        let sceneImageUrlsList: [String] = sortedKeys.compactMap { key in
            sceneImageUrls[key]?.first
        }

        Task {
            do {
                let resp = try await api.submitSoftAdVideos(projectId: project.id, sceneImageUrls: sceneImageUrlsList)
                await MainActor.run {
                    if let tasks = resp.tasks {
                        for task in tasks {
                            if let index = task.sceneIndex {
                                videoTaskIds["\(index)"] = task.taskId
                            }
                        }
                    }
                }

                // Start polling
                try await pollAllVideos(projectId: project.id)

                await MainActor.run {
                    isSubmittingVideos = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmittingVideos = false
                }
            }
        }
    }

    private func pollAllVideos(projectId: Int) async throws {
        var allDone = false
        while !allDone {
            try await Task.sleep(nanoseconds: 3_000_000_000)

            var stillPolling = false
            var tempUrls: [String: String] = [:]

            for (sceneKey, taskId) in videoTaskIds {
                do {
                    let pollResp = try await api.pollSoftAdVideo(projectId: projectId, taskId: taskId)
                    await MainActor.run {
                        if pollResp.status == "completed" || pollResp.status == "success" {
                            if let url = pollResp.videoUrl, !url.isEmpty {
                                tempUrls[sceneKey] = url
                            }
                        } else if pollResp.status == "failed" {
                            errorMessage = "场景 \(sceneKey) 视频生成失败"
                        } else {
                            stillPolling = true
                        }
                    }
                } catch {
                    stillPolling = true
                }
            }

            await MainActor.run {
                if !tempUrls.isEmpty {
                    sceneVideoUrls.merge(tempUrls) { current, _ in current }
                }
            }

            allDone = !stillPolling && sceneVideoUrls.count >= videoTaskIds.count
        }
    }

    // MARK: - Step 5: 拼接

    private var step5Concat: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频拼接")
                .font(.headline)

            if sceneVideoUrls.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("请先在第四步生成场景视频。")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if isConcatting {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在拼接视频...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let urlStr = concatVideoUrl, let url = URL(string: urlStr) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("拼接完成，预览：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    let avPlayer = AVPlayer(url: url)
                    AppKitVideoPlayerView(player: avPlayer)
                        .frame(height: 300)
                        .cornerRadius(8)
                        .onDisappear {
                            avPlayer.pause()
                        }

                    HStack {
                        Button("重新拼接") {
                            concatVideo()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("将 \(sceneVideoUrls.count) 个场景视频拼接为一个完整视频")
                        .font(.subheadline)
                    Button(action: concatVideo) {
                        Label("开始拼接", systemImage: "rectangle.stack.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    private func concatVideo() {
        guard let project = selectedProject else { return }
        isConcatting = true
        concatVideoUrl = nil
        player?.pause()
        player = nil
        Task {
            do {
                let resp = try await api.concatSoftAdVideo(projectId: project.id)
                await MainActor.run {
                    if let url = resp.videoUrl {
                        concatVideoUrl = url
                    }
                    isConcatting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isConcatting = false
                }
            }
        }
    }

    // MARK: - Step 6: 导出

    private var step6Export: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导出项目")
                .font(.headline)

            if concatVideoUrl == nil {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("请先在第五步完成视频拼接。")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if isExporting {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在导出...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let url = exportUrl {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)

                    Text("导出成功！")
                        .font(.title3).bold()

                    HStack {
                        Text("导出链接：")
                            .foregroundColor(.secondary)
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Button("复制链接") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    }
                    .buttonStyle(.bordered)

                    Button("重新导出") {
                        exportProject()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 12) {
                    Text("导出后可在作品库中查看和管理")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button(action: exportProject) {
                        Label("导出项目", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    private func exportProject() {
        guard let project = selectedProject else { return }
        isExporting = true
        exportUrl = nil
        Task {
            do {
                let resp = try await api.exportSoftAdProject(projectId: project.id)
                await MainActor.run {
                    if let url = resp.exportUrl {
                        exportUrl = url
                    }
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }

    // MARK: - Navigation Bar

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
        case 0:
            return selectedProject != nil
        case 1:
            return !generatedScript.isEmpty
        case 2:
            return !sceneImageUrls.isEmpty
        case 3:
            return !sceneVideoUrls.isEmpty
        case 4:
            return concatVideoUrl != nil
        default:
            return true
        }
    }
}

// MARK: - Preview

#Preview {
    SoftAdWorkflowView()
        .environmentObject(APIService.shared)
}
