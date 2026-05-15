import Foundation
import SwiftUI

// MARK: - Preset Kind

enum PresetKind: String, Codable, CaseIterable {
    case gptImage
    case banana
    case seedance
    case wan
    case veo
    case grok

    var displayName: String {
        switch self {
        case .gptImage: return "GPT-Image-2"
        case .banana: return "Banana"
        case .seedance: return "Seedance"
        case .wan: return "Wan"
        case .veo: return "Veo"
        case .grok: return "Grok"
        }
    }
}

// MARK: - Preset Params (text-only, no file refs)

enum PresetParams: Codable {
    case gptImage(GptImagePresetParams)
    case banana(BananaPresetParams)
    case seedance(SeedancePresetParams)
    case wan(WanPresetParams)
    case veo(VeoPresetParams)
    case grok(GrokPresetParams)

    var kind: PresetKind {
        switch self {
        case .gptImage: return .gptImage
        case .banana: return .banana
        case .seedance: return .seedance
        case .wan: return .wan
        case .veo: return .veo
        case .grok: return .grok
        }
    }
}

struct GptImagePresetParams: Codable {
    var prompt: String = ""
    var channel: String = "official"
    var aspectRatio: String = "9:16"
    var resolution: String = "2k"
    var quality: String = "medium"
    var photoReal: Bool = false
}

struct BananaPresetParams: Codable {
    var prompt: String = ""
    var provider: String = "third_party"
}

struct SeedancePresetParams: Codable {
    var prompt: String = ""
    var mode: String = "reference"
    var model: String = "dreamina-seedance-2-0-260128"
    var ratio: String = "adaptive"
    var resolution: String = "720p"
    var duration: Int = 5
    var count: Int = 1
    var generateAudio: Bool = true
}

struct WanPresetParams: Codable {
    var mode: String = "image"
    var prompt: String = ""
    var width: Int = 720
    var height: Int = 1280
    var seconds: Int = 5
    var enable48G: Bool = false
}

struct VeoPresetParams: Codable {
    var prompt: String = ""
    var channel: String = "budget"
    var model: String = "fast"
    var mode: String = "text"
    var aspectRatio: String = "9:16"
    var resolution: String = "720p"
    var duration: String = "8"
    var generateAudio: Bool = false
    var negativePrompt: String = ""
}

struct GrokPresetParams: Codable {
    var prompt: String = ""
    var channel: String = "budget"
    var mode: String = "text"
    var aspectRatio: String = "9:16"
    var resolution: String = "720p"
    var duration: String = "6"
}

// MARK: - Preset

struct Preset: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var kind: PresetKind
    var params: PresetParams
    var createdAt: Date = Date()
}

// MARK: - Preset Store

@MainActor
final class PresetStore: ObservableObject {
    @Published var presets: [Preset] = []

    private static let persistenceKey = "PresetStore.presets"

    init() {
        load()
    }

    func presets(for kind: PresetKind) -> [Preset] {
        presets.filter { $0.kind == kind }
    }

    func save(name: String, kind: PresetKind, params: PresetParams) {
        let preset = Preset(name: name, kind: kind, params: params)
        presets.append(preset)
        persist()
    }

    func delete(_ id: String) {
        presets.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let decoded = try? JSONDecoder().decode([Preset].self, from: data)
        else { return }
        presets = decoded
    }
}
