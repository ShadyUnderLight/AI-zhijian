import Foundation

// MARK: - Model

struct PromoPromptPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var prompt: String

    init(id: UUID = UUID(), name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }

    // Identity-based equality (id only)
    static func == (lhs: PromoPromptPreset, rhs: PromoPromptPreset) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Store

class PromoPromptStore: ObservableObject {
    @Published var presets: [PromoPromptPreset] = []

    private let userDefaultsKey = "PromoPromptStore.presets"

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
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([PromoPromptPreset].self, from: data) {
            presets = decoded
        }
    }
}
