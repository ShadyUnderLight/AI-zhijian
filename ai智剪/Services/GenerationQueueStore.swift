import Foundation
import AppKit

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
        case .veo(let p): return p.imageData != nil || p.firstImageData != nil || p.lastImageData != nil || p.ref1Data != nil || p.videoData != nil
        case .grok(let p): return !p.imageFiles.isEmpty || p.videoData != nil
        }
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
}

// MARK: - Queue Store

@MainActor
final class GenerationQueueStore: ObservableObject {
    @Published var items: [GenerationQueueItem] = []
    @Published var isPaused = false
    @Published var isProcessing = false

    @Published var concurrencyLimit = 1 {
        didSet {
            concurrencyLimit = min(max(concurrencyLimit, 1), 5)
            processTask?.cancel()
            processTask = nil
            if oldValue != concurrencyLimit {
                startProcessingIfNeeded()
            }
        }
    }
    let maxConsecutivePollFailures = 5

    private let api: APIService
    private var processTask: Task<Void, Never>?
    private var loginObserverTask: Task<Void, Never>?

    private static let persistenceKey = "GenerationQueueStore.items"

    init(api: APIService) {
        self.api = api
        loadFromPersistence()
        observeLoginState()
    }

    var pendingCount: Int { items.count { $0.status == .pending } }
    var submittingCount: Int { items.count { $0.status == .submitting } }
    var pollingCount: Int { items.count { $0.status == .polling } }
    var succeededCount: Int { items.count { $0.status == .succeeded } }
    var failedCount: Int { items.count { $0.status == .failed } }

