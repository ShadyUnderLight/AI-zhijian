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
}

// MARK: - Script

struct Script: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var product: String
    var shots: [ScriptShot]
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
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
