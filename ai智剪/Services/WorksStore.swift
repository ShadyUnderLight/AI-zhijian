import Foundation
import AppKit
import OSLog

struct WorkRecordMetadata: Codable, Hashable {
    var model: String
    var channel: String
    var aspectRatio: String
    var resolution: String
    var duration: String
}

struct WorkRecordWorkflowSource: Codable, Hashable {
    var workflowId: String
    var workflowName: String
    var runId: String
    var nodeId: String
    var nodeTitle: String
    var batchId: String?
    var batchEntryId: String?
}

struct WorkRecord: Identifiable, Hashable {
    var id: String = UUID().uuidString
    let kind: GenerationJobKind
    let prompt: String
    let metadata: WorkRecordMetadata
    var resultUrls: [String]
    var videoUrl: String?
    var localImagePath: String?
    var errorMessage: String?
    let createdAt: Date
    var completedAt: Date?
    var rating: Int?
    var notes: String?
    var tags: [String] = []
    var priceUsd: String?
    var paramsSnapshot: String?
    var workflowSource: WorkRecordWorkflowSource? = nil

    var displayType: String { kind.displayName }
    var iconName: String { kind.icon }

    var isVideo: Bool {
        switch kind {
        case .gptImage, .banana, .voiceGen, .transcript, .gptStoryboardScene: return false
        case .seedance, .wan, .veo, .grok, .subtitleRemove, .backgroundReplace, .characterReplace, .motionTransfer, .lipSyncImage, .videoReplica, .heygen: return true
        }
    }

    var isSuccess: Bool {
        errorMessage == nil && (!resultUrls.isEmpty || videoUrl != nil || localImagePath != nil)
    }

    var localImage: NSImage? {
        guard let path = localImagePath else { return nil }
        return NSImage(contentsOfFile: path)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: WorkRecord, rhs: WorkRecord) -> Bool { lhs.id == rhs.id }
}

extension WorkRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, kind, prompt, metadata, resultUrls, videoUrl, localImagePath
        case errorMessage, createdAt, completedAt
        case rating, notes, tags, priceUsd, paramsSnapshot, workflowSource
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(GenerationJobKind.self, forKey: .kind)
        prompt = try c.decode(String.self, forKey: .prompt)
        metadata = try c.decode(WorkRecordMetadata.self, forKey: .metadata)
        resultUrls = try c.decode([String].self, forKey: .resultUrls)
        videoUrl = try c.decodeIfPresent(String.self, forKey: .videoUrl)
        localImagePath = try c.decodeIfPresent(String.self, forKey: .localImagePath)
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        priceUsd = try c.decodeIfPresent(String.self, forKey: .priceUsd)
        paramsSnapshot = try c.decodeIfPresent(String.self, forKey: .paramsSnapshot)
        workflowSource = (try? c.decodeIfPresent(WorkRecordWorkflowSource.self, forKey: .workflowSource)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(prompt, forKey: .prompt)
        try c.encode(metadata, forKey: .metadata)
        try c.encode(resultUrls, forKey: .resultUrls)
        try c.encodeIfPresent(videoUrl, forKey: .videoUrl)
        try c.encodeIfPresent(localImagePath, forKey: .localImagePath)
        try c.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(notes, forKey: .notes)
        if !tags.isEmpty { try c.encode(tags, forKey: .tags) }
        try c.encodeIfPresent(priceUsd, forKey: .priceUsd)
        try c.encodeIfPresent(paramsSnapshot, forKey: .paramsSnapshot)
        try c.encodeIfPresent(workflowSource, forKey: .workflowSource)
    }
}

enum WorkRecordParams: Codable {
    case gptImage(channel: String, aspectRatio: String, resolution: String, quality: String, photoReal: Bool)
    case banana(provider: String)
    case seedance(mode: String, model: String, ratio: String, resolution: String, duration: Int, count: Int, generateAudio: Bool)
    case wan(mode: String, width: Int, height: Int, seconds: Int, enable48G: Bool)
    case veo(channel: String, model: String, mode: String, aspectRatio: String, resolution: String, duration: String, generateAudio: Bool, negativePrompt: String?)
    case grok(channel: String, mode: String, aspectRatio: String, resolution: String, duration: String)
    case voiceGen(platform: String)
    case transcript(language: String)
    case subtitleRemove(region: String)
    case backgroundReplace(mode: String)
    case characterReplace(similarity: Double, faceFidelity: Double)
    case motionTransfer(intensity: Double, cropMode: String)
    case lipSyncImage(accuracy: String)
    case videoReplica(targetStyle: String, duration: Int, resolution: String)
    case heygen(avatarId: String, voiceId: String, language: String)
    case gptStoryboardScene(sceneIndex: Int, channel: String, resolution: String)

