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

    private static let legacyPersistenceKey = "ScriptStore.scripts"
    private static let legacyBackupKey = "ScriptStore.scripts.backup"
    private static let fileName = "scripts.json"
    private static let backupFileName = "scripts.backup.json"
    private let logger = Logger(subsystem: "AIZhijian", category: "ScriptStore")

    /// For tests only. When set, file persistence uses this directory.
    nonisolated(unsafe) static var baseDirectoryOverride: URL?

    private static var baseDirectory: URL {
        if let override = baseDirectoryOverride {
            try? FileManager.default.createDirectory(at: override, withIntermediateDirectories: true)
            return override
        }
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AI 智剪/Scripts")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var scriptsURL: URL {
        baseDirectory.appendingPathComponent(fileName)
    }

    private static var backupURL: URL {
        baseDirectory.appendingPathComponent(backupFileName)
    }

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
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(wrapper)
            try data.write(to: Self.scriptsURL, options: .atomic)
            UserDefaults.standard.set(data, forKey: Self.legacyPersistenceKey)
        } catch {
            logger.error("Failed to encode scripts: \(error.localizedDescription)")
        }
    }

    private func load() {
        if let data = try? Data(contentsOf: Self.scriptsURL),
           loadFromData(data, source: "file") {
            return
        }

        if FileManager.default.fileExists(atPath: Self.scriptsURL.path) {
            backupCorruptedFile()
            logger.error("Failed to decode script file, attempting legacy UserDefaults migration")
        }

        guard let data = UserDefaults.standard.data(forKey: Self.legacyPersistenceKey) else { return }
        if loadFromData(data, source: "legacy UserDefaults") {
            persist()
            return
        }

        UserDefaults.standard.set(data, forKey: Self.legacyBackupKey)
        logger.error("All recovery attempts failed, corrupted data backed up to legacy key '\(Self.legacyBackupKey)'")
    }

    private func loadFromData(_ data: Data, source: String) -> Bool {
        do {
            let wrapper = try JSONDecoder().decode(ScriptListWrapper.self, from: data)
            scripts = wrapper.items
            logger.info("Loaded \(wrapper.items.count) scripts from \(source)")
            return true
        } catch {
            logger.error("Failed to decode script list from \(source): \(error.localizedDescription), attempting fallbacks")
        }

        if let legacy = try? JSONDecoder().decode([Script].self, from: data) {
            scripts = legacy
            logger.info("Loaded \(legacy.count) scripts from legacy unversioned format in \(source), upgrading")
            persist()
            return true
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
                logger.notice("Recovered \(recovered.count) of \(raw.count) scripts from legacy array in \(source)")
                scripts = recovered
                persist()
                return true
            }
        }

        return false
    }

    private func backupCorruptedFile() {
        guard let data = try? Data(contentsOf: Self.scriptsURL) else { return }
        do {
            try data.write(to: Self.backupURL, options: .atomic)
        } catch {
            logger.error("Failed to back up corrupted script file: \(error.localizedDescription)")
        }
    }
}
