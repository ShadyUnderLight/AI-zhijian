import Foundation

// 提交结果：异步任务需要轮询，Banana 同步返回图片数据
struct GenerationSubmitResult {
    let taskId: String
    let priceUsd: String?
    let extraTaskIds: [String]
    let bananaImageData: Data?

    var isBananaComplete: Bool { bananaImageData != nil }
}

// 单次轮询结果
enum GenerationPollTick {
    case stillProcessing
    case processingDetail(String)
    case completed(GenerationOutput)
    case failed(String)
}

// 最终生成输出
enum GenerationOutput {
    case images([String])
    case video(String?)
    case localImage(Data)
}

// 负责执行单个模型生成任务（提交 + 轮询），共享给队列和工作流
@MainActor
final class GenerationTaskExecutor {
    private let api: APIService

    init(api: APIService) {
        self.api = api
    }

    // 提交任务并返回 taskId（异步模型）或图片数据（Banana）
    func submit(_ params: JobParams) async throws -> GenerationSubmitResult {
        switch params {

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
            return GenerationSubmitResult(taskId: taskId, priceUsd: result.priceUsd, extraTaskIds: [], bananaImageData: nil)

        case .banana(let p):
            let data = try await api.generateBanana(
                prompt: p.prompt, provider: p.provider, referenceImages: p.referenceImages
            )
            if let data {
                return GenerationSubmitResult(taskId: "", priceUsd: nil, extraTaskIds: [], bananaImageData: data)
            }
            throw APIError.requestFailed("未返回图片数据")

        case .seedance(let p):
            let result = try await api.generateSeedanceVideo(
                prompt: p.prompt, mode: p.mode, model: p.model,
                ratio: p.ratio, resolution: p.resolution,
                duration: p.duration, count: p.count,
                generateAudio: p.generateAudio, assets: p.assets
            )
            if let tasks = result.tasks, let firstTask = tasks.first {
                let extraIds = tasks.dropFirst().map(\.ourTaskId)
                return GenerationSubmitResult(taskId: firstTask.ourTaskId, priceUsd: result.priceUsd, extraTaskIds: extraIds, bananaImageData: nil)
            } else if let taskId = result.ourTaskId {
                return GenerationSubmitResult(taskId: taskId, priceUsd: result.priceUsd, extraTaskIds: [], bananaImageData: nil)
            }
            throw APIError.requestFailed(result.message ?? "未能获取任务ID")

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
            return GenerationSubmitResult(taskId: taskId, priceUsd: result.priceUsd, extraTaskIds: [], bananaImageData: nil)

        case .veo(let p):
            var veoParams = VeoParams()
            veoParams.channel = p.channel; veoParams.model = p.model; veoParams.mode = p.mode
            veoParams.prompt = p.prompt; veoParams.aspectRatio = p.aspectRatio
            veoParams.resolution = p.resolution
            veoParams.duration = VeoRules.fixedDuration(channel: p.channel, model: p.model, mode: p.mode) ?? p.duration
            veoParams.generateAudio = VeoRules.supportsAudio(channel: p.channel, model: p.model, mode: p.mode) && p.generateAudio
            veoParams.negativePrompt = VeoRules.supportsNegativePrompt(channel: p.channel) ? p.negativePrompt : nil
            veoParams.imageFiles = p.imageFiles
            veoParams.imageData = p.imageData; veoParams.imageName = p.imageName; veoParams.imageMime = p.imageMime
            veoParams.firstImageData = p.firstImageData; veoParams.firstImageName = p.firstImageName; veoParams.firstImageMime = p.firstImageMime
            veoParams.lastImageData = p.lastImageData; veoParams.lastImageName = p.lastImageName; veoParams.lastImageMime = p.lastImageMime
            veoParams.ref1Data = p.ref1Data; veoParams.ref2Data = p.ref2Data; veoParams.ref3Data = p.ref3Data
            veoParams.videoData = p.videoData; veoParams.videoName = p.videoName; veoParams.videoMime = p.videoMime

            let result = try await api.generateVeoVideo(params: veoParams)
            guard let taskId = result.ourTaskId else {
                throw APIError.requestFailed(result.message ?? "未能获取任务ID")
            }
            return GenerationSubmitResult(taskId: taskId, priceUsd: result.priceUsd, extraTaskIds: [], bananaImageData: nil)

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
            return GenerationSubmitResult(taskId: taskId, priceUsd: result.priceUsd, extraTaskIds: [], bananaImageData: nil)
        }
    }