    init?(from params: JobParams) {
        switch params {
        case .gptImage(let p):
            self = .gptImage(channel: p.channel, aspectRatio: p.aspectRatio, resolution: p.resolution, quality: p.quality, photoReal: p.photoReal)
        case .banana(let p):
            self = .banana(provider: p.provider)
        case .seedance(let p):
            self = .seedance(mode: p.mode, model: p.model, ratio: p.ratio, resolution: p.resolution, duration: p.duration, count: p.count, generateAudio: p.generateAudio)
        case .wan(let p):
            self = .wan(mode: p.mode, width: p.width, height: p.height, seconds: p.seconds, enable48G: p.enable48G)
        case .veo(let p):
            self = .veo(channel: p.channel, model: p.model, mode: p.mode, aspectRatio: p.aspectRatio, resolution: p.resolution, duration: p.duration, generateAudio: p.generateAudio, negativePrompt: p.negativePrompt)
        case .grok(let p):
            self = .grok(channel: p.channel, mode: p.mode, aspectRatio: p.aspectRatio, resolution: p.resolution, duration: p.duration)
        case .voiceGen(let p):
            self = .voiceGen(platform: p.platform)
        case .transcript(let p):
            self = .transcript(language: p.language)
        case .subtitleRemove(let p):
            self = .subtitleRemove(region: p.region)
        case .backgroundReplace(let p):
            self = .backgroundReplace(mode: p.mode)
        case .characterReplace(let p):
            self = .characterReplace(similarity: p.similarity, faceFidelity: p.faceFidelity)
        case .motionTransfer(let p):
            self = .motionTransfer(intensity: p.intensity, cropMode: p.cropMode)
        case .lipSyncImage(let p):
            self = .lipSyncImage(accuracy: p.accuracy)
        case .videoReplica(let p):
            self = .videoReplica(targetStyle: p.targetStyle, duration: p.duration, resolution: p.resolution)
        case .heygen(let p):
            self = .heygen(avatarId: p.avatarId, voiceId: p.voiceId, language: p.language)
        case .gptStoryboardScene(let p):
            self = .gptStoryboardScene(sceneIndex: p.sceneIndex, channel: p.channel, resolution: p.resolution)
        }
    }
}

@MainActor
final class WorksStore: ObservableObject {
    @Published var records: [WorkRecord] = []
    @Published var favoriteIds: Set<String> = []

    private static let recordsKey = "WorksStore.records"
    private static let favoritesKey = "WorksStore.favorites"
    private static let maxRecords = 500
    private static let priceLogger = Logger(subsystem: "AIZhijian", category: "WorksStore")

    private static var worksDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AI 智剪/Works")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    init() { load() }

    func addRecord(from item: GenerationQueueItem) {
        guard item.status == .succeeded || item.status == .failed else { return }

        let resultUrls = item.resultUrls
        var localImagePath: String?
        let videoUrl = item.videoUrl

        if item.status == .succeeded, let imageData = item.bananaResultImageData {
            if let existing = records.first(where: { $0.id == item.id }),
               let existingPath = existing.localImagePath,
               FileManager.default.fileExists(atPath: existingPath) {
                localImagePath = existingPath
            } else {
                let saved = Self.saveWorksImage(data: imageData, prefix: item.kind == .banana ? "banana" : "image")
                localImagePath = saved?.path
            }
        }

        let paramsSnapshot = WorkRecordParams(from: item.params).flatMap { params in
            try? JSONEncoder().encode(params)
        }.flatMap { String(data: $0, encoding: .utf8) }

        var record = WorkRecord(
            id: item.id,
            kind: item.kind,
            prompt: item.summary,
            metadata: extractMetadata(from: item.params),
            resultUrls: resultUrls,
            videoUrl: videoUrl,
            localImagePath: localImagePath,
            errorMessage: item.errorMessage,
            createdAt: item.createdAt,
            completedAt: item.completedAt,
            priceUsd: item.priceUsd,
            paramsSnapshot: paramsSnapshot
        )

        if let existing = records.first(where: { $0.id == item.id }) {
            record.rating = existing.rating
            record.notes = existing.notes
            record.tags = existing.tags
            if record.priceUsd == nil { record.priceUsd = existing.priceUsd }
        }

        insertRecord(record)
    }

    @discardableResult
    func addRecord(
        id: String,
        kind: GenerationJobKind,
        prompt: String,
        metadata: WorkRecordMetadata,
        resultUrls: [String],
        videoUrl: String?,
        localImagePath: String?,
        errorMessage: String?,
        createdAt: Date,
        completedAt: Date?,
        priceUsd: String? = nil,
        params: JobParams? = nil,
        workflowSource: WorkRecordWorkflowSource? = nil
    ) -> WorkRecord {
        let paramsSnapshot = params.flatMap { WorkRecordParams(from: $0) }
            .flatMap { try? JSONEncoder().encode($0) }
            .flatMap { String(data: $0, encoding: .utf8) }
        let record = WorkRecord(
            id: id, kind: kind, prompt: prompt, metadata: metadata,
            resultUrls: resultUrls, videoUrl: videoUrl,
            localImagePath: localImagePath, errorMessage: errorMessage,
            createdAt: createdAt, completedAt: completedAt,
            priceUsd: priceUsd,
            paramsSnapshot: paramsSnapshot,
            workflowSource: workflowSource
        )
        insertRecord(record)
        return record
    }

