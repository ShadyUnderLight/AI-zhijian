import Foundation
import AppKit

enum GenerationJobKind: String, CaseIterable {
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

enum GenerationQueueStatus: String, CaseIterable {
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
    let id: String = UUID().uuidString
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

    mutating func markSubmitting() {
        status = .submitting
        startedAt = Date()
    }

    mutating func markPolling(taskId: String) {
        self.taskId = taskId
        status = .polling
    }

    mutating func markSucceeded(resultUrls: [String] = [], videoUrl: String? = nil) {
        status = .succeeded
        self.resultUrls = resultUrls
        self.videoUrl = videoUrl
        completedAt = Date()
    }

    mutating func markFailed(_ error: String) {
        status = .failed
        errorMessage = error
        completedAt = Date()
    }

    mutating func markCancelled() {
        status = .cancelled
        completedAt = Date()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GenerationQueueItem, rhs: GenerationQueueItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Queue Store

@MainActor
final class GenerationQueueStore: ObservableObject {
    @Published var items: [GenerationQueueItem] = []
    @Published var isPaused = false
    @Published var isProcessing = false

    let concurrencyLimit = 1

    private let api: APIService
    private var processTask: Task<Void, Never>?

    init(api: APIService) {
        self.api = api
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
    }

    func enqueueBatch(_ batch: [GenerationQueueItem]) {
        items.append(contentsOf: batch)
        syncActiveTasks()
        startProcessingIfNeeded()
    }

    func cancelPendingItem(_ id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].status == .pending else { return }
        items[idx].markCancelled()
        syncActiveTasks()
    }

    func retryFailedItem(_ id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].status == .failed else { return }
        items[idx].status = .pending
        items[idx].errorMessage = nil
        items[idx].retryCount += 1
        items[idx].taskId = nil
        items[idx].resultUrls = []
        items[idx].videoUrl = nil
        items[idx].startedAt = nil
        items[idx].completedAt = nil
        syncActiveTasks()
        startProcessingIfNeeded()
    }

    func clearCompleted() {
        items.removeAll { $0.status == .succeeded || $0.status == .cancelled }
        syncActiveTasks()
    }

    func clearFailed() {
        items.removeAll { $0.status == .failed }
        syncActiveTasks()
    }

    func clearAllCompleted() {
        items.removeAll { $0.status == .succeeded || $0.status == .failed || $0.status == .cancelled }
        syncActiveTasks()
    }

    func pauseQueue() {
        isPaused = true
    }

    func resumeQueue() {
        isPaused = false
        startProcessingIfNeeded()
    }

    // MARK: - Private

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
                await submitNextPendingItem()
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

    private func submitNextPendingItem() async {
        let activeCount = items.count { $0.isActive }
        guard activeCount < concurrencyLimit else { return }

        guard let idx = items.firstIndex(where: { $0.status == .pending }) else { return }
        items[idx].markSubmitting()
        syncActiveTasks()

        let item = items[idx]
        do {
            try await submitItem(item, at: idx)
        } catch {
            if !Task.isCancelled {
                items[idx].markFailed(error.localizedDescription)
                syncActiveTasks()
            }
        }
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

        case .banana(let p):
            let data = try await api.generateBanana(
                prompt: p.prompt, provider: p.provider, referenceImages: p.referenceImages
            )
            if let data, let _ = NSImage(data: data) {
                items[idx].markSucceeded(resultUrls: [])
            } else {
                throw APIError.requestFailed("未返回图片数据")
            }

        case .seedance(let p):
            let result = try await api.generateSeedanceVideo(
                prompt: p.prompt, mode: p.mode, model: p.model,
                ratio: p.ratio, resolution: p.resolution,
                duration: p.duration, count: p.count,
                generateAudio: p.generateAudio, assets: p.assets
            )
            if let tasks = result.tasks, let first = tasks.first {
                items[idx].markPolling(taskId: first.ourTaskId)
            } else if let taskId = result.ourTaskId {
                items[idx].markPolling(taskId: taskId)
            } else {
                throw APIError.requestFailed(result.message ?? "未能获取任务ID")
            }
            syncActiveTasks()

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
                syncActiveTasks()
            } catch {
                if !Task.isCancelled {
                    items[idx].markFailed(error.localizedDescription)
                    syncActiveTasks()
                }
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

    private func syncActiveTasks() {
        for item in items where item.status == .submitting || item.status == .polling {
            api.addTask(id: item.id, type: item.displayType, desc: String(item.summary.prefix(30)))
        }
        for item in items where item.status == .succeeded || item.status == .failed || item.status == .cancelled {
            api.removeTask(id: item.id)
        }
    }
}
