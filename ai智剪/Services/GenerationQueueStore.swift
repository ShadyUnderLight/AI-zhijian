import Foundation
import AppKit
import OSLog

enum GenerationJobKind: String, CaseIterable, Codable {
    case gptImage
    case banana
    case seedance
    case wan
    case veo
    case grok

    var displayName: String {
        switch self {
        case .gptImage: return "GPT-Image-2"
        case .banana: return "Banana"
        case .seedance: return "Seedance"
        case .wan: return "Wan"
        case .veo: return "Veo"
        case .grok: return "Grok"
        }
    }

    var icon: String {
        switch self {
        case .gptImage, .banana: return "photo"
        case .seedance, .wan, .veo, .grok: return "video"
        }
    }
}

enum GenerationQueueStatus: String, CaseIterable, Codable {
    case pending
    case submitting
    case polling
    case succeeded
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .pending: return "排队中"
        case .submitting: return "提交中"
        case .polling: return "轮询中"
        case .succeeded: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}

enum JobParams {
    case gptImage(GptImageJobParams)
    case banana(BananaJobParams)
    case seedance(SeedanceJobParams)
    case wan(WanJobParams)
    case veo(VeoJobParams)
    case grok(GrokJobParams)
}

struct GptImageJobParams {
    let prompt: String
    let channel: String
    let aspectRatio: String
    let resolution: String
    let quality: String
    let photoReal: Bool
    var referenceImages: [FileRef] = []
    var isImageToImage: Bool { !referenceImages.isEmpty }
}

struct BananaJobParams {
    let prompt: String
    let provider: String
    var referenceImages: [FileRef] = []
}

struct SeedanceJobParams {
    let prompt: String
    let mode: String
    let model: String
    let ratio: String
    let resolution: String
    let duration: Int
    let count: Int
    let generateAudio: Bool
    var assets: [SeedanceAsset] = []
}

struct WanJobParams {
    let mode: String
    let prompt: String
    let width: Int
    let height: Int
    let seconds: Int
    var enable48G: Bool = false
    var imageData: Data?
    var imageName: String?
    var imageMime: String?
    var firstFrame: FileRef?
    var lastFrame: FileRef?
}

struct VeoJobParams {
    var channel: String = "budget"
    var model: String = "fast"
    var mode: String = "text"
    var prompt: String = ""
    var aspectRatio: String = "9:16"
    var resolution: String = "720p"
    var duration: String = "8"
    var generateAudio: Bool = false
    var negativePrompt: String?
    var imageData: Data?
    var imageName: String?
    var imageMime: String?
    var imageFiles: [FileRef] = []
    var firstImageData: Data?
    var firstImageName: String?
    var firstImageMime: String?
    var lastImageData: Data?
    var lastImageName: String?
    var lastImageMime: String?
    var ref1Data: (data: Data, name: String, mime: String)?
    var ref2Data: (data: Data, name: String, mime: String)?
    var ref3Data: (data: Data, name: String, mime: String)?
    var videoData: Data?
    var videoName: String?
    var videoMime: String?
}

struct GrokJobParams {
    let prompt: String
    let channel: String
    let mode: String
    let aspectRatio: String
    let resolution: String
    let duration: String
    var imageFiles: [(Data, String, String)] = []
    var videoData: Data?
    var videoName: String?
    var videoMime: String?
}

struct GenerationQueueItem: Identifiable, Hashable {
    var id: String = UUID().uuidString
    let kind: GenerationJobKind
    var status: GenerationQueueStatus = .pending
    var taskId: String?
    var resultUrls: [String] = []
    var videoUrl: String?
    var errorMessage: String?
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var retryCount: Int = 0

    var params: JobParams

    var bananaResultImageData: Data?

    var consecutivePollFailures: Int = 0
    var lastPollError: String?

    var priceUsd: String?

    var restoredFromPersistence = false

    var displayType: String { kind.displayName }
    var iconName: String { kind.icon }

    var summary: String {
        switch params {
        case .gptImage(let p): return p.prompt
        case .banana(let p): return p.prompt
        case .seedance(let p): return p.prompt
        case .wan(let p): return p.prompt
        case .veo(let p): return p.prompt
        case .grok(let p): return p.prompt
        }
    }

