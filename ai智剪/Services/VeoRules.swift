import Foundation

enum VeoRules {

    // MARK: - Channel & Model Validation

    static var channels: [(String, String)] {
        [
            ("budget", "低价"),
            ("official", "RH 官方"),
            ("google", "Google 官方"),
            ("yunwu", "云雾API中转"),
            ("apimart", "APIMart")
        ]
    }

    static func isValidCombination(channel: String, model: String) -> Bool {
        validModelValues(channel: channel).contains(model)
    }

    static func validModels(channel: String) -> [(String, String)] {
        switch channel {
        case "budget":   return [("fast", "Fast"), ("pro", "Pro")]
        case "official", "google":
            return [("lite", "Lite"), ("fast", "Fast"), ("pro", "Pro")]
        case "yunwu":
            return [
                ("veo_3_1", "veo_3_1"),
                ("veo_3_1-fast", "veo_3_1-fast"),
                ("veo_3_1-4K", "veo_3_1-4K"),
                ("veo_3_1-fast-4K", "veo_3_1-fast-4K")
            ]
        case "apimart":
            return [
                ("veo3.1-fast", "Veo 3.1 Fast"),
                ("veo3.1-quality", "Veo 3.1 Quality"),
                ("veo3.1-lite", "Veo 3.1 Lite")
            ]
        default:         return []
        }
    }

    static func validModelValues(channel: String) -> [String] {
        validModels(channel: channel).map(\.0)
    }

    // MARK: - Mode Options

    static func validModes(channel: String, model: String) -> [(String, String)] {
        if channel == "yunwu" {
            switch model {
            case "veo_3_1", "veo_3_1-fast", "veo_3_1-4K", "veo_3_1-fast-4K":
                return [("text", "文生视频"), ("image", "图生视频")]
            default:
                return []
            }
        }
        if channel == "apimart" {
            switch model {
            case "veo3.1-fast":
                return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧"), ("reference", "参考生视频")]
            case "veo3.1-quality":
                return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧")]
            case "veo3.1-lite":
                return [("text", "文生视频")]
            default:
                return []
            }
        }

        switch (channel, model) {
        case ("budget", "fast"):
            return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧")]
        case ("budget", "pro"):
            return [("text", "文生视频"), ("start_end", "首尾帧")]
        case ("official", "lite"), ("google", "lite"):
            return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧")]
        case ("official", "fast"), ("google", "fast"):
            return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧"), ("extend", "视频扩展")]
        case ("official", "pro"), ("google", "pro"):
            return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧"), ("reference", "参考生视频"), ("extend", "视频扩展")]
        default:
            return []
        }
    }

    static func validModeValues(channel: String, model: String) -> [String] {
        validModes(channel: channel, model: model).map(\.0)
    }

    // MARK: - Duration

    static var adjustableDurationOptions: [(String, String)] {
        [("4","4s"), ("6","6s"), ("8","8s")]
    }

    static var workflowDurationOptions: [(String, String)] {
        [("4","4s"), ("6","6s"), ("8","8s"), ("12","12s")]
    }

    /// Whether the user-facing UI should show a duration picker.
    static func supportsDuration(channel: String, model: String, mode: String) -> Bool {
        guard isValidCombination(channel: channel, model: model) else { return false }
        if channel == "yunwu" { return false }
        if channel == "apimart" { return false }
        if channel == "budget" { return false }
        if model == "lite" && mode == "start_end" { return false }
        return mode != "reference" && mode != "extend"
    }

    /// Whether the API request should include a duration field.
    /// Differs from `supportsDuration`: budget text/image/start_end is fixed 8s but must still be sent.
    static func shouldSendDurationValue(channel: String, model: String, mode: String) -> Bool {
        guard isValidCombination(channel: channel, model: model) else { return false }
        if channel == "apimart" {
            return validModeValues(channel: channel, model: model).contains(mode)
        }
        if channel == "yunwu" { return false }
        if mode == "reference" || mode == "extend" { return false }
        if model == "lite" && mode == "start_end" { return false }
        return true
    }

    static func fixedDuration(channel: String, model: String, mode: String) -> String? {
        guard isValidCombination(channel: channel, model: model) else { return nil }
        if channel == "budget" && mode != "reference" && mode != "extend" {
            return "8"
        }
        if channel == "apimart", validModeValues(channel: channel, model: model).contains(mode) {
            return "8"
        }
        return nil
    }

    // MARK: - Audio

    static func supportsAudio(channel: String, model: String, mode: String) -> Bool {
        guard isValidCombination(channel: channel, model: model) else { return false }
        return channel == "official" && model != "lite" && mode != "extend"
    }

    static func supportsNegativePrompt(channel: String) -> Bool {
        channel == "official"
    }

    // MARK: - Aspect Ratio

    static func supportsAspectRatio(mode: String) -> Bool {
        mode != "reference" && mode != "extend"
    }