    // 单次轮询，返回 stillProcessing 表示仍在处理中
    func poll(taskId: String, kind: GenerationJobKind) async throws -> GenerationPollTick {
        switch kind {
        case .gptImage:
            let result = try await api.pollImageTask(taskId)
            if result.isTerminalSuccess(for: .image) {
                let urls = result.imageResultUrls
                if urls.isEmpty, let imageData = result.imageResultData {
                    return .completed(.localImage(imageData))
                }
                guard !urls.isEmpty else {
                    return .failed("任务完成但未返回图片链接")
                }
                return .completed(.images(urls))
            }
            if result.isTerminalFailure(for: .image) {
                return .failed(result.errorMessage ?? "任务失败")
            }
            if let detail = Self.mapIntermediateStatus(result) {
                return .processingDetail(detail)
            }
            return .stillProcessing

        case .seedance:
            let result = try await api.pollSeedanceTask(taskId)
            if result.isTerminalSuccess(for: .seedance) {
                guard let videoUrl = result.videoResultUrl else {
                    return .failed("任务完成但未返回视频链接")
                }
                return .completed(.video(videoUrl))
            }
            if result.isTerminalFailure(for: .seedance) {
                return .failed(result.errorMessage ?? "任务失败")
            }
            if let detail = Self.mapIntermediateStatus(result) {
                return .processingDetail(detail)
            }
            return .stillProcessing

        case .wan:
            let result = try await api.pollMediaTask(taskId)
            if result.isTerminalSuccess(for: .wan) {
                guard let videoUrl = result.videoResultUrl else {
                    return .failed("任务完成但未返回视频链接")
                }
                return .completed(.video(videoUrl))
            }
            if result.isTerminalFailure(for: .wan) {
                return .failed(result.errorMessage ?? result.detailMessage ?? result.message ?? "任务失败")
            }
            if let detail = Self.mapIntermediateStatus(result) {
                return .processingDetail(detail)
            }
            return .stillProcessing

        case .veo:
            let result = try await api.pollVeoTask(taskId)
            if result.isTerminalSuccess(for: .veo) {
                guard let videoUrl = result.videoResultUrl else {
                    return .failed("任务完成但未返回视频链接")
                }
                return .completed(.video(videoUrl))
            }
            if result.isTerminalFailure(for: .veo) {
                return .failed(result.errorMessage ?? "任务失败")
            }
            if let detail = Self.mapIntermediateStatus(result) {
                return .processingDetail(detail)
            }
            return .stillProcessing

        case .grok:
            let result = try await api.pollGrokTask(taskId)
            if result.isTerminalSuccess(for: .grok) {
                guard let videoUrl = result.videoResultUrl else {
                    return .failed("任务完成但未返回视频链接")
                }
                return .completed(.video(videoUrl))
            }
            if result.isTerminalFailure(for: .grok) {
                return .failed(result.errorMessage ?? "任务失败")
            }
            if let detail = Self.mapIntermediateStatus(result) {
                return .processingDetail(detail)
            }
            return .stillProcessing

        case .banana:
            return .failed("Banana 任务无需轮询")
        }
    }

    private nonisolated static func mapIntermediateStatus(_ result: TaskPollResponse) -> String? {
        let candidates = [result.rhStatus, result.dbStatus, result.status, result.taskStatus]
        for raw in candidates {
            let key = normalizeStatusKey(raw)
            if key.isEmpty { continue }
            if let detail = mapVendorStatus(key) { return detail }
        }
        return nil
    }

    private nonisolated static func normalizeStatusKey(_ raw: String?) -> String {
        guard let raw else { return "" }
        return raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private nonisolated static func mapVendorStatus(_ raw: String) -> String? {
        switch raw {
        case "QUEUED", "PENDING", "WAITING", "IN_QUEUE":
            return "供应商排队中"
        case "PROCESSING", "RUNNING", "IN_PROGRESS", "GENERATING", "RENDERING":
            return "供应商生成中"
        case "UPLOADING", "SAVING", "STORING":
            return "结果上传中"
        case "DOWNLOADING", "FETCHING", "RETRIEVING":
            return "取回结果中"
        case "POST_PROCESSING", "POSTPROCESSING", "FINALIZING":
            return "后处理中"
        case "SUBMITTED", "ACCEPTED", "STARTED":
            return "已受理"
        default:
            return nil
        }
    }

    // 提交 + 阻塞轮询，供工作流等同步场景使用
    func executeFully(_ params: JobParams, kind: GenerationJobKind, maxTicks: Int = 120, tickInterval: UInt64 = 3_000_000_000) async throws -> GenerationOutput {
        let submission = try await submit(params)
        if let data = submission.bananaImageData {
            return .localImage(data)
        }
        guard !submission.taskId.isEmpty else {
            throw APIError.requestFailed("未能获取任务ID")
        }

        for _ in 0..<maxTicks {
            guard !Task.isCancelled else { throw CancellationError() }
            let tick = try await poll(taskId: submission.taskId, kind: kind)
            switch tick {
            case .completed(let output): return output
            case .failed(let msg): throw APIError.requestFailed(msg)
            case .stillProcessing, .processingDetail: try await Task.sleep(nanoseconds: tickInterval)
            }
        }
        throw APIError.requestFailed("任务超时")
    }

    nonisolated static func testMapIntermediateStatus(_ result: TaskPollResponse) -> String? {
        mapIntermediateStatus(result)
    }
}
