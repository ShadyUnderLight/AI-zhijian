import Foundation
import SwiftUI
import OSLog

// MARK: - Preset Kind

enum PresetKind: String, Codable, CaseIterable {
    case gptImage
    case banana
    case seedance
    case wan
    case veo
    case grok
    case voiceGen
    case transcript
    case subtitleRemove
    case backgroundReplace

    var displayName: String {
        switch self {
        case .gptImage: return "GPT-Image-2"
        case .banana: return "Banana"
        case .seedance: return "Seedance"
        case .wan: return "Wan"
        case .veo: return "Veo"
        case .grok: return "Grok"
        case .voiceGen: return "语音生成"
        case .transcript: return "视频文案提取"
        case .subtitleRemove: return "视频去字幕"
        case .backgroundReplace: return "视频背景替换"
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
    case voiceGen(VoiceGenPresetParams)
    case transcript(TranscriptPresetParams)
    case subtitleRemove(SubtitleRemovePresetParams)
    case backgroundReplace(BackgroundReplacePresetParams)

    var kind: PresetKind {
        switch self {
        case .gptImage: return .gptImage
        case .banana: return .banana
        case .seedance: return .seedance
        case .wan: return .wan
        case .veo: return .veo
        case .grok: return .grok
        case .voiceGen: return .voiceGen
        case .transcript: return .transcript
        case .subtitleRemove: return .subtitleRemove
        case .backgroundReplace: return .backgroundReplace
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

struct VoiceGenPresetParams: Codable {
    var platform: String = "elevenlabs"
    var voiceId: String = ""
    var modelId: String = ""
    var speed: Double = 1.0
    var stability: Double = 0.5
    var similarityBoost: Double = 0.75
    var style: Double = 0.0
}

struct TranscriptPresetParams: Codable {
    var language: String = "zh"
}

struct SubtitleRemovePresetParams: Codable {
    var region: String = "full"
}

struct BackgroundReplacePresetParams: Codable {
    var mode: String = "replace"
}

// MARK: - Preset

struct Preset: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var kind: PresetKind
    var params: PresetParams
    var createdAt: Date = Date()
}

// MARK: - Versioned Wrapper (for future schema migrations)

private struct PresetListWrapper: Codable {
    static let currentVersion = 1
    var version: Int = currentVersion
    var items: [Preset]
}

// MARK: - Preset Store

@MainActor
final class PresetStore: ObservableObject {
    @Published var presets: [Preset] = []

    private static let persistenceKey = "PresetStore.presets"
    private static let backupKey = "PresetStore.presets.backup"
    private let logger = Logger(subsystem: "AIZhijian", category: "PresetStore")

    init() {
        load()
    }

    func presets(for kind: PresetKind) -> [Preset] {
        presets.filter { $0.kind == kind }
    }

    func save(name: String, params: PresetParams) {
        let preset = Preset(name: name, kind: params.kind, params: params)
        presets.append(preset)
        persist()
    }

    func delete(_ id: String) {
        presets.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        let wrapper = PresetListWrapper(items: presets)
        do {
            let data = try JSONEncoder().encode(wrapper)
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        } catch {
            logger.error("Failed to encode presets: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey) else { return }

        do {
            let wrapper = try JSONDecoder().decode(PresetListWrapper.self, from: data)
            presets = wrapper.items
            return
        } catch {
            logger.error("Failed to decode preset list: \(error.localizedDescription), attempting fallbacks")
        }

        // try legacy format (unversioned array)
        if let legacy = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = legacy
            logger.info("Loaded \(legacy.count) presets from legacy unversioned format, upgrading")
            persist()
            return
        }

        // try per-item recovery from legacy array
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var recovered: [Preset] = []
            for itemDict in raw {
                do {
                    let itemData = try JSONSerialization.data(withJSONObject: itemDict)
                    let preset = try JSONDecoder().decode(Preset.self, from: itemData)
                    recovered.append(preset)
                } catch {
                    logger.warning("Skipping corrupted preset entry: \(error.localizedDescription)")
                }
            }
            if !recovered.isEmpty {
                logger.notice("Recovered \(recovered.count) of \(raw.count) presets from legacy array")
                presets = recovered
                persist()
                return
            }
        }

        // keep backup of corrupted data for manual recovery
        UserDefaults.standard.set(data, forKey: Self.backupKey)
        logger.error("All recovery attempts failed, corrupted data backed up to key '\(Self.backupKey)'")
    }
}