    static func supportsAspectRatio(channel: String, model: String, mode: String) -> Bool {
        !validAspectRatios(channel: channel, model: model, mode: mode).isEmpty
    }

    static func validAspectRatios(channel: String, model: String, mode: String) -> [(String, String)] {
        guard isValidCombination(channel: channel, model: model) else { return [] }
        if channel == "apimart" {
            guard validModeValues(channel: channel, model: model).contains(mode) else { return [] }
            return [("9:16", "9:16"), ("16:9", "16:9")]
        }
        guard supportsAspectRatio(mode: mode) else { return [] }
        return [("9:16", "9:16"), ("16:9", "16:9"), ("1:1", "1:1")]
    }

    static func validResolutions(channel: String, model: String, mode: String) -> [(String, String)] {
        if channel == "yunwu" {
            return [("720p", "720p")]
        }
        if channel == "apimart" {
            return [("720p", "720p"), ("1080p", "1080p"), ("4k", "4K")]
        }
        if mode == "extend" {
            return channel == "google" ? [("720p", "720p")] : [("720p", "720p"), ("1080p", "1080p")]
        }
        if (channel == "official" || channel == "google") && model == "lite" {
            return [("720p", "720p"), ("1080p", "1080p")]
        }
        return [("720p", "720p"), ("1080p", "1080p"), ("4k", "4K")]
    }

    // MARK: - Frame Requirements

    static func lastFrameRequired(channel: String, model: String, mode: String) -> Bool {
        guard isValidCombination(channel: channel, model: model) else { return false }
        return mode == "start_end" && channel == "official" && model == "lite"
    }

    // MARK: - Image References

    static func supportsMultiImageReferences(channel: String, model: String, mode: String) -> Bool {
        (channel == "budget" && model == "fast" && mode == "image") ||
            (channel == "apimart" && model == "veo3.1-fast" && (mode == "image" || mode == "reference"))
    }

    static func imageReferenceLimit(channel: String, model: String, mode: String) -> Int {
        supportsMultiImageReferences(channel: channel, model: model, mode: mode) ? 3 : 1
    }

    static func imageReferenceMaxBytes(channel: String, model: String, mode: String) -> Int {
        if channel == "budget" { return 30 * 1024 * 1024 }
        if channel == "apimart" { return 10 * 1024 * 1024 }
        if model == "lite" && mode == "image" { return 20 * 1024 * 1024 }
        return 10 * 1024 * 1024
    }

    // MARK: - Descriptions

    static func channelDisplayName(_ channel: String) -> String {
        switch channel {
        case "budget": return "低价"
        case "official": return "RH 官方"
        case "google": return "Google 官方"
        case "yunwu": return "云雾API中转"
        case "apimart": return "APIMart"
        default: return channel
        }
    }

    static func channelDescription(_ channel: String) -> String {
        switch channel {
        case "budget":
            return "低价渠道，价格更优惠，时长固定 8s，适合快速验证"
        case "official":
            return "RunningHub 官方稳定，效果更佳，支持更多参数选项"
        case "google":
            return "谷歌官方 API，经反代提交，支持官方 Veo 模型组合"
        case "yunwu":
            return "云雾 API 中转渠道，支持 Veo 3.1 文生/图生模型"
        case "apimart":
            return "APIMart 渠道，支持 Veo 3.1 文生、图生和首尾帧模式"
        default:
            return channel
        }
    }

    static func modelDescription(_ model: String) -> String {
        switch model {
        case "fast": return "Fast — 快速生成，性价比高"
        case "pro":  return "Pro — 专业模式，画质更优"
        case "lite": return "Lite — 轻量快速，适合简单场景"
        case "veo_3_1": return "Veo 3.1 — 云雾标准模型"
        case "veo_3_1-fast": return "Veo 3.1 Fast — 云雾快速模型"
        case "veo_3_1-4K": return "Veo 3.1 4K — 云雾高分辨率模型"
        case "veo_3_1-fast-4K": return "Veo 3.1 Fast 4K — 云雾快速高分辨率模型"
        case "veo3.1-fast": return "Veo 3.1 Fast — APIMart 快速模型"
        case "veo3.1-quality": return "Veo 3.1 Quality — APIMart 质量模型"
        case "veo3.1-lite": return "Veo 3.1 Lite — APIMart 轻量模型"
        default:     return model
        }
    }

    static func modeDescription(_ mode: String) -> String {
        switch mode {
        case "text":      return "文生视频 — 仅用文字描述生成视频"
        case "image":     return "图生视频 — 输入参考图生成视频"
        case "start_end": return "首尾帧 — 提供起始和结束画面生成视频"
        case "reference": return "参考生视频 — 多张参考图生成视频"
        case "extend":    return "视频扩展 — 基于已有视频继续生成"
        default:          return mode
        }
    }
}