    var elapsed: String {
        let start = startedAt ?? createdAt
        let s = Int(Date().timeIntervalSince(start))
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m\(s % 60)s"
    }

    var isActive: Bool {
        status == .submitting || status == .polling
    }

    var hasFileData: Bool {
        switch params {
        case .gptImage(let p): return !p.referenceImages.isEmpty
        case .banana(let p): return !p.referenceImages.isEmpty
        case .seedance(let p): return !p.assets.isEmpty
        case .wan(let p): return p.imageData != nil || p.firstFrame != nil || p.lastFrame != nil
        case .veo(let p): return !p.imageFiles.isEmpty || p.imageData != nil || p.firstImageData != nil || p.lastImageData != nil || p.ref1Data != nil || p.videoData != nil
        case .grok(let p): return !p.imageFiles.isEmpty || p.videoData != nil
        }
    }

    var retryValidationError: String? {
        switch params {
        case .gptImage(let p):
            guard Self.hasPrompt(p.prompt) else { return "无法重试：任务缺少提示词，请从页面重新提交" }
            guard p.referenceImages.allSatisfy(Self.isValidFile) else { return "无法重试：任务包含无效参考图，请从页面重新提交" }
        case .banana(let p):
            guard Self.hasPrompt(p.prompt) else { return "无法重试：任务缺少提示词，请从页面重新提交" }
            guard p.referenceImages.allSatisfy(Self.isValidFile) else { return "无法重试：任务包含无效参考图，请从页面重新提交" }
        case .seedance(let p):
            guard Self.hasPrompt(p.prompt) || p.assets.contains(where: Self.isValidAsset) else {
                return "无法重试：任务缺少提示词或参考素材，请从页面重新提交"
            }
            if p.mode == "first_last" && !p.assets.contains(where: Self.isValidAsset) {
                return "无法重试：任务缺少首帧图片，请从页面重新提交"
            }
        case .wan(let p):
            guard p.width > 0, p.height > 0, p.seconds > 0 else {
                return "无法重试：任务尺寸或时长无效，请从页面重新提交"
            }
            if p.mode == "image" {
                guard Self.isValidUpload(data: p.imageData, name: p.imageName, mime: p.imageMime) else {
                    return "无法重试：任务缺少输入图片，请从页面重新提交"
                }
            } else {
                guard Self.isValidFile(p.firstFrame), Self.isValidFile(p.lastFrame) else {
                    return "无法重试：任务缺少首帧或尾帧图片，请从页面重新提交"
                }
            }
        case .veo(let p):
            if !VeoRules.isValidCombination(channel: p.channel, model: p.model) {
                return "无法重试：任务渠道/模型组合无效 (\(p.channel)/\(p.model))，请从页面重新提交"
            }
            let validModes = VeoRules.validModeValues(channel: p.channel, model: p.model)
            if !validModes.contains(p.mode) {
                let allowed = validModes.joined(separator: ", ")
                return "无法重试：任务模式无效 (\(p.mode))，可用: \(allowed)，请从页面重新提交"
            }
            if p.mode != "extend" && !Self.hasPrompt(p.prompt) {
                return "无法重试：任务缺少提示词，请从页面重新提交"
            }
            if !p.imageFiles.allSatisfy(Self.isValidFile) {
                return "无法重试：任务包含无效参考图，请从页面重新提交"
            }
            if p.mode == "image" && p.imageFiles.isEmpty && !Self.isValidUpload(data: p.imageData, name: p.imageName, mime: p.imageMime) {
                return "无法重试：任务缺少参考图，请从页面重新提交"
            }
            if p.mode == "start_end" && !Self.isValidUpload(data: p.firstImageData, name: p.firstImageName, mime: p.firstImageMime) {
                return "无法重试：任务缺少首帧图片，请从页面重新提交"
            }
            if p.mode == "start_end" && p.channel == "official" && p.model == "lite" &&
                !Self.isValidUpload(data: p.lastImageData, name: p.lastImageName, mime: p.lastImageMime) {
                return "无法重试：任务缺少尾帧图片，请从页面重新提交"
            }
            if p.mode == "reference" && !Self.isValidVeoReference(p) {
                return "无法重试：任务缺少参考图，请从页面重新提交"
            }
            if p.mode == "extend" && !Self.isValidUpload(data: p.videoData, name: p.videoName, mime: p.videoMime) {
                return "无法重试：任务缺少视频素材，请从页面重新提交"
            }
        case .grok(let p):
            guard Self.hasPrompt(p.prompt) else { return "无法重试：任务缺少提示词，请从页面重新提交" }
            if (p.mode == "image" || p.mode == "reference") && p.imageFiles.isEmpty {
                return "无法重试：任务缺少参考图，请从页面重新提交"
            }
            if !p.imageFiles.allSatisfy(Self.isValidGrokUpload) {
                return "无法重试：任务包含无效参考图，请从页面重新提交"
            }
            if (p.mode == "extend" || p.mode == "edit") && !Self.isValidUpload(data: p.videoData, name: p.videoName, mime: p.videoMime) {
                return "无法重试：任务缺少视频素材，请从页面重新提交"
            }
        }
        return nil
    }

