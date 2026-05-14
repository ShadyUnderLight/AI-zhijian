import Foundation

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
    var errorMessage: String?
    let createdAt: Date
    var completedAt: Date?

    var displayType: String { kind.displayName }
    var iconName: String { kind.icon }

    var isVideo: Bool {
        switch kind {
        case .gptImage, .banana: return false
        case .seedance, .wan, .veo, .grok: return true
        }
    }

    var isSuccess: Bool { errorMessage == nil && (!resultUrls.isEmpty || videoUrl != nil) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: WorkRecord, rhs: WorkRecord) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class WorksStore: ObservableObject {
    @Published var records: [WorkRecord] = []
    @Published var favoriteIds: Set<String> = []

    private static let recordsKey = "WorksStore.records"
    private static let favoritesKey = "WorksStore.favorites"
    private static let maxRecords = 500

    init() { load() }

    func addRecord(from item: GenerationQueueItem) {
        guard item.status == .succeeded || item.status == .failed else { return }

        let record = WorkRecord(
            id: item.id,
            kind: item.kind,
            prompt: item.summary,
            metadata: extractMetadata(from: item.params),
            resultUrls: item.resultUrls,
            videoUrl: item.videoUrl,
            errorMessage: item.errorMessage,
            createdAt: item.createdAt,
            completedAt: item.completedAt
        )

        records.removeAll { $0.id == record.id }
        records.append(record)

        if records.count > Self.maxRecords {
            records = Array(records.suffix(Self.maxRecords))
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

    func deleteRecord(_ id: String) {
        records.removeAll { $0.id == id }
        favoriteIds.remove(id)
        persist()
        persistFavorites()
    }

    func updateRecordUrls(id: String, resultUrls: [String], videoUrl: String?) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].resultUrls = resultUrls
        records[idx].videoUrl = videoUrl
        records[idx].errorMessage = nil
        persist()
    }

    // MARK: - Private

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
