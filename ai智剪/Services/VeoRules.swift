import Foundation

enum VeoRules {

    // MARK: - Channel & Model Validation

    static var channels: [(String, String)] {
        [
            ("budget", "低价"),
            ("official", "RH 官方"),
            ("google", "Google 官方")
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
        default:         return []
        }
    }

    static func validModelValues(channel: String) -> [String] {
        validModels(channel: channel).map(\.0)
    }

    // MARK: - Mode Options

    static func validModes(channel: String, model: String) -> [(String, String)] {
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
        if channel == "budget" { return false }
        if model == "lite" && mode == "start_end" { return false }
        return mode != "reference" && mode != "extend"
    }

    /// Whether the API request should include a duration field.
    /// Differs from `supportsDuration`: budget text/image/start_end is fixed 8s but must still be sent.
    static func shouldSendDurationValue(channel: String, model: String, mode: String) -> Bool {
        guard isValidCombination(channel: channel, model: model) else { return false }
        if mode == "reference" || mode == "extend" { return false }
        if model == "lite" && mode == "start_end" { return false }
        return true
    }

    static func fixedDuration(channel: String, model: String, mode: String) -> String? {
        guard isValidCombination(channel: channel, model: model) else { return nil }
        if channel == "budget" && mode != "reference" && mode != "extend" {
            return "8"
        }
        return nil
    }

    // MARK: - Audio

    static func supportsAudio(channel: String, model: String, mode: String) -> Bool {
        guard isValidCombination(channel: channel, model: model) else { return false }
        return channel == "official" && model != "lite" && mode != "extend"
    }

    // MARK: - Aspect Ratio

    static func supportsAspectRatio(mode: String) -> Bool {
        mode != "reference" && mode != "extend"
    }

    static func validResolutions(channel: String, model: String, mode: String) -> [(String, String)] {
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
        channel == "budget" && model == "fast" && mode == "image"
    }

    static func imageReferenceLimit(channel: String, model: String, mode: String) -> Int {
        supportsMultiImageReferences(channel: channel, model: model, mode: mode) ? 3 : 1
    }

    static func imageReferenceMaxBytes(channel: String, model: String, mode: String) -> Int {
        if channel == "budget" { return 30 * 1024 * 1024 }
        if model == "lite" && mode == "image" { return 20 * 1024 * 1024 }
        return 10 * 1024 * 1024
    }

    // MARK: - Descriptions

    static func channelDisplayName(_ channel: String) -> String {
        switch channel {
        case "budget": return "低价"
        case "official": return "RH 官方"
        case "google": return "Google 官方"
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
        default:
            return channel
        }
    }

    static func modelDescription(_ model: String) -> String {
        switch model {
        case "fast": return "Fast — 快速生成，性价比高"
        case "pro":  return "Pro — 专业模式，画质更优"
        case "lite": return "Lite — 轻量快速，适合简单场景"
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
