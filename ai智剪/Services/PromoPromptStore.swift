import Foundation
import OSLog

// MARK: - Model

struct PromoPromptPreset: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var prompt: String

    init(id: UUID = UUID(), name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }

    static func == (lhs: PromoPromptPreset, rhs: PromoPromptPreset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Versioned wrapper for future schema migration
private struct PresetListWrapper: Codable {
    let version: Int
    let presets: [PromoPromptPreset]
}

// MARK: - Store

@MainActor
class PromoPromptStore: ObservableObject {
    @Published var presets: [PromoPromptPreset] = []

    private let userDefaultsKey = "PromoPromptStore.presets"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "aiZhijian", category: "PromoPromptStore")

    init() { load() }

    // MARK: - CRUD

    func add(name: String, prompt: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPrompt.isEmpty else { return }
        let preset = PromoPromptPreset(name: trimmedName, prompt: trimmedPrompt)
        presets.append(preset)
        save()
    }

    func delete(_ id: UUID) {
        presets.removeAll { $0.id == id }
        save()
    }

    func update(_ preset: PromoPromptPreset) {
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[idx] = preset
        save()
    }

    // MARK: - Persistence

    private func save() {
        let wrapper = PresetListWrapper(version: 1, presets: presets)
        do {
            let data = try JSONEncoder().encode(wrapper)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            logger.error("Failed to encode prompt presets: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        // Try versioned wrapper first
        if let wrapper = try? JSONDecoder().decode(PresetListWrapper.self, from: data) {
            presets = wrapper.presets
            return
        }
        // Fallback: try unversioned array (V1 without wrapper)
        if let legacy = try? JSONDecoder().decode([PromoPromptPreset].self, from: data) {
            presets = legacy
            save() // upgrade to versioned format
            return
        }
        logger.warning("Failed to decode prompt presets from UserDefaults")
    }
}