    private func insertRecord(_ record: WorkRecord) {
        records.removeAll { $0.id == record.id }
        records.append(record)

        if records.count > Self.maxRecords {
            records = Array(records.suffix(Self.maxRecords))
            let remaining = Set(records.map(\.id))
            if favoriteIds != remaining.intersection(favoriteIds) {
                favoriteIds = remaining.intersection(favoriteIds)
                persistFavorites()
            }
        }

        persist()
    }

    func toggleFavorite(_ id: String) {
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
        } else {
            favoriteIds.insert(id)
        }
        persistFavorites()
    }

    var totalCost: Double {
        records
            .filter(\.isSuccess)
            .reduce(0) { $0 + Self.parsePrice($1.priceUsd) }
    }

    var todayCost: Double {
        let cal = Calendar.current
        return records
            .filter(\.isSuccess)
            .filter { cal.isDateInToday($0.completedAt ?? $0.createdAt) }
            .reduce(0) { $0 + Self.parsePrice($1.priceUsd) }
    }

    private static func parsePrice(_ raw: String?) -> Double {
        guard let raw, !raw.isEmpty else { return 0 }
        var cleaned = raw
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "USD", with: "")
            .replacingOccurrences(of: "usd", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("US") { cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        guard let value = Double(cleaned) else {
            Self.priceLogger.debug("parsePrice: 无法解析价格 \"\(raw)\"")
            return 0
        }
        return value
    }

    func isFavorited(_ id: String) -> Bool { favoriteIds.contains(id) }

    func updateRating(_ id: String, rating: Int?) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].rating = rating
        persist()
    }

    func updateNotes(_ id: String, notes: String?) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].notes = notes
        persist()
    }

    func updateTags(_ id: String, tags: [String]) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].tags = tags
        persist()
    }

    func deleteRecord(_ id: String) {
        if let record = records.first(where: { $0.id == id }),
           let path = record.localImagePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        records.removeAll { $0.id == id }
        favoriteIds.remove(id)
        persist()
        persistFavorites()
    }

    func clearAll() {
        for record in records {
            if let path = record.localImagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        records.removeAll()
        favoriteIds.removeAll()
        persist()
        persistFavorites()
    }

    // MARK: - Private

    static func saveWorksImage(data: Data, prefix: String) -> URL? {
        let filename = "\(prefix)-\(UUID().uuidString).png"
        let fileURL = worksDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private func extractMetadata(from params: JobParams) -> WorkRecordMetadata {
        switch params {
        case .gptImage(let p):
            return WorkRecordMetadata(model: "GPT-Image-2", channel: p.channel,
                                       aspectRatio: p.aspectRatio, resolution: p.resolution, duration: "—")
        case .banana(let p):
            return WorkRecordMetadata(model: "Banana", channel: p.provider,
                                       aspectRatio: "—", resolution: "—", duration: "—")
        case .seedance(let p):
            return WorkRecordMetadata(model: p.model, channel: "—",
                                       aspectRatio: p.ratio, resolution: p.resolution, duration: "\(p.duration)s")
        case .wan(let p):
            return WorkRecordMetadata(model: "Wan2.2", channel: "—",
                                       aspectRatio: "\(p.width)×\(p.height)", resolution: "—", duration: "\(p.seconds)s")
        case .veo(let p):
            return WorkRecordMetadata(model: p.model, channel: p.channel,
                                       aspectRatio: p.aspectRatio, resolution: p.resolution, duration: "\(p.duration)s")
        case .grok(let p):
            return WorkRecordMetadata(model: "Grok", channel: p.channel,
                                       aspectRatio: p.aspectRatio, resolution: p.resolution, duration: "\(p.duration)s")
        case .voiceGen:
            return WorkRecordMetadata(model: "语音合成", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .transcript:
            return WorkRecordMetadata(model: "文案提取", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .subtitleRemove:
            return WorkRecordMetadata(model: "视频去字幕", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .backgroundReplace:
            return WorkRecordMetadata(model: "背景替换", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .characterReplace:
            return WorkRecordMetadata(model: "人物替换", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .motionTransfer:
            return WorkRecordMetadata(model: "动作迁移", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .lipSyncImage:
            return WorkRecordMetadata(model: "图片对口型", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .videoReplica:
            return WorkRecordMetadata(model: "视频复刻", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .heygen:
            return WorkRecordMetadata(model: "HeyGen 数字人", channel: "—", aspectRatio: "—", resolution: "—", duration: "—")
        case .gptStoryboardScene(let p):
            return WorkRecordMetadata(model: "故事板分镜", channel: p.channel, aspectRatio: "—", resolution: p.resolution, duration: "—")
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: Self.recordsKey)
        }
    }

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(Array(favoriteIds)) {
            UserDefaults.standard.set(data, forKey: Self.favoritesKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.recordsKey),
           let decoded = try? JSONDecoder().decode([WorkRecord].self, from: data) {
            records = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.favoritesKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            favoriteIds = Set(decoded)
        }
    }
}