    mutating func markSubmitting() {
        status = .submitting
        startedAt = Date()
        consecutivePollFailures = 0
        lastPollError = nil
    }

    mutating func markPolling(taskId: String) {
        self.taskId = taskId
        status = .polling
        consecutivePollFailures = 0
        lastPollError = nil
    }

    mutating func markSucceeded(resultUrls: [String] = [], videoUrl: String? = nil) {
        status = .succeeded
        self.resultUrls = resultUrls
        self.videoUrl = videoUrl
        completedAt = Date()
        consecutivePollFailures = 0
        lastPollError = nil
    }

    mutating func markFailed(_ error: String) {
        status = .failed
        errorMessage = error
        completedAt = Date()
        consecutivePollFailures = 0
        lastPollError = nil
    }

    mutating func markCancelled() {
        status = .cancelled
        completedAt = Date()
        consecutivePollFailures = 0
        lastPollError = nil
    }

    mutating func recordPollFailure(_ error: String) {
        consecutivePollFailures += 1
        lastPollError = error
    }

    mutating func clearPollFailure() {
        consecutivePollFailures = 0
        lastPollError = nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GenerationQueueItem, rhs: GenerationQueueItem) -> Bool {
        lhs.id == rhs.id
    }

    static func restoring(id: String, kind: GenerationJobKind, createdAt: Date, params: JobParams) -> GenerationQueueItem {
        var item = GenerationQueueItem(kind: kind, createdAt: createdAt, params: params)
        item.id = id
        return item
    }

    private static func hasPrompt(_ prompt: String) -> Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func isValidFile(_ file: FileRef) -> Bool {
        !file.data.isEmpty && !file.name.isEmpty && !file.mime.isEmpty
    }

    private static func isValidFile(_ file: FileRef?) -> Bool {
        guard let file else { return false }
        return isValidFile(file)
    }

    private static func isValidAsset(_ asset: SeedanceAsset) -> Bool {
        asset.size > 0 && !asset.name.isEmpty && !asset.mime.isEmpty
    }

    private static func isValidUpload(data: Data?, name: String?, mime: String?) -> Bool {
        guard let data, let name, let mime else { return false }
        return !data.isEmpty && !name.isEmpty && !mime.isEmpty
    }

    private static func isValidGrokUpload(_ file: (Data, String, String)) -> Bool {
        !file.0.isEmpty && !file.1.isEmpty && !file.2.isEmpty
    }

    private static func isValidVeoReference(_ params: VeoJobParams) -> Bool {
        [params.ref1Data, params.ref2Data, params.ref3Data].contains { file in
            guard let file else { return false }
            return !file.data.isEmpty && !file.name.isEmpty && !file.mime.isEmpty
        }
    }
}

// MARK: - Persistence Snapshot

private struct QueueItemSnapshot: Codable {
    let id: String
    let kind: GenerationJobKind
    var status: GenerationQueueStatus
    var taskId: String?
    var resultUrls: [String]
    var videoUrl: String?
    var errorMessage: String?
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var retryCount: Int
    var summaryText: String
    var consecutivePollFailures: Int
    var hasFileData: Bool
    var priceUsd: String?
}

// MARK: - Queue Store

@MainActor
final class GenerationQueueStore: ObservableObject {
    @Published var items: [GenerationQueueItem] = []
    @Published var isPaused = false
    @Published var isProcessing = false

