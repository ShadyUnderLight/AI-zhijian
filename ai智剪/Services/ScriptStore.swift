import Foundation
import SwiftUI
import OSLog

// MARK: - Script Shot

struct ScriptShot: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String = ""
    var referencePrompt: String = ""
    var videoPrompt: String = ""
    var sortOrder: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, title, referencePrompt, videoPrompt, sortOrder
    }

    init(id: String = UUID().uuidString, title: String = "", referencePrompt: String = "", videoPrompt: String = "", sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.referencePrompt = referencePrompt
        self.videoPrompt = videoPrompt
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        referencePrompt = try container.decodeIfPresent(String.self, forKey: .referencePrompt) ?? ""
        videoPrompt = try container.decodeIfPresent(String.self, forKey: .videoPrompt) ?? ""
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

// MARK: - Script

struct Script: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var product: String
    var shots: [ScriptShot]
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, title, product, shots, createdAt, updatedAt
    }

    init(id: String = UUID().uuidString, title: String, product: String, shots: [ScriptShot], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.product = product
        self.shots = shots
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        product = try container.decode(String.self, forKey: .product)
        shots = try container.decodeIfPresent([ScriptShot].self, forKey: .shots) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

// MARK: - Versioned Wrapper

private struct ScriptListWrapper: Codable {
    static let currentVersion = 1
    var version: Int = currentVersion
    var items: [Script]
}

// MARK: - Script Store

@MainActor
final class ScriptStore: ObservableObject {
    @Published var scripts: [Script] = []

    private static let persistenceKey = "ScriptStore.scripts"
    private static let backupKey = "ScriptStore.scripts.backup"
    private let logger = Logger(subsystem: "AIZhijian", category: "ScriptStore")

    init() {
        load()
    }

    func script(with id: String) -> Script? {
        scripts.first { $0.id == id }
    }

    func save(script: Script) {
        var s = script
        s.updatedAt = Date()
        if let idx = scripts.firstIndex(where: { $0.id == s.id }) {
            scripts[idx] = s
        } else {
            scripts.append(s)
        }
        persist()
    }

    func delete(_ id: String) {
        scripts.removeAll { $0.id == id }
        persist()
    }

    @discardableResult
    func duplicate(_ id: String) -> String? {
        guard let original = script(with: id) else { return nil }
        var copy = original
        copy.id = UUID().uuidString
        copy.title = "\(original.title) - 副本"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.shots = original.shots.enumerated().map { index, shot in
            var copiedShot = shot
            copiedShot.id = UUID().uuidString
            copiedShot.sortOrder = index
            return copiedShot
        }
        save(script: copy)
        return copy.id
    }

    // MARK: - Persistence

    private func persist() {
        let wrapper = ScriptListWrapper(items: scripts)
        do {
            let data = try JSONEncoder().encode(wrapper)
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        } catch {
            logger.error("Failed to encode scripts: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey) else { return }

        do {
            let wrapper = try JSONDecoder().decode(ScriptListWrapper.self, from: data)
            scripts = wrapper.items
            return
        } catch {
            logger.error("Failed to decode script list: \(error.localizedDescription), attempting fallbacks")
        }

        if let legacy = try? JSONDecoder().decode([Script].self, from: data) {
            scripts = legacy
            logger.info("Loaded \(legacy.count) scripts from legacy unversioned format, upgrading")
            persist()
            return
        }

        if let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var recovered: [Script] = []
            for itemDict in raw {
                do {
                    let itemData = try JSONSerialization.data(withJSONObject: itemDict)
                    let script = try JSONDecoder().decode(Script.self, from: itemData)
                    recovered.append(script)
                } catch {
                    logger.warning("Skipping corrupted script entry: \(error.localizedDescription)")
                }
            }
            if !recovered.isEmpty {
                logger.notice("Recovered \(recovered.count) of \(raw.count) scripts from legacy array")
                scripts = recovered
                persist()
                return
            }
        }

        UserDefaults.standard.set(data, forKey: Self.backupKey)
        logger.error("All recovery attempts failed, corrupted data backed up to key '\(Self.backupKey)'")
    }
}
