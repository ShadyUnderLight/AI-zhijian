import SwiftUI
import AVKit

// MARK: - Status Enums

enum ShotStatus: String, CaseIterable {
    case pending, running, succeeded, failed

    var icon: String {
        switch self {
        case .pending:  return "circle"
        case .running:  return "arrow.triangle.2.circlepath"
        case .succeeded: return "checkmark.circle.fill"
        case .failed:   return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending:  return .gray
        case .running:  return .orange
        case .succeeded: return .green
        case .failed:   return .red
        }
    }

    var label: String {
        switch self {
        case .pending:  return "待处理"
        case .running:  return "生成中"
        case .succeeded: return "已完成"
        case .failed:   return "失败"
        }
    }
}

enum CharacterImageStatus: String {
    case pending, generating, succeeded, failed

    var icon: String {
        switch self {
        case .pending:    return "person.circle"
        case .generating: return "arrow.triangle.2.circlepath"
        case .succeeded:  return "checkmark.circle.fill"
        case .failed:     return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending:    return .gray
        case .generating: return .orange
        case .succeeded:  return .green
        case .failed:     return .red
        }
    }

    var label: String {
        switch self {
        case .pending:    return "待生成"
        case .generating: return "生成中"
        case .succeeded:  return "已生成"
        case .failed:     return "失败"
        }
    }
}

// MARK: - Local Models

struct StoryboardCard: Identifiable {
    let id = UUID()
    let index: Int
    var prompt: String
    var status: ShotStatus = .pending
}

struct CharacterModel: Identifiable {
    let id = UUID()
    let index: Int
    var name: String
    var imageUrl: String?
    var status: CharacterImageStatus = .pending
    var errorMessage: String?
}

struct ShotModel: Identifiable {
    let id = UUID()
    let index: Int
    var status: ShotStatus = .pending
    var videoUrl: String?
    var errorMessage: String?
}

// MARK: - AiComicStudioView

struct AiComicStudioView: View {
    @EnvironmentObject var api: APIService

    // MARK: - Script / Outline State

    @State private var outlineText = ""
    @State private var isGeneratingScript = false
    @State private var scriptId: String?
    @State private var storyboardCards: [StoryboardCard] = []

    // MARK: - Card Editing State

    @State private var showEditSheet = false
    @State private var editingCardIndex = 0
    @State private var editingPrompt = ""

    // MARK: - Character State

    @State private var characters: [CharacterModel] = []
    @State private var generatingCharIndex: Int?

    // MARK: - Shot State

    @State private var taskId: String?
    @State private var shots: [ShotModel] = []
    @State private var isSubmittingShots = false
    @State private var isCancelling = false
    @State private var retryingShotIndex: Int?
    @State private var rescuingShotIndex: Int?
    @State private var pollTask: Task<Void, Never>?

    // MARK: - Preview State

    @State private var showPreview = false
    @State private var previewUrl: String?
    @State private var player: AVPlayer?

    // MARK: - Shared State

    @State private var errorMessage: String?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // MARK: - Computed Properties

    private var completedShotCount: Int {
        shots.filter { $0.status == .succeeded }.count
    }

    private var totalShotCount: Int {
        shots.count
    }

    private var progress: Double {
        guard totalShotCount > 0 else { return 0 }
        return Double(completedShotCount) / Double(totalShotCount)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                leftPanel
                centerPanel
                rightPanel
            }