    @Published var concurrencyLimit = 5 {
        didSet {
            let clamped = min(max(concurrencyLimit, 1), 5)
            if concurrencyLimit != clamped {
                concurrencyLimit = clamped
            }
            if oldValue != concurrencyLimit {
                sleepTask?.cancel()
            }
        }
    }
    let maxConsecutivePollFailures = 5

    private let api: APIService
    private let executor: GenerationTaskExecutor
    private let logger = Logger(subsystem: "AIZhijian", category: "GenerationQueueStore")
    private var worksStore: WorksStore?
    private var processTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
    private var loginObserverTask: Task<Void, Never>?
    private var activeLoopToken: UUID?

    private static let persistenceKey = "GenerationQueueStore.items"

    init(api: APIService) {
        self.api = api
        self.executor = GenerationTaskExecutor(api: api)
        loadFromPersistence()
        observeLoginState()
    }

    func attachWorksStore(_ ws: WorksStore) {
        worksStore = ws
        for item in items where item.status == .succeeded || item.status == .failed {
            ws.addRecord(from: item)
        }
    }

    var pendingCount: Int { items.count { $0.status == .pending } }
    var submittingCount: Int { items.count { $0.status == .submitting } }
    var pollingCount: Int { items.count { $0.status == .polling } }
    var succeededCount: Int { items.count { $0.status == .succeeded } }
    var failedCount: Int { items.count { $0.status == .failed } }

    var activeTaskCount: Int { submittingCount + pollingCount }

    var totalCostSummary: String? {
        let prices = items.compactMap { $0.priceUsd }.filter { !$0.isEmpty }
        guard !prices.isEmpty else { return nil }
        return prices.joined(separator: " + ")
    }

    var statsSummary: String {
        "待提交 \(pendingCount) | 提交中 \(submittingCount) | 轮询中 \(pollingCount) | 完成 \(succeededCount) | 失败 \(failedCount)"
    }

    func enqueue(_ item: GenerationQueueItem) {
        items.append(item)
        syncActiveTasks()
        startProcessingIfNeeded()
        persistQueue()
    }

    func enqueueBatch(_ batch: [GenerationQueueItem]) {
        items.append(contentsOf: batch)
        syncActiveTasks()
        startProcessingIfNeeded()
        persistQueue()
    }

