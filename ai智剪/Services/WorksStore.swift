import Foundation
import AppKit

struct WorkRecordMetadata: Codable, Hashable {
    var model: String
    var channel: String
    var aspectRatio: String
    var resolution: String
    var duration: String
}

struct WorkRecord: Identifiable, Codable, Hashable {
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
    var paramsSnapshot: String?

    var displayType: String { kind.displayName }
    var iconName: String { kind.icon }

    var isVideo: Bool {
        switch kind {
        case .gptImage, .banana: return false
        case .seedance, .wan, .veo, .grok: return true
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

enum WorkRecordParams: Codable {
    case gptImage(channel: String, aspectRatio: String, resolution: String, quality: String, photoReal: Bool)
    case banana(provider: String)
    case seedance(mode: String, model: String, ratio: String, resolution: String, duration: Int, count: Int, generateAudio: Bool)
    case wan(mode: String, width: Int, height: Int, seconds: Int, enable48G: Bool)
    case veo(channel: String, model: String, mode: String, aspectRatio: String, resolution: String, duration: String, generateAudio: Bool, negativePrompt: String?)
    case grok(channel: String, mode: String, aspectRatio: String, resolution: String, duration: String)

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
            paramsSnapshot: paramsSnapshot
        )

        if let existing = records.first(where: { $0.id == item.id }) {
            record.rating = existing.rating
            record.notes = existing.notes
            record.tags = existing.tags
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
        params: JobParams? = nil
    ) -> WorkRecord {
        let paramsSnapshot = params.flatMap { WorkRecordParams(from: $0) }
            .flatMap { try? JSONEncoder().encode($0) }
            .flatMap { String(data: $0, encoding: .utf8) }
        let record = WorkRecord(
            id: id, kind: kind, prompt: prompt, metadata: metadata,
            resultUrls: resultUrls, videoUrl: videoUrl,
            localImagePath: localImagePath, errorMessage: errorMessage,
            createdAt: createdAt, completedAt: completedAt,
            paramsSnapshot: paramsSnapshot
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