            bottomBar
        }
        .frame(minWidth: 1000, minHeight: 600)
        .alert(alertTitle, isPresented: $showAlert, actions: {
            Button("确定", role: .cancel) {}
        }, message: {
            Text(alertMessage)
        })
        .sheet(isPresented: $showEditSheet) {
            editCardSheet
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    // MARK: - Left Panel: Outline Input

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("剧本大纲")
                .font(.headline)

            TextEditor(text: $outlineText)
                .font(.body)
                .frame(height: 150)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )

            HStack {
                Button(action: generateScript) {
                    if isGeneratingScript {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("生成中...")
                    } else {
                        Label("生成分镜", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    outlineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isGeneratingScript
                )

                Spacer()

                Text("\(storyboardCards.count) 个场景")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !storyboardCards.isEmpty {
                Text("分镜列表")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(storyboardCards) { card in
                            storyboardCardRow(card)
                        }
                    }
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("输入剧本大纲并点击「生成分镜」")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(16)
        .frame(minWidth: 280, idealWidth: 320)
    }

    private func storyboardCardRow(_ card: StoryboardCard) -> some View {
        HStack(spacing: 10) {
            Text("\(card.index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(card.prompt)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: card.status.icon)
                .foregroundColor(card.status.color)
                .font(.caption)

            Button("编辑") {
                editingCardIndex = card.index
                editingPrompt = card.prompt
                showEditSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.caption)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.15))
        )
    }

    // MARK: - Center Panel: Character Management

    private var centerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("角色管理")
                .font(.headline)

            HStack {
                Button(action: addCharacter) {
                    Label("添加角色", systemImage: "person.badge.plus")
                }
                .buttonStyle(.bordered)
                .disabled(scriptId == nil)

                Spacer()

                Text("\(characters.count) 个角色")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if characters.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(scriptId == nil ? "请先生成剧本分镜" : "点击「添加角色」创建角色")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(characters.indices, id: \.self) { i in
                            characterRow(characters[i])
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 240, idealWidth: 280)
    }

    private func characterRow(_ character: CharacterModel) -> some View {
        HStack(spacing: 10) {
            // Image preview
            if let urlString = character.imageUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    case .failure:
                        characterPlaceholder
                    case .empty:
                        characterPlaceholder
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.5)
                            )
                    @unknown default:
                        characterPlaceholder
                    }
                }
                .frame(width: 48, height: 48)
            } else {
                characterPlaceholder
            }

            // Name + status
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: character.status.icon)
                        .foregroundColor(character.status.color)
                        .font(.caption2)
                    Text(character.status.label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            if character.status == .pending || character.status == .failed {
                Button(action: {
                    generateCharacterImage(at: character.index)
                }) {
                    if generatingCharIndex == character.index {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Text("生成定妆图")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.caption)
                .disabled(generatingCharIndex == character.index)
            }

            if character.status == .failed {
                Button(action: {
                    retryCharacterImage(at: character.index)
                }) {
                    Label("重试", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .font(.caption)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.15))
        )
    }

    private var characterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "person")
                    .foregroundColor(.secondary)
            )
    }

    // MARK: - Right Panel: Shot Board

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("镜头看板")
                .font(.headline)

            // Action buttons row
            HStack(spacing: 8) {
                Button(action: batchSubmit) {
                    if isSubmittingShots {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("提交中...")
                    } else {
                        Label("批提交", systemImage: "tray.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    shots.isEmpty
                    || shots.allSatisfy { $0.status != .pending }
                    || isSubmittingShots
                )

                Button(action: cancelAll) {
                    if isCancelling {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("取消中...")
                    } else {
                        Label("取消全部", systemImage: "xmark.circle")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(shots.isEmpty || isCancelling)

                Spacer()
            }

            // Progress bar
            if !shots.isEmpty {
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .frame(maxWidth: .infinity)
                    HStack {
                        Text("整体进度")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(completedShotCount)/\(totalShotCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            // Shot grid
            if shots.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.split.2x2")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无镜头，请先生成剧本并提交")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 180))],
                        spacing: 10
                    ) {
                        ForEach(shots.indices, id: \.self) { i in
                            shotCell(shots[i])
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 280, idealWidth: 320)
    }

    @ViewBuilder
    private func shotCell(_ shot: ShotModel) -> some View {
        VStack(spacing: 6) {
            Text("镜头 \(shot.index + 1)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Image(systemName: shot.status.icon)
                    .foregroundColor(shot.status.color)
                    .font(.caption)
                Text(shot.status.label)
                    .font(.caption2)
                    .foregroundColor(shot.status.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(shot.status.color.opacity(0.1))
            .cornerRadius(4)

            if shot.status == .failed {
                HStack(spacing: 4) {
                    Button("重试") {
                        retryShot(at: shot.index)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption2)
                    .disabled(retryingShotIndex == shot.index)

                    Button("抢救") {
                        rescueShot(at: shot.index)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption2)
                    .tint(.orange)
                    .disabled(rescuingShotIndex == shot.index)
                }
            }

            if shot.status == .running {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    shot.status == .failed
                        ? Color.red.opacity(0.3)
                        : Color.secondary.opacity(0.15)
                )
        )
    }

    // MARK: - Bottom Bar: Preview

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Button(action: togglePreview) {
                    Label(
                        showPreview ? "关闭预览" : "预览",
                        systemImage: showPreview ? "chevron.down" : "play.rectangle"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(shots.filter { $0.status == .succeeded }.isEmpty)

                if let url = previewUrl, !url.isEmpty {
                    Text("视频已就绪")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.leading, 8)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if showPreview {
                if let urlString = previewUrl, let url = URL(string: urlString) {
                    AppKitVideoPlayerView(player: player)
                        .frame(height: 250)
                        .onAppear {
                            player = AVPlayer(url: url)
                            player?.play()
                        }
                        .onDisappear {
                            player?.pause()
                            player = nil
                        }
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("等待视频生成...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Edit Card Sheet

    private var editCardSheet: some View {
        VStack(spacing: 16) {
            Text("编辑分镜 \(editingCardIndex + 1)")
                .font(.headline)

            TextEditor(text: $editingPrompt)
                .font(.body)
                .frame(height: 200)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )

            HStack {
                Button("取消") {
                    showEditSheet = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("保存") {
                    saveEditedCard()
                    showEditSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420, height: 320)
    }

    private func saveEditedCard() {
        if let idx = storyboardCards.firstIndex(where: { $0.index == editingCardIndex }) {
            storyboardCards[idx].prompt = editingPrompt
        }
    }

    // MARK: - Async Actions: Script Generation

    private func generateScript() {
        isGeneratingScript = true
        errorMessage = nil

        Task {
            do {
                let trimmed = outlineText.trimmingCharacters(in: .whitespacesAndNewlines)
                let result = try await api.generateComicScript(
                    topic: trimmed,
                    language: "zh",
                    style: nil,
                    characterCount: nil,
                    panelCount: nil
                )

                if result.success, let sid = result.scriptId {
                    scriptId = sid
                    let count = result.sceneCount ?? 4
                    let scriptContent = result.script ?? trimmed

                    let lines = scriptContent
                        .components(separatedBy: "\n")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    if !lines.isEmpty {
                        storyboardCards = lines.enumerated().map { (i, line) in
                            StoryboardCard(index: i, prompt: line)
                        }
                    } else {
                        storyboardCards = (0 ..< count).map { i in
                            StoryboardCard(
                                index: i,
                                prompt: "场景 \(i + 1)：\(trimmed.prefix(50))"
                            )
                        }
                    }

                    shots = storyboardCards.map { card in
                        ShotModel(index: card.index)
                    }
                } else {
                    errorMessage = result.message ?? "生成分镜失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGeneratingScript = false
        }
    }

    // MARK: - Async Actions: Characters

    private func addCharacter() {
        let newIndex = characters.count
        let names = ["主角", "配角A", "配角B", "反派", "路人甲", "路人乙"]
        let name = newIndex < names.count ? names[newIndex] : "角色 \(newIndex + 1)"
        characters.append(CharacterModel(index: newIndex, name: name))
    }

    private func generateCharacterImage(at index: Int) {
        guard let sid = scriptId else { return }
        generatingCharIndex = index

        Task {
            do {
                guard let characterIdx = characters.firstIndex(where: { $0.index == index }) else {
                    generatingCharIndex = nil
                    return
                }
                characters[characterIdx].status = .generating

                let result = try await api.retryComicCharacterImage(
                    scriptId: sid,
                    characterIndex: index
                )

                if result.success {
                    characters[characterIdx].status = .succeeded
                    characters[characterIdx].imageUrl = result.imageUrl
                } else {
                    characters[characterIdx].status = .failed
                    characters[characterIdx].errorMessage = result.message
                }
            } catch {
                if let characterIdx = characters.firstIndex(where: { $0.index == index }) {
                    characters[characterIdx].status = .failed
                    characters[characterIdx].errorMessage = error.localizedDescription
                }
            }
            generatingCharIndex = nil
        }
    }

    private func retryCharacterImage(at index: Int) {
        guard let sid = scriptId else { return }

        Task {
            do {
                guard let characterIdx = characters.firstIndex(where: { $0.index == index }) else { return }
                characters[characterIdx].status = .generating

                let result = try await api.retryComicCharacterImage(
                    scriptId: sid,
                    characterIndex: index
                )

                if result.success {
                    characters[characterIdx].status = .succeeded
                    characters[characterIdx].imageUrl = result.imageUrl
                } else {
                    characters[characterIdx].status = .failed
                    characters[characterIdx].errorMessage = result.message
                }
            } catch {
                if let characterIdx = characters.firstIndex(where: { $0.index == index }) {
                    characters[characterIdx].status = .failed
                    characters[characterIdx].errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Async Actions: Shot Submission

    private func batchSubmit() {
        guard let sid = scriptId else { return }
        isSubmittingShots = true
        errorMessage = nil

        for i in shots.indices where shots[i].status == .pending {
            shots[i].status = .running
        }

        Task {
            do {
                let charIds = characters.isEmpty ? nil : Dictionary(
                    uniqueKeysWithValues: characters.map { ($0.name, $0.index) }
                )
                let result = try await api.submitComicVideos(
                    scriptId: sid,
                    characterIds: charIds
                )

                if result.success {
                    taskId = result.taskId

                    if let responseShots = result.shots {
                        for responseShot in responseShots {
                            if let idx = shots.firstIndex(where: { $0.index == responseShot.shotIndex }) {
                                switch responseShot.status {
                                case "completed", "succeeded":
                                    shots[idx].status = .succeeded
                                case "failed":
                                    shots[idx].status = .failed
                                    shots[idx].errorMessage = responseShot.errorMessage
                                case "running", "processing":
                                    shots[idx].status = .running
                                default:
                                    shots[idx].status = .running
                                }
                                if let videoUrl = responseShot.videoUrl {
                                    shots[idx].videoUrl = videoUrl
                                }
                            }
                        }
                    }

                    if let tid = result.taskId {
                        startPolling(taskId: tid)
                    }

                    if let existingShots = result.shots,
                       let firstVideo = existingShots.compactMap({ $0.videoUrl }).first {
                        previewUrl = firstVideo
                    }
                } else {
                    errorMessage = result.message ?? "批量提交失败"
                    for i in shots.indices where shots[i].status == .running {
                        shots[i].status = .pending
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                for i in shots.indices where shots[i].status == .running {
                    shots[i].status = .pending
                }
            }
            isSubmittingShots = false
        }
    }

    // MARK: - Async Actions: Shot Retry / Rescue

    private func retryShot(at index: Int) {
        guard let tid = taskId else { return }
        retryingShotIndex = index

        Task {
            do {
                if let shotIdx = shots.firstIndex(where: { $0.index == index }) {
                    shots[shotIdx].status = .running
                }

                let result = try await api.retryComicVideoShot(
                    taskId: tid,
                    shotIndex: index
                )

                if result.success {
                    if let shotIdx = shots.firstIndex(where: { $0.index == index }) {
                        shots[shotIdx].status = .pending
                    }
                } else {
                    if let shotIdx = shots.firstIndex(where: { $0.index == index }) {
                        shots[shotIdx].status = .failed
                        shots[shotIdx].errorMessage = result.message
                    }
                }
            } catch {
                if let shotIdx = shots.firstIndex(where: { $0.index == index }) {
                    shots[shotIdx].status = .failed
                    shots[shotIdx].errorMessage = error.localizedDescription
                }
            }
            retryingShotIndex = nil
        }
    }

    private func rescueShot(at index: Int) {
        guard let tid = taskId else { return }
        rescuingShotIndex = index

        Task {
            do {
                if let shotIdx = shots.firstIndex(where: { $0.index == index }) {
                    shots[shotIdx].status = .running
                }

                let result = try await api.rescueComicShotSeedance(
                    taskId: tid,
                    shotIndex: index
                )

                if result.success {
                    if let shotIdx = shots.firstIndex(where: { $0.index == index }) {
                        shots[shotIdx].status = .pending
                    }
                } else {
                    if let shotIdx = shots.firstIndex(where: { $0.index == index }) {
                        shots[shotIdx].status = .failed
                        shots[shotIdx].errorMessage = result.message
                    }
                }
            } catch {
                if let shotIdx = shots.firstIndex(where: { $0.index == index }) {
                    shots[shotIdx].status = .failed
                    shots[shotIdx].errorMessage = error.localizedDescription
                }
            }
            rescuingShotIndex = nil
        }
    }

    // MARK: - Async Actions: Cancel / Polling

    private func cancelAll() {
        guard let tid = taskId else { return }
        isCancelling = true

        Task {
            do {
                _ = try await api.cancelComicRunningHubTasks(taskIds: [tid])

                for i in shots.indices {
                    if shots[i].status == .running {
                        shots[i].status = .pending
                    }
                }

                alertTitle = "已取消"
                alertMessage = "所有进行中的任务已取消"
                showAlert = true
            } catch {
                alertTitle = "取消失败"
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isCancelling = false
        }
    }

    private func startPolling(taskId: String) {
        pollTask?.cancel()

        pollTask = Task {
            while !Task.isCancelled {
                do {
                    let status = try await api.queryComicTaskStatus(taskId: taskId)

                    if let responseShots = status.shots {
                        for responseShot in responseShots {
                            if let idx = shots.firstIndex(where: { $0.index == responseShot.shotIndex }) {
                                switch responseShot.status {
                                case "completed", "succeeded":
                                    shots[idx].status = .succeeded
                                case "failed":
                                    shots[idx].status = .failed
                                    shots[idx].errorMessage = responseShot.errorMessage
                                case "running", "processing":
                                    shots[idx].status = .running
                                default:
                                    break
                                }
                                if let videoUrl = responseShot.videoUrl {
                                    shots[idx].videoUrl = videoUrl
                                }
                            }
                        }
                    }

                    if let videoUrl = status.videoUrl {
                        previewUrl = videoUrl
                    }

                    let allDone = shots.allSatisfy { $0.status == .succeeded || $0.status == .failed }
                    if allDone {
                        if let consolidatedUrl = status.videoUrl {
                            previewUrl = consolidatedUrl
                        }
                        break
                    }
                } catch {
                    // Continue polling silently
                }

                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func togglePreview() {
        showPreview.toggle()
        if !showPreview {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - AppKit Video Player Wrapper
// Shared AppKitVideoPlayerView lives in Views/AppKitVideoPlayerView.swift