    func cancelPendingItem(_ id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].status == .pending else { return }
        items[idx].markCancelled()
        syncActiveTasks()
        persistQueue()
    }

    func retryFailedItem(_ id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].status == .failed else { return }
        if items[idx].restoredFromPersistence {
            items[idx].errorMessage = "无法重试：任务参数已丢失，请从页面重新提交"
            persistQueue()
            return
        }
        if let validationError = items[idx].retryValidationError {
            items[idx].errorMessage = validationError
            persistQueue()
            return
        }
        items[idx].status = .pending
        items[idx].errorMessage = nil
        items[idx].retryCount += 1
        items[idx].taskId = nil
        items[idx].resultUrls = []
        items[idx].videoUrl = nil
        items[idx].priceUsd = nil
        items[idx].startedAt = nil
        items[idx].completedAt = nil
        items[idx].consecutivePollFailures = 0
        items[idx].lastPollError = nil
        syncActiveTasks()
        startProcessingIfNeeded()
        persistQueue()
    }

    func clearCompleted() {
        items.removeAll { $0.status == .succeeded || $0.status == .cancelled }
        syncActiveTasks()
        persistQueue()
    }

    func clearFailed() {
        items.removeAll { $0.status == .failed }
        syncActiveTasks()
        persistQueue()
    }

    func clearAllCompleted() {
        items.removeAll { $0.status == .succeeded || $0.status == .failed || $0.status == .cancelled }
        syncActiveTasks()
        persistQueue()
    }

    func cancelAndClearAll() {
        processTask?.cancel()
        processTask = nil
        sleepTask?.cancel()
        sleepTask = nil
        for idx in items.indices {
            if items[idx].status == .pending || items[idx].status == .submitting || items[idx].status == .polling {
                items[idx].markCancelled()
            }
        }
        syncActiveTasks()
        for item in items where item.status == .cancelled {
            api.removeTask(id: item.id)
        }
        items.removeAll()
        persistQueue()
    }

    func pauseQueue() {
        isPaused = true
    }

    func resumeQueue() {
        isPaused = false
        startProcessingIfNeeded()
    }

    // MARK: - Private: Processing

    private func startProcessingIfNeeded() {
        guard processTask == nil else { return }
        let token = UUID()
        activeLoopToken = token
        processTask = Task { await processLoop(token: token) }
    }

    private func processLoop(token: UUID) async {
        isProcessing = true
        defer {
            isProcessing = false
            if activeLoopToken == token {
                processTask = nil
            }
        }

        while !Task.isCancelled {
            if !isPaused {
                await submitPendingItemsUpToLimit()
                await pollActiveItems()
            }
            let allDone = items.allSatisfy {
                $0.status == .succeeded || $0.status == .failed || $0.status == .cancelled
            }
            if allDone && pendingCount == 0 {
                break
            }
            sleepTask = Task { try? await Task.sleep(nanoseconds: 3_000_000_000) }
            await sleepTask?.value
            sleepTask = nil
        }
    }

    private func submitPendingItemsUpToLimit() async {
        let activeCount = items.count { $0.isActive }
        let capacity = max(0, concurrencyLimit - activeCount)
        guard capacity > 0 else { return }

        var submissions: [GenerationQueueItem] = []
        for idx in items.indices where items[idx].status == .pending {
            if items[idx].restoredFromPersistence {
                if items[idx].hasFileData {
                    items[idx].markFailed("持久化恢复失败：文件数据已丢失，请从页面重新提交")
                } else {
                    items[idx].markFailed("持久化恢复失败：任务参数已丢失，请从页面重新提交")
                }
                continue
            }

            items[idx].markSubmitting()
            submissions.append(items[idx])

            if submissions.count >= capacity {
                break
            }
        }

        syncActiveTasks()
        persistQueue()

        guard !submissions.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for submission in submissions {
                group.addTask { [weak self, item = submission] in
                    await self?.submitPreparedItem(item)
                }
            }
        }
    }

    private func submitPreparedItem(_ item: GenerationQueueItem) async {
        do {
            try await submitItem(item)
        } catch {
            if !Task.isCancelled {
                if let currentIdx = items.firstIndex(where: { $0.id == item.id }) {
                    items[currentIdx].markFailed(error.localizedDescription)
                }
                syncActiveTasks()
                persistQueue()
            }
        }
    }

    private func submitItem(_ item: GenerationQueueItem) async throws {
        let submission = try await executor.submit(item.params)

        if let data = submission.bananaImageData {
            guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[idx].markSucceeded()
            items[idx].bananaResultImageData = data
            syncActiveTasks()
            persistQueue()
            return
        }

        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].priceUsd = submission.priceUsd
        items[idx].markPolling(taskId: submission.taskId)
        syncActiveTasks()
        persistQueue()

        if !submission.extraTaskIds.isEmpty, case .seedance(let p) = item.params {
            for extraId in submission.extraTaskIds {
                var child = GenerationQueueItem(
                    kind: .seedance,
                    createdAt: Date(),
                    params: .seedance(p)
                )
                child.markPolling(taskId: extraId)
                child.priceUsd = submission.priceUsd
                items.append(child)
            }
        }
    }

    private func pollActiveItems() async {
        let pollingItems = items.filter { $0.status == .polling && $0.taskId != nil }
        for pollingItem in pollingItems {
            guard items.contains(where: { $0.id == pollingItem.id && $0.status == .polling }) else { continue }
            guard let taskId = pollingItem.taskId else { continue }
            if Task.isCancelled { return }
            do {
                let tick = try await executor.poll(taskId: taskId, kind: pollingItem.kind)
                guard let idx = items.firstIndex(where: { $0.id == pollingItem.id }) else { continue }
                switch tick {
                case .completed(let output):
                    switch output {
                    case .images(let urls):
                        items[idx].markSucceeded(resultUrls: urls)
                    case .video(let url):
                        items[idx].markSucceeded(videoUrl: url)
                    case .bananaImage:
                        break
                    }
                case .failed(let msg):
                    items[idx].markFailed(msg)
                case .stillProcessing:
                    items[idx].clearPollFailure()
                }
                syncActiveTasks()
                persistQueue()
            } catch {
                if Task.isCancelled { return }
                guard let idx = items.firstIndex(where: { $0.id == pollingItem.id }) else { continue }
                items[idx].recordPollFailure(error.localizedDescription)
                if items[idx].consecutivePollFailures >= maxConsecutivePollFailures {
                    items[idx].markFailed("轮询连续失败 \(maxConsecutivePollFailures) 次: \(items[idx].lastPollError ?? error.localizedDescription)")
                }
                syncActiveTasks()
                persistQueue()
            }
        }
    }

    // MARK: - Active task sync

    private func syncActiveTasks() {
        for item in items where item.status == .submitting || item.status == .polling {
            api.addTask(id: item.id, type: item.displayType, desc: String(item.summary.prefix(30)))
        }
        for item in items where item.status == .succeeded || item.status == .failed || item.status == .cancelled {
            api.removeTask(id: item.id)
        }
    }

    // MARK: - Login state observation

    private func observeLoginState() {
        loginObserverTask = Task { [weak self] in
            guard let self else { return }
            var wasLoggedIn = api.isLoggedIn
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let current = api.isLoggedIn
                if current != wasLoggedIn {
                    wasLoggedIn = current
                    if !current {
                        await MainActor.run { self.cancelAndClearAll() }
                    }
                }
            }
        }
    }

    // MARK: - Persistence (UserDefaults)

    private func persistQueue() {
        let snapshots = items.map { item in
            QueueItemSnapshot(
                id: item.id,
                kind: item.kind,
                status: item.status,
                taskId: item.taskId,
                resultUrls: item.resultUrls,
                videoUrl: item.videoUrl,
                errorMessage: item.errorMessage,
                createdAt: item.createdAt,
                startedAt: item.startedAt,
                completedAt: item.completedAt,
                retryCount: item.retryCount,
                summaryText: item.summary,
                consecutivePollFailures: item.consecutivePollFailures,
                hasFileData: item.hasFileData,
                priceUsd: item.priceUsd
            )
        }
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }

        if let ws = worksStore {
            for item in items where item.status == .succeeded || item.status == .failed {
                ws.addRecord(from: item)
            }
        }
    }

    private func loadFromPersistence() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let snapshots = try? JSONDecoder().decode([QueueItemSnapshot].self, from: data)
        else { return }

        items = snapshots.compactMap { snapshot -> GenerationQueueItem? in
            guard snapshot.status == .polling, snapshot.taskId != nil else {
                return nil
            }
            if snapshot.hasFileData {
                return nil
            }
            var item = GenerationQueueItem.restoring(
                id: snapshot.id,
                kind: snapshot.kind,
                createdAt: snapshot.createdAt,
                params: placeholderParams(kind: snapshot.kind, summary: snapshot.summaryText)
            )
            item.status = snapshot.status
            item.taskId = snapshot.taskId
            item.resultUrls = snapshot.resultUrls
            item.videoUrl = snapshot.videoUrl
            item.errorMessage = snapshot.errorMessage
            item.startedAt = snapshot.startedAt
            item.completedAt = snapshot.completedAt
            item.retryCount = snapshot.retryCount
            item.consecutivePollFailures = snapshot.consecutivePollFailures
            item.priceUsd = snapshot.priceUsd
            item.restoredFromPersistence = true
            return item
        }

        if !items.isEmpty {
            startProcessingIfNeeded()
        }
    }

    private func placeholderParams(kind: GenerationJobKind, summary: String) -> JobParams {
        switch kind {
        case .gptImage:
            return .gptImage(GptImageJobParams(prompt: summary, channel: "official", aspectRatio: "1:1", resolution: "2k", quality: "medium", photoReal: false))
        case .banana:
            return .banana(BananaJobParams(prompt: summary, provider: "third_party"))
        case .seedance:
            return .seedance(SeedanceJobParams(prompt: summary, mode: "reference", model: "dreamina-seedance-2-0-260128", ratio: "adaptive", resolution: "720p", duration: 5, count: 1, generateAudio: true))
        case .wan:
            return .wan(WanJobParams(mode: "image", prompt: summary, width: 720, height: 1280, seconds: 5))
        case .veo:
            return .veo(VeoJobParams(prompt: summary))
        case .grok:
            return .grok(GrokJobParams(prompt: summary, channel: "budget", mode: "text", aspectRatio: "9:16", resolution: "720p", duration: "6"))
        }
    }
}