    var activeTaskCount: Int { submittingCount + pollingCount }

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
        if items[idx].hasFileData {
            items[idx].errorMessage = "无法重试：任务包含文件数据，请从页面重新提交"
            return
        }
        items[idx].status = .pending
        items[idx].errorMessage = nil
        items[idx].retryCount += 1
        items[idx].taskId = nil
        items[idx].resultUrls = []
        items[idx].videoUrl = nil
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
        processTask = Task { await processLoop() }
    }

    private func processLoop() async {
        isProcessing = true
        defer {
            isProcessing = false
            processTask = nil
        }

        while !Task.isCancelled {
            if !isPaused {
                while await submitNextPendingItem() {}
                await pollActiveItems()
            }
            let allDone = items.allSatisfy {
                $0.status == .succeeded || $0.status == .failed || $0.status == .cancelled
            }
            if allDone && pendingCount == 0 {
                break
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    @discardableResult
    private func submitNextPendingItem() async -> Bool {
        let activeCount = items.count { $0.isActive }
        guard activeCount < concurrencyLimit else { return false }

        guard let idx = items.firstIndex(where: { $0.status == .pending }) else { return false }

        if items[idx].restoredFromPersistence {
            if items[idx].hasFileData {
                items[idx].markFailed("持久化恢复失败：文件数据已丢失，请从页面重新提交")
            } else {
                items[idx].markFailed("持久化恢复失败：任务参数已丢失，请从页面重新提交")
            }
            syncActiveTasks()
            persistQueue()
            return true
        }

        items[idx].markSubmitting()
        syncActiveTasks()

        let item = items[idx]
        do {
            try await submitItem(item, at: idx)
        } catch {
            if !Task.isCancelled {
                items[idx].markFailed(error.localizedDescription)
                syncActiveTasks()
                persistQueue()
            }
        }
        return true
    }

    private func submitItem(_ item: GenerationQueueItem, at idx: Int) async throws {
        switch item.params {
        case .gptImage(let p):
            let result: TaskSubmitResponse
            if p.isImageToImage {
                result = try await api.generateImageToImage(
                    prompt: p.prompt, channel: p.channel, aspectRatio: p.aspectRatio,
                    resolution: p.resolution, quality: p.quality,
                    referenceImages: p.referenceImages
                )
            } else {
                result = try await api.generateImage(
                    prompt: p.prompt, channel: p.channel, aspectRatio: p.aspectRatio,
                    resolution: p.resolution, quality: p.quality, photoReal: p.photoReal
                )
            }
            guard let taskId = result.ourTaskId else {
                throw APIError.requestFailed(result.message ?? "未能获取任务ID")
            }
            items[idx].markPolling(taskId: taskId)
            syncActiveTasks()
            persistQueue()

        case .banana(let p):
            let data = try await api.generateBanana(
                prompt: p.prompt, provider: p.provider, referenceImages: p.referenceImages
            )
            if let data {
                items[idx].markSucceeded()
                items[idx].bananaResultImageData = data
            } else {
                throw APIError.requestFailed("未返回图片数据")
            }
            syncActiveTasks()
            persistQueue()

        case .seedance(let p):
            let result = try await api.generateSeedanceVideo(
                prompt: p.prompt, mode: p.mode, model: p.model,
                ratio: p.ratio, resolution: p.resolution,
                duration: p.duration, count: p.count,
                generateAudio: p.generateAudio, assets: p.assets
            )
            if let tasks = result.tasks, let firstTask = tasks.first {
                items[idx].markPolling(taskId: firstTask.ourTaskId)
                for extra in tasks.dropFirst() {
                    var child = GenerationQueueItem(
                        kind: .seedance,
                        createdAt: Date(),
                        params: .seedance(p)
                    )
                    child.markPolling(taskId: extra.ourTaskId)
                    items.append(child)
                }
            } else if let taskId = result.ourTaskId {
                items[idx].markPolling(taskId: taskId)
            } else {
                throw APIError.requestFailed(result.message ?? "未能获取任务ID")
            }
            syncActiveTasks()
            persistQueue()

        case .wan(let p):
            let result: TaskSubmitResponse
            if p.mode == "image" {
                guard let data = p.imageData, let name = p.imageName, let mime = p.imageMime else {
                    throw APIError.requestFailed("请先选择输入图片")
                }
                result = try await api.generateWanVideo(
                    imageData: data, fileName: name, mimeType: mime,
                    prompt: p.prompt, width: p.width, height: p.height, seconds: p.seconds
                )
            } else {
                guard let first = p.firstFrame, let last = p.lastFrame else {
                    throw APIError.requestFailed("请先选择首帧和尾帧图片")
                }
                result = try await api.generateWanFirstLastVideo(
                    firstFrame: first, lastFrame: last,
                    prompt: p.prompt, seconds: p.seconds, enable48G: p.enable48G
                )
            }
            guard let taskId = result.taskId else {
                throw APIError.requestFailed(result.message ?? "未能获取任务ID")
            }
            items[idx].markPolling(taskId: taskId)
            syncActiveTasks()
            persistQueue()

        case .veo(let p):
            var veoParams = VeoParams()
            veoParams.channel = p.channel; veoParams.model = p.model; veoParams.mode = p.mode
            veoParams.prompt = p.prompt; veoParams.aspectRatio = p.aspectRatio
            veoParams.resolution = p.resolution; veoParams.duration = p.duration
            veoParams.generateAudio = p.generateAudio
            veoParams.negativePrompt = p.negativePrompt
            veoParams.imageData = p.imageData; veoParams.imageName = p.imageName; veoParams.imageMime = p.imageMime
            veoParams.firstImageData = p.firstImageData; veoParams.firstImageName = p.firstImageName; veoParams.firstImageMime = p.firstImageMime
            veoParams.lastImageData = p.lastImageData; veoParams.lastImageName = p.lastImageName; veoParams.lastImageMime = p.lastImageMime
            veoParams.ref1Data = p.ref1Data; veoParams.ref2Data = p.ref2Data; veoParams.ref3Data = p.ref3Data
            veoParams.videoData = p.videoData; veoParams.videoName = p.videoName; veoParams.videoMime = p.videoMime

            let result = try await api.generateVeoVideo(params: veoParams)
            guard let taskId = result.ourTaskId else {
                throw APIError.requestFailed(result.message ?? "未能获取任务ID")
            }
            items[idx].markPolling(taskId: taskId)
            syncActiveTasks()
            persistQueue()

        case .grok(let p):
            let result = try await api.generateGrokVideo(
                prompt: p.prompt, channel: p.channel, mode: p.mode,
                aspectRatio: p.aspectRatio, resolution: p.resolution, duration: p.duration,
                imageFiles: p.imageFiles,
                videoData: p.videoData, videoName: p.videoName, videoMime: p.videoMime
            )
            guard let taskId = result.taskId else {
                throw APIError.requestFailed(result.message ?? "未能获取任务ID")
            }
            items[idx].markPolling(taskId: taskId)
            syncActiveTasks()
            persistQueue()
        }
    }

    private func pollActiveItems() async {
        let pollingIndices = items.indices.filter { items[$0].status == .polling && items[$0].taskId != nil }
        for idx in pollingIndices {
            guard items[idx].status == .polling, let taskId = items[idx].taskId else { continue }
            if Task.isCancelled { return }
            let kind = items[idx].kind
            do {
                let result: TaskPollResponse
                switch kind {
                case .gptImage:
                    result = try await api.pollImageTask(taskId)
                    let imageStatus = (result.dbStatus ?? "").uppercased()
                    if imageStatus == "SUCCESS" {
                        items[idx].markSucceeded(resultUrls: result.resultUrls ?? [])
                    } else if imageStatus == "FAILED" || imageStatus == "CANCELLED" {
                        items[idx].markFailed(result.errorMessage ?? "任务失败")
                    }
                case .seedance:
                    result = try await api.pollSeedanceTask(taskId)
                    handlePollResult(idx: idx, result: result)
                case .wan:
                    result = try await api.pollMediaTask(taskId)
                    let mediaStatus = (result.status ?? result.taskStatus ?? "").uppercased()
                    if mediaStatus == "SUCCESS" || mediaStatus == "COMPLETED" {
                        let videoUrl = [result.videoUrl, result.outputUrl]
                            .compactMap { $0 }
                            .first { ExternalURL.sanitizedURL($0) != nil }
                        items[idx].markSucceeded(videoUrl: videoUrl)
                    } else if mediaStatus == "FAILED" || mediaStatus == "CANCELLED" || mediaStatus == "ERROR" {
                        items[idx].markFailed(result.errorMessage ?? result.detailMessage ?? result.message ?? "任务失败")
                    }
                case .veo:
                    result = try await api.pollVeoTask(taskId)
                    handlePollResult(idx: idx, result: result)
                case .grok:
                    result = try await api.pollGrokTask(taskId)
                    let grokStatus = (result.status ?? "").uppercased()
                    if grokStatus == "SUCCESS" {
                        items[idx].markSucceeded(videoUrl: result.outputUrl)
                    } else if grokStatus == "FAILED" || grokStatus == "CANCELLED" || grokStatus == "ERROR" {
                        items[idx].markFailed(result.errorMessage ?? "任务失败")
                    }
                case .banana:
                    break
                }
                if items[idx].status == .polling {
                    items[idx].clearPollFailure()
                }
                syncActiveTasks()
                persistQueue()
            } catch {
                if Task.isCancelled { return }
                items[idx].recordPollFailure(error.localizedDescription)
                if items[idx].consecutivePollFailures >= maxConsecutivePollFailures {
                    items[idx].markFailed("轮询连续失败 \(maxConsecutivePollFailures) 次: \(items[idx].lastPollError ?? error.localizedDescription)")
                }
                syncActiveTasks()
                persistQueue()
            }
        }
    }

    private func handlePollResult(idx: Int, result: TaskPollResponse) {
        let dbStatus = (result.dbStatus ?? "").uppercased()
        if dbStatus == "SUCCESS" {
            items[idx].markSucceeded(videoUrl: result.videoUrl)
        } else if dbStatus == "FAILED" || dbStatus == "CANCELLED" || dbStatus == "ERROR" {
            items[idx].markFailed(result.errorMessage ?? "任务失败")
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
                hasFileData: item.hasFileData
            )
        }
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
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
