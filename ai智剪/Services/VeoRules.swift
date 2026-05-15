import Foundation

enum VeoRules {

    // MARK: - Model & Mode Options

    static func validModels(channel: String) -> [(String, String)] {
        channel == "budget"
            ? [("fast", "Fast"), ("pro", "Pro")]
            : [("lite", "Lite"), ("fast", "Fast"), ("pro", "Pro")]
    }

    static func validModelValues(channel: String) -> [String] {
        validModels(channel: channel).map(\.0)
    }

    static func validModes(channel: String, model: String) -> [(String, String)] {
        if channel == "budget" && model == "fast" {
            return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧")]
        }
        if channel == "budget" && model == "pro" {
            return [("text", "文生视频"), ("start_end", "首尾帧")]
        }
        if channel == "official" && model == "lite" {
            return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧")]
        }
        if channel == "official" && model == "fast" {
            return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧"), ("extend", "视频扩展")]
        }
        return [("text", "文生视频"), ("image", "图生视频"), ("start_end", "首尾帧"), ("reference", "参考生视频"), ("extend", "视频扩展")]
    }

    static func validModeValues(channel: String, model: String) -> [String] {
        validModes(channel: channel, model: model).map(\.0)
    }

    // MARK: - Capabilities

    static func supportsDuration(channel: String, model: String, mode: String) -> Bool {
        if channel == "budget" { return false }
        if model == "lite" && mode == "start_end" { return false }
        return mode != "reference" && mode != "extend"
    }

    static func supportsAudio(channel: String, model: String, mode: String) -> Bool {
        channel == "official" && model != "lite" && mode != "extend"
    }

    static func supportsAspectRatio(mode: String) -> Bool {
        mode != "reference" && mode != "extend"
    }

    static func lastFrameRequired(channel: String, model: String, mode: String) -> Bool {
        mode == "start_end" && channel == "official" && model == "lite"
    }

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

    static func fixedDuration(channel: String, model: String, mode: String) -> String? {
        if channel == "budget" && mode != "reference" && mode != "extend" { return "8" }
        return nil
    }

    // MARK: - Descriptions

    static func channelDisplayName(_ channel: String) -> String {
        channel == "official" ? "官方" : "低价"
    }

    static func channelDescription(_ channel: String) -> String {
        channel == "official"
            ? "官方渠道，效果更佳，支持更多参数选项"
            : "低价渠道，价格更优惠，时长固定 8s，适合快速验证"
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
