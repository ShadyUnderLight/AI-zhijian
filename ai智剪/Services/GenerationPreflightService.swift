import Foundation

@MainActor
final class GenerationPreflightService: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case ready(Result)
        case insufficient(Result)
        case unavailable
        case error(String)

        var isBlocking: Bool {
            if case .insufficient = self { return true }
            return false
        }

        var balanceSufficient: Bool {
            if case .ready = self { return true }
            if case .insufficient = self { return false }
            return true
        }
    }

    struct Result: Equatable {
        let estimatedPriceUsd: String
        let estimatedDurationSeconds: Int
        let balanceSufficient: Bool
        let blockingReasons: [String]
        let itemCount: Int
    }

    @Published var state: State = .idle

    private let api: APIService
    private var task: Task<Void, Never>?

    init(api: APIService = .shared) {
        self.api = api
    }

    func schedule(for params: JobParams) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }

            await self.applyState(from: params)
        }
    }

    func scheduleBatch(for items: [JobParams]) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }

            guard let first = items.first else {
                self.state = .error("批量任务列表为空")
                return
            }
            await self.applyBatchState(from: first, batchCount: items.count)
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        state = .idle
    }

    func preflightNow(for params: JobParams) async -> State {
        await applyState(from: params)
        return state
    }

    func preflightNowBatch(for items: [JobParams]) async -> State {
        guard let first = items.first else {
            return .error("批量任务列表为空")
        }
        await applyBatchState(from: first, batchCount: items.count)
        return state
    }

    func makeBody(_ params: JobParams) -> [String: Any] {
        switch params {
        case .gptImage(let p):
            return [
                "model": "gpt-image-2",
                "channel": p.channel,
                "aspectRatio": p.aspectRatio,
                "resolution": p.resolution,
                "quality": p.quality,
                "photoReal": p.photoReal,
                "isImageToImage": p.isImageToImage,
                "referenceCount": p.referenceImages.count,
                "hasPrompt": !p.prompt.isEmpty
            ]

        case .banana(let p):
            return [
                "model": "banana",
                "provider": p.provider,
                "referenceCount": p.referenceImages.count,
                "hasPrompt": !p.prompt.isEmpty
            ]

        case .seedance(let p):
            return [
                "model": "seedance20",
                "mode": p.mode,
                "internalModel": p.model,
                "ratio": p.ratio,
                "resolution": p.resolution,
                "duration": p.duration,
                "count": p.count,
                "generateAudio": p.generateAudio,
                "assetCount": p.assets.count,
                "hasPrompt": !p.prompt.isEmpty
            ]

        case .wan(let p):
            return [
                "model": "wan21",
                "mode": p.mode,
                "width": p.width,
                "height": p.height,
                "duration": p.seconds,
                "enable48G": p.enable48G,
                "hasImage": p.imageData != nil,
                "hasFirstFrame": p.firstFrame != nil,
                "hasLastFrame": p.lastFrame != nil,
                "hasPrompt": !p.prompt.isEmpty
            ]

        case .veo(let p):
            let refCount = [p.ref1Data, p.ref2Data, p.ref3Data].filter { $0 != nil }.count
            return [
                "model": "veo-video",
                "channel": p.channel,
                "internalModel": p.model,
                "mode": p.mode,
                "aspectRatio": p.aspectRatio,
                "resolution": p.resolution,
                "duration": p.duration,
                "generateAudio": p.generateAudio,
                "hasImageFiles": p.imageData != nil || !p.imageFiles.isEmpty,
                "hasFirstImage": p.firstImageData != nil,
                "hasLastImage": p.lastImageData != nil,
                "refCount": refCount,
                "hasVideo": p.videoData != nil,
                "hasPrompt": !p.prompt.isEmpty
            ]

        case .grok(let p):
            return [
                "model": "grok-video",
                "channel": p.channel,
                "mode": p.mode,
                "aspectRatio": p.aspectRatio,
                "resolution": p.resolution,
                "duration": p.duration,
                "imageCount": p.imageFiles.count,
                "hasVideo": p.videoData != nil,
                "hasPrompt": !p.prompt.isEmpty
            ]
        }
    }

    private func applyState(from params: JobParams) async {
        state = .loading
        do {
            let body = makeBody(params)
            let resp = try await api.preflight(body: body)
            guard !Task.isCancelled else { return }

            if !resp.success {
                state = .error(resp.message ?? "预估算失败")
                return
            }
            let price = resp.estimatedPriceUsd ?? "未知"
            let sufficient = resp.balanceSufficient ?? true
            let info = Result(
                estimatedPriceUsd: price,
                estimatedDurationSeconds: resp.estimatedDurationSeconds ?? -1,
                balanceSufficient: sufficient,
                blockingReasons: resp.blockingReasons ?? (sufficient ? [] : ["余额不足"]),
                itemCount: 1
            )
            state = sufficient ? .ready(info) : .insufficient(info)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .unavailable
        }
    }

    private func applyBatchState(from first: JobParams, batchCount: Int) async {
        state = .loading
        do {
            var body = makeBody(first)
            body["batchCount"] = batchCount
            let resp = try await api.preflight(body: body)
            guard !Task.isCancelled else { return }

            if !resp.success {
                state = .error(resp.message ?? "批量预估算失败")
                return
            }
            let price = resp.estimatedPriceUsd ?? "未知"
            let sufficient = resp.balanceSufficient ?? true
            let info = Result(
                estimatedPriceUsd: price,
                estimatedDurationSeconds: resp.estimatedDurationSeconds ?? -1,
                balanceSufficient: sufficient,
                blockingReasons: resp.blockingReasons ?? (sufficient ? [] : ["余额不足"]),
                itemCount: batchCount
            )
            state = sufficient ? .ready(info) : .insufficient(info)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .unavailable
        }
    }
}
