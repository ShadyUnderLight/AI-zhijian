import Foundation
import SwiftUI

extension Date {
    /// Current time truncated to millisecond precision, for roundtrip-safe encoding.
    static var nowTruncatedToMilliseconds: Date {
        let t = Date().timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (t * 1000).rounded() / 1000)
    }

    /// Truncate to millisecond precision.
    var truncatedToMilliseconds: Date {
        Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate * 1000).rounded() / 1000)
    }
}

// MARK: - Workflow Point

struct WorkflowPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double

    static let zero = WorkflowPoint(x: 0, y: 0)
}

// MARK: - Port Type

enum WorkflowPortType: String, Codable, CaseIterable {
    case text
    case image
    case video
    case file
    case json
    case any

    var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .video: return "视频"
        case .file: return "文件"
        case .json: return "JSON"
        case .any: return "任意"
        }
    }
}

// MARK: - Port Role (stable key for programmatic access)

enum WorkflowPortRole: String, Codable, Hashable {
    case text           // 文本输入/输出
    case prompt         // 提示词输入
    case image          // 图片输入/输出（通用）
    case firstFrame     // 首帧图片输入
    case lastFrame      // 尾帧图片输入
    case video          // 视频输出
    case input          // 结果收集输入
    case styleVariable  // 模板变量输入
}

// MARK: - Port

struct WorkflowPort: Identifiable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var portType: WorkflowPortType
    var nodeId: String
    var role: WorkflowPortRole

    /// Return a copy with `nodeId` set to the given value.
    func withNodeId(_ nodeId: String) -> WorkflowPort {
        var copy = self
        copy.nodeId = nodeId
        return copy
    }

    /// Infer a default role from port type and name, for decoding legacy data.
    static func inferRole(name: String, portType: WorkflowPortType) -> WorkflowPortRole {
        switch (portType, name) {
        case (.text, "文本"): return .styleVariable
        case (.text, "提示词"): return .prompt
        case (.text, _): return .text
        case (.image, "首帧图片"): return .firstFrame
        case (.image, "尾帧图片"): return .lastFrame
        case (.image, _): return .image
        case (.video, _): return .video
        case (.any, _): return .input
        default: return .text
        }
    }
}

// MARK: - WorkflowPort Codable (backward-compatible)

extension WorkflowPort: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, portType, nodeId, role
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(portType, forKey: .portType)
        try container.encode(nodeId, forKey: .nodeId)
        try container.encode(role, forKey: .role)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        portType = try container.decode(WorkflowPortType.self, forKey: .portType)
        nodeId = try container.decode(String.self, forKey: .nodeId)
        // role 缺失时按 portType/name 推断，兼容旧版 JSON
        role = try container.decodeIfPresent(WorkflowPortRole.self, forKey: .role)
            ?? Self.inferRole(name: name, portType: portType)
    }
}

// MARK: - Config Value Enums

enum ImageGenType: String, Codable, CaseIterable {
    case gptImage = "gpt-image"
    case banana
}

enum ImageChannel: String, Codable, CaseIterable {
    case official
    case budget
}

enum ImageResolution: String, Codable, CaseIterable {
    case k1 = "1k"
    case k2 = "2k"
    case k4 = "4k"
}

enum ImageQuality: String, Codable, CaseIterable {
    case low
    case medium
    case high
}

enum AspectRatio: String, Codable, CaseIterable {
    case adaptive
    case square = "1:1"
    case landscape = "16:9"
    case portrait = "9:16"
    case twoThree = "2:3"
    case threeTwo = "3:2"
    case fourThree = "4:3"
    case threeFour = "3:4"
    case fourFive = "4:5"
    case fiveFour = "5:4"
    case twentyOneNine = "21:9"
}

enum VideoGenType: String, Codable, CaseIterable {
    case veo
    case grok
    case seedance
    case wan
}

enum VideoChannel: String, Codable, CaseIterable {
    case official
    case budget
    case google
    case yunwu
    case xai
    case apimart
}

enum VideoMode: String, Codable, CaseIterable {
    case text
    case image
    case reference
    case startEnd = "start_end"
    case extend
    case firstLast = "first_last"
    case edit
}

enum VideoResolution: String, Codable, CaseIterable {
    case p480 = "480p"
    case p720 = "720p"
    case p1080 = "1080p"
    case k4 = "4k"
}

// MARK: - Node Configs

struct TextInputNodeConfig: Codable, Equatable, Hashable {
    var text: String = ""

    func validate() -> [WorkflowValidationError] {
        var errors: [WorkflowValidationError] = []
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidConfig("文本输入不能为空"))
        }
        return errors
    }
}

struct PromptTemplateNodeConfig: Codable, Equatable, Hashable {
    var template: String = ""

    func validate() -> [WorkflowValidationError] {
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [.invalidConfig("提示词模板不能为空")]
        }
        return []
    }
}

struct ImageGenNodeConfig: Codable, Equatable, Hashable {
    var genType: ImageGenType = .gptImage
    var channel: ImageChannel = .official
    var aspectRatio: AspectRatio = .portrait
    var resolution: ImageResolution = .k2
    var quality: ImageQuality = .medium
    var photoReal: Bool = false

    func validate() -> [WorkflowValidationError] { [] }
}

struct VideoGenNodeConfig: Codable, Equatable, Hashable {
    var genType: VideoGenType = .veo
    var channel: VideoChannel = .budget
    var model: String = "fast"
    var mode: VideoMode = .text
    var aspectRatio: AspectRatio = .portrait
    var resolution: VideoResolution = .p720
    var duration: String = "8"
    var generateAudio: Bool = false
    var negativePrompt: String = ""
    var count: Int = 1

    func validate() -> [WorkflowValidationError] {
        var errors: [WorkflowValidationError] = []
        let validModels: Set<String>
        let validModes: Set<VideoMode>

        switch genType {
        case .veo:
            if channel == .xai || channel == .apimart {
                errors.append(.invalidConfig("Veo 不支持 Grok 渠道"))
                return errors
            }
            validModels = Set(VeoRules.validModelValues(channel: channel.rawValue))
            validModes = Set(VeoRules.validModeValues(channel: channel.rawValue, model: model).compactMap { VideoMode(rawValue: $0) })
            if !validModels.contains(model) {
                errors.append(.invalidConfig("Veo 不支持模型 \(model)，可用: \(validModels.sorted().joined(separator: ", "))"))
            }
            if !validModes.isEmpty, !validModes.contains(mode) {
                errors.append(.invalidConfig("Veo \(channel.rawValue)/\(model) 不支持 \(mode.rawValue) 模式"))
            }
        case .grok:
            if channel == .google || channel == .yunwu {
                errors.append(.invalidConfig("Grok 不支持 \(channel.rawValue) 渠道"))
            }
            if mode != .text {
                errors.append(.invalidConfig("Grok 工作流仅支持文生视频 (text) 模式"))
            }
            if ![VideoResolution.p720, .p480].contains(resolution) {
                errors.append(.invalidConfig("Grok 分辨率仅支持 720p / 480p"))
            }
            let longDurations: Set<String> = ["6", "8", "10", "12", "15", "20", "30"]
            let shortDurations: Set<String> = ["6", "10"]
            let allowedDurations = (channel == .budget || channel == .apimart) ? longDurations : shortDurations
            if !allowedDurations.contains(duration) {
                errors.append(.invalidConfig("Grok 当前渠道不支持 \(duration)s 时长"))
            }
        case .seedance:
            let seedanceModels = ["dreamina-seedance-2-0-260128", "dreamina-seedance-2-0-fast-260128"]
            if !seedanceModels.contains(model) {
                errors.append(.invalidConfig("Seedance 需要指定模型，如 dreamina-seedance-2-0-260128"))
            }
            if ![.reference, .firstLast].contains(mode) {
                errors.append(.invalidConfig("Seedance 仅支持 reference / first_last 模式"))
            }
            if ![AspectRatio.adaptive, .portrait, .landscape, .fourThree, .square, .threeFour, .twentyOneNine].contains(aspectRatio) {
                errors.append(.invalidConfig("Seedance 不支持当前画幅 \(aspectRatio.rawValue)"))
            }
            if ![VideoResolution.p480, .p720, .p1080].contains(resolution) {
                errors.append(.invalidConfig("Seedance 分辨率仅支持 480p / 720p / 1080p"))
            }
            if let durationValue = Int(duration) {
                if durationValue < 4 || durationValue > 15 {
                    errors.append(.invalidConfig("Seedance 时长需在 4-15 秒之间"))
                }
            } else {
                errors.append(.invalidConfig("Seedance 时长无效"))
            }
            if count < 1 || count > 4 {
                errors.append(.invalidConfig("Seedance 数量需在 1-4 之间"))
            }
        case .wan:
            errors.append(.invalidConfig("Wan 需要本地文件输入，暂不支持在工作流中使用"))
        }
        return errors
    }
}

struct ResultOutputNodeConfig: Codable, Equatable, Hashable {
    var label: String = "最终结果"

    func validate() -> [WorkflowValidationError] { [] }
}

// MARK: - Node Config (with stable Codable)

enum WorkflowNodeConfig: Equatable, Hashable {
    case textInput(TextInputNodeConfig)
    case promptTemplate(PromptTemplateNodeConfig)
    case imageGen(ImageGenNodeConfig)
    case videoGen(VideoGenNodeConfig)
    case resultOutput(ResultOutputNodeConfig)

    var nodeType: WorkflowNodeType {
        switch self {
        case .textInput: return .textInput
        case .promptTemplate: return .promptTemplate
        case .imageGen: return .imageGen
        case .videoGen: return .videoGen
        case .resultOutput: return .resultOutput
        }
    }

    func validate() -> [WorkflowValidationError] {
        switch self {
        case .textInput(let c): return c.validate()
        case .promptTemplate(let c): return c.validate()
        case .imageGen(let c): return c.validate()
        case .videoGen(let c): return c.validate()
        case .resultOutput(let c): return c.validate()
        }
    }

    /// Whether this input port is required to have an incoming connection
    /// given the current node configuration.
    func isRequiredInputPort(_ port: WorkflowPort) -> Bool {
        if port.portType == .any { return false }
        switch self {
        case .textInput: return false
        case .promptTemplate(let config):
            let referenced = WorkflowTemplateResolver.extractVariableNames(from: config.template)
            return referenced.contains(port.name)
        case .imageGen: return port.role == .prompt
        case .videoGen(let config):
            switch port.role {
            case .prompt: return config.mode == .text
            case .image:
                if config.mode == .image { return true }
                if config.mode == .reference { return config.genType != .seedance }
                return false
            case .firstFrame: return config.mode == .startEnd || config.mode == .firstLast
            case .lastFrame: return false
            default: return false
            }
        case .resultOutput: return false
        }
    }
}

// MARK: - WorkflowNodeConfig Codable (stable format)

extension WorkflowNodeConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case config
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeType.rawValue, forKey: .type)
        switch self {
        case .textInput(let c): try container.encode(c, forKey: .config)
        case .promptTemplate(let c): try container.encode(c, forKey: .config)
        case .imageGen(let c): try container.encode(c, forKey: .config)
        case .videoGen(let c): try container.encode(c, forKey: .config)
        case .resultOutput(let c): try container.encode(c, forKey: .config)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case WorkflowNodeType.textInput.rawValue:
            self = .textInput(try container.decode(TextInputNodeConfig.self, forKey: .config))
        case WorkflowNodeType.promptTemplate.rawValue:
            self = .promptTemplate(try container.decode(PromptTemplateNodeConfig.self, forKey: .config))
        case WorkflowNodeType.imageGen.rawValue:
            self = .imageGen(try container.decode(ImageGenNodeConfig.self, forKey: .config))
        case WorkflowNodeType.videoGen.rawValue:
            self = .videoGen(try container.decode(VideoGenNodeConfig.self, forKey: .config))
        case WorkflowNodeType.resultOutput.rawValue:
            self = .resultOutput(try container.decode(ResultOutputNodeConfig.self, forKey: .config))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown node type: \(type)"
            )
        }
    }
}

// MARK: - Node Type

enum WorkflowNodeType: String, Codable, CaseIterable {
    case textInput
    case promptTemplate
    case imageGen
    case videoGen
    case resultOutput

    var displayName: String {
        switch self {
        case .textInput: return "文本输入"
        case .promptTemplate: return "提示词模板"
        case .imageGen: return "图片生成"
        case .videoGen: return "视频生成"
        case .resultOutput: return "结果输出"
        }
    }

    var icon: String {
        switch self {
        case .textInput: return "text.cursor"
        case .promptTemplate: return "text.badge.plus"
        case .imageGen: return "photo.badge.plus"
        case .videoGen: return "video.badge.plus"
        case .resultOutput: return "arrow.down.to.line"
        }
    }
}

// MARK: - Node

struct WorkflowNode: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var position: WorkflowPoint
    var config: WorkflowNodeConfig
    var inputPorts: [WorkflowPort]
    var outputPorts: [WorkflowPort]

    var type: WorkflowNodeType { config.nodeType }

    init(
        id: String = UUID().uuidString,
        title: String,
        position: WorkflowPoint = .zero,
        config: WorkflowNodeConfig,
        inputPorts: [WorkflowPort]? = nil,
        outputPorts: [WorkflowPort]? = nil
    ) {
        let nodeId = id
        self.id = nodeId
        self.title = title
        self.position = position
        self.config = config
        self.inputPorts = (inputPorts ?? Self.defaultInputPorts(for: config, nodeId: nodeId))
            .map { $0.withNodeId(nodeId) }
        self.outputPorts = (outputPorts ?? Self.defaultOutputPorts(for: config, nodeId: nodeId))
            .map { $0.withNodeId(nodeId) }
    }

    private static func defaultInputPorts(for config: WorkflowNodeConfig, nodeId: String) -> [WorkflowPort] {
        switch config {
        case .textInput:
            return []
        case .promptTemplate:
            return [WorkflowPort(name: "文本", portType: .text, nodeId: nodeId, role: .styleVariable)]
        case .imageGen:
            return [WorkflowPort(name: "提示词", portType: .text, nodeId: nodeId, role: .prompt)]
        case .videoGen:
            return [
                WorkflowPort(name: "提示词", portType: .text, nodeId: nodeId, role: .prompt),
                WorkflowPort(name: "图片", portType: .image, nodeId: nodeId, role: .image),
                WorkflowPort(name: "首帧图片", portType: .image, nodeId: nodeId, role: .firstFrame),
                WorkflowPort(name: "尾帧图片", portType: .image, nodeId: nodeId, role: .lastFrame),
            ]
        case .resultOutput:
            return [WorkflowPort(name: "输入", portType: .any, nodeId: nodeId, role: .input)]
        }
    }

    private static func defaultOutputPorts(for config: WorkflowNodeConfig, nodeId: String) -> [WorkflowPort] {
        switch config {
        case .textInput:
            return [WorkflowPort(name: "文本", portType: .text, nodeId: nodeId, role: .text)]
        case .promptTemplate:
            return [WorkflowPort(name: "拼装文本", portType: .text, nodeId: nodeId, role: .text)]
        case .imageGen:
            return [WorkflowPort(name: "图片", portType: .image, nodeId: nodeId, role: .image)]
        case .videoGen:
            return [WorkflowPort(name: "视频", portType: .video, nodeId: nodeId, role: .video)]
        case .resultOutput:
            return []
        }
    }

    var configFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(config)
        return hasher.finalize()
    }

    var structuralFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine("inputs")
        hasher.combine(inputPorts.count)
        for port in inputPorts {
            hasher.combine(port.id)
            hasher.combine(port.portType)
        }
        hasher.combine("outputs")
        hasher.combine(outputPorts.count)
        for port in outputPorts {
            hasher.combine(port.id)
            hasher.combine(port.portType)
        }
        return hasher.finalize()
    }
}

// MARK: - Edge

struct WorkflowEdge: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var sourceNodeId: String
    var sourcePortId: String
    var targetNodeId: String
    var targetPortId: String
}

// MARK: - Workflow Definition

struct WorkflowDefinition: Identifiable, Codable, Equatable, Hashable {
    var schemaVersion: Int = 1
    var id: String = UUID().uuidString
    var name: String
    var nodes: [WorkflowNode] = []
    var edges: [WorkflowEdge] = []
    var createdAt: Date = .nowTruncatedToMilliseconds
    var updatedAt: Date = .nowTruncatedToMilliseconds

    /// Convenience helper: set of all node ids.
    var nodeIds: Set<String> { Set(nodes.map(\.id)) }

    /// Structural fingerprint for cache invalidation.
    /// Distinguishes input vs output ports, so swapping a port's direction
    /// (same port id, moved between inputPorts/outputPorts) correctly invalidates.
    var structuralFingerprint: Int {
        var hasher = Hasher()
        for node in nodes {
            hasher.combine(node.id)
            hasher.combine("inputs")
            hasher.combine(node.inputPorts.count)
            for port in node.inputPorts {
                hasher.combine(port.id)
                hasher.combine(port.nodeId)
                hasher.combine(port.portType)
            }
            hasher.combine("outputs")
            hasher.combine(node.outputPorts.count)
            for port in node.outputPorts {
                hasher.combine(port.id)
                hasher.combine(port.nodeId)
                hasher.combine(port.portType)
            }
        }
        for edge in edges {
            hasher.combine(edge.id)
            hasher.combine(edge.sourceNodeId)
            hasher.combine(edge.sourcePortId)
            hasher.combine(edge.targetNodeId)
            hasher.combine(edge.targetPortId)
        }
        return hasher.finalize()
    }

    /// Config fingerprint for cache invalidation.
    /// Changes when any node's config (prompt, model, mode, etc.) changes,
    /// even if the graph structure stays the same.
    var configFingerprint: Int {
        var hasher = Hasher()
        for node in nodes {
            hasher.combine(node.id)
            hasher.combine(node.title)
            hasher.combine(node.config)
        }
        return hasher.finalize()
    }

    var perNodeConfigFingerprints: [String: Int] {
        var result: [String: Int] = [:]
        for node in nodes {
            result[node.id] = node.configFingerprint
        }
        return result
    }

    var perNodeStructuralFingerprints: [String: Int] {
        var result: [String: Int] = [:]
        for node in nodes {
            var hasher = Hasher()
            hasher.combine(node.structuralFingerprint)
            let incoming = edges.filter { $0.targetNodeId == node.id }
            hasher.combine("incoming")
            hasher.combine(incoming.count)
            for edge in incoming {
                hasher.combine(edge.sourceNodeId)
                hasher.combine(edge.sourcePortId)
                hasher.combine(edge.targetPortId)
            }
            let outgoing = edges.filter { $0.sourceNodeId == node.id }
            hasher.combine("outgoing")
            hasher.combine(outgoing.count)
            for edge in outgoing {
                hasher.combine(edge.targetNodeId)
                hasher.combine(edge.sourcePortId)
                hasher.combine(edge.targetPortId)
            }
            result[node.id] = hasher.finalize()
        }
        return result
    }

    func downstreamNodeIds(of changedIds: Set<String>) -> Set<String> {
        var adjacency: [String: [String]] = [:]
        for edge in edges {
            adjacency[edge.sourceNodeId, default: []].append(edge.targetNodeId)
        }
        var visited = changedIds
        var result = Set<String>()
        var index = 0
        var queue = Array(changedIds)
        while index < queue.count {
            let node = queue[index]
            index += 1
            for neighbor in adjacency[node] ?? [] {
                if visited.insert(neighbor).inserted {
                    result.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }
        return result
    }
}

// MARK: - Node Status

enum WorkflowNodeStatus: String, Codable, CaseIterable {
    case pending
    case running
    case succeeded
    case failed
    case skipped
    case cancelled

    var displayName: String {
        switch self {
        case .pending: return "等待中"
        case .running: return "执行中"
        case .succeeded: return "已完成"
        case .failed: return "失败"
        case .skipped: return "已复用"
        case .cancelled: return "已取消"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .running: return "circle.dotted"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "forward.circle"
        case .cancelled: return "stop.circle.fill"
        }
    }

    var isSuccessLike: Bool {
        self == .succeeded || self == .skipped
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .red
        case .skipped: return .orange
        case .cancelled: return .secondary
        }
    }
}

// MARK: - Node Run State

struct WorkflowNodeRunState: Codable, Equatable, Hashable {
    var nodeId: String
    var status: WorkflowNodeStatus = .pending
    var errorMessage: String?
    var startedAt: Date?
    var completedAt: Date?
    var outputSummary: String?
}

// MARK: - Workflow Run

struct WorkflowRun: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var workflowId: String
    var nodeStates: [String: WorkflowNodeRunState] = [:]
    var overallStatus: WorkflowNodeStatus = .pending
    var startedAt: Date?
    var completedAt: Date?
}

// MARK: - Workflow Value Types

struct WorkflowImage: Codable, Equatable, Hashable {
    var localFile: FileRef?
    var remoteURL: String?

    var isValid: Bool {
        localFile != nil || remoteURL != nil
    }
}

struct WorkflowVideo: Codable, Equatable, Hashable {
    var remoteURL: String

    var isValid: Bool {
        !remoteURL.isEmpty
    }
}

enum WorkflowValue: Equatable, Codable {
    case none
    case text(String)
    case image(WorkflowImage)
    case images([WorkflowImage])
    case video(WorkflowVideo)
    case file(FileRef)
    case json(Data)

    var summary: String {
        switch self {
        case .none: return "无"
        case .text(let t): return String(t.prefix(50))
        case .image(let img):
            if let f = img.localFile { return "图片 (\(ByteCountFormatter.string(fromByteCount: Int64(f.data.count), countStyle: .file)))" }
            if let url = img.remoteURL { return "图片: \(String(url.prefix(50)))" }
            return "图片（无数据）"
        case .images(let imgs):
            return imgs.isEmpty ? "无图片" : "\(imgs.count) 张图片"
        case .video(let v):
            return "视频: \(String(v.remoteURL.prefix(50)))"
        case .file(let f):
            return "文件: \(f.name) (\(ByteCountFormatter.string(fromByteCount: Int64(f.data.count), countStyle: .file)))"
        case .json(let d):
            return "JSON (\(ByteCountFormatter.string(fromByteCount: Int64(d.count), countStyle: .file)))"
        }
    }

    /// Safe summary that strips URL query/fragment to avoid leaking signed tokens.
    var safeSummary: String {
        switch self {
        case .image(let img):
            if let f = img.localFile { return "图片 (\(ByteCountFormatter.string(fromByteCount: Int64(f.data.count), countStyle: .file)))" }
            if let url = img.remoteURL { return "图片: \(Self.stripURLSecrets(url))" }
            return "图片（无数据）"
        case .images(let imgs):
            return imgs.isEmpty ? "无图片" : "\(imgs.count) 张图片"
        case .video(let v):
            return "视频: \(Self.stripURLSecrets(v.remoteURL))"
        default:
            return summary
        }
    }

    /// Strip query and fragment from a URL string to avoid leaking signed tokens.
    nonisolated static func stripURLSecrets(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        components.query = nil
        components.fragment = nil
        return components.string ?? urlString
    }

    var textValue: String? {
        if case .text(let t) = self { return t }
        return nil
    }

    var imageValue: WorkflowImage? {
        if case .image(let img) = self { return img }
        return nil
    }

    var imageValues: [WorkflowImage]? {
        if case .images(let imgs) = self { return imgs }
        if case .image(let img) = self { return [img] }
        return nil
    }

    /// First remote image URL from `.image` or `.images`, for Veo/Grok image-to-video.
    var firstRemoteImageURL: String? {
        if case .image(let img) = self { return img.remoteURL }
        if case .images(let imgs) = self { return imgs.first?.remoteURL }
        return nil
    }

    var videoValue: WorkflowVideo? {
        if case .video(let v) = self { return v }
        return nil
    }

    var portType: WorkflowPortType {
        switch self {
        case .none: return .any
        case .text: return .text
        case .image: return .image
        case .images: return .image
        case .video: return .video
        case .file: return .file
        case .json: return .json
        }
    }
}

// MARK: - Workflow Run Context

enum WorkflowRunContextError: Error, LocalizedError, Equatable {
    case typeMismatch(edgeId: String, expected: WorkflowPortType, actual: WorkflowValue)
    case noUpstreamValue(nodeId: String, portId: String)
    case missingNode(nodeId: String)
    case missingSourcePort(portId: String)
    case sourcePortNotOutput(portId: String)
    case wrongTargetNode(portId: String, expectedNodeId: String)
    case targetPortNotInput(portId: String)
    case multipleSources(portId: String, edgeIds: [String])

    var errorDescription: String? {
        switch self {
        case .typeMismatch(let edgeId, let expected, let actual):
            return "连线 \(edgeId) 类型不兼容: 预期 \(expected.displayName)，实际收到 \(actual.portType.displayName)"
        case .noUpstreamValue(let nodeId, let portId):
            return "节点 \(nodeId) 的端口 \(portId) 缺少上游输入值"
        case .missingNode(let nodeId):
            return "运行时找不到节点: \(nodeId)"
        case .missingSourcePort(let portId):
            return "连线引用了不存在的源端口: \(portId)"
        case .sourcePortNotOutput(let portId):
            return "连线源端口不是输出端口: \(portId)"
        case .wrongTargetNode(let portId, let expectedNodeId):
            return "端口 \(portId) 不属于节点 \(expectedNodeId)"
        case .targetPortNotInput(let portId):
            return "端口 \(portId) 不是输入端口"
        case .multipleSources(let portId, let edgeIds):
            return "输入端口 \(portId) 有多个来源连线: \(edgeIds.joined(separator: ", "))"
        }
    }
}

final class WorkflowRunContext {
    private var outputs: [String: [String: WorkflowValue]] = [:]
    private var logMessages: [(String, String)] = []

    // Cached indexes per definition (structural fingerprint, not just id)
    private var cachedFingerprint: Int?
    private var nodeMap: [String: WorkflowNode] = [:]
    private var portOwnerMap: [String: (nodeId: String, isInput: Bool)] = [:]
    private var edgeByTargetMap: [String: [WorkflowEdge]] = [:]

    private func ensureIndexes(from def: WorkflowDefinition) {
        let fp = def.structuralFingerprint
        guard fp != cachedFingerprint else { return }
        cachedFingerprint = fp
        nodeMap = [:]
        portOwnerMap = [:]
        edgeByTargetMap = [:]

        for node in def.nodes {
            nodeMap[node.id] = node
            for port in node.inputPorts {
                portOwnerMap[port.id] = (node.id, true)
            }
            for port in node.outputPorts {
                portOwnerMap[port.id] = (node.id, false)
            }
        }
        for edge in def.edges {
            edgeByTargetMap[edge.targetPortId, default: []].append(edge)
        }
    }

    // MARK: Output

    func setOutput(nodeId: String, portId: String, value: WorkflowValue) {
        outputs[nodeId, default: [:]][portId] = value
        logMessages.append((nodeId, "输出 \(portId): \(value.safeSummary)"))
    }

    func output(nodeId: String, portId: String) -> WorkflowValue? {
        outputs[nodeId]?[portId]
    }

    // MARK: Inputs (resolved from DAG edges)

    func inputValue(for targetPort: WorkflowPort, in definition: WorkflowDefinition) throws -> WorkflowValue? {
        ensureIndexes(from: definition)

        let targetNodeId = targetPort.nodeId
        guard let owner = portOwnerMap[targetPort.id] else {
            throw WorkflowRunContextError.missingSourcePort(portId: targetPort.id)
        }
        guard owner.nodeId == targetNodeId else {
            throw WorkflowRunContextError.wrongTargetNode(portId: targetPort.id, expectedNodeId: targetNodeId)
        }
        guard owner.isInput else {
            throw WorkflowRunContextError.targetPortNotInput(portId: targetPort.id)
        }

        guard let edges = edgeByTargetMap[targetPort.id], !edges.isEmpty else {
            return nil
        }
        guard edges.count == 1 else {
            throw WorkflowRunContextError.multipleSources(portId: targetPort.id, edgeIds: edges.map(\.id))
        }

        let edge = edges[0]
        guard nodeMap[edge.sourceNodeId] != nil else {
            throw WorkflowRunContextError.missingNode(nodeId: edge.sourceNodeId)
        }
        guard let srcOwner = portOwnerMap[edge.sourcePortId] else {
            throw WorkflowRunContextError.missingSourcePort(portId: edge.sourcePortId)
        }
        guard !srcOwner.isInput else {
            throw WorkflowRunContextError.sourcePortNotOutput(portId: edge.sourcePortId)
        }

        guard let value = outputs[edge.sourceNodeId]?[edge.sourcePortId] else {
            throw WorkflowRunContextError.noUpstreamValue(nodeId: edge.sourceNodeId, portId: edge.sourcePortId)
        }
        if targetPort.portType != .any, value.portType != targetPort.portType {
            throw WorkflowRunContextError.typeMismatch(edgeId: edge.id, expected: targetPort.portType, actual: value)
        }
        return value
    }

    func inputValues(for node: WorkflowNode, in definition: WorkflowDefinition) throws -> [String: WorkflowValue] {
        var result: [String: WorkflowValue] = [:]
        for port in node.inputPorts {
            result[port.id] = try inputValue(for: port, in: definition)
        }
        return result
    }

    // MARK: Logs

    var logLines: [(nodeId: String, message: String)] { logMessages }

    func logTail(count: Int = 10) -> [String] {
        logMessages.suffix(count).map { "[\($0.0)] \($0.1)" }
    }
}

// MARK: - Template Resolver

enum WorkflowTemplateResolver {
    /// Resolve template variables like ``{{portName}}`` using the given input map.
    /// The input map keys are port names (e.g. "文本", "图片"), matching ``WorkflowPort.name``.
    /// Returns the resolved string. Unresolved ``{{key}}`` patterns are left in place silently.
    static func resolve(_ template: String, with inputs: [String: WorkflowValue]) -> String {
        let result = resolveReporting(template, with: inputs)
        return result.resolved
    }

    /// Resolve template variables and report which keys remain unresolved.
    static func resolveReporting(_ template: String, with inputs: [String: WorkflowValue]) -> (resolved: String, unresolved: [String]) {
        var result = template
        var unresolved: [String] = []

        let pattern = try! NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}")
        let nsRange = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = pattern.matches(in: template, range: nsRange)

        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: template) else { continue }
            let key = String(template[keyRange])
            if let value = inputs[key] {
                let replacement = Self.stringValue(for: value)
                if let matchRange = Range(match.range, in: result) {
                    result.replaceSubrange(matchRange, with: replacement)
                }
            } else {
                unresolved.append(key)
            }
        }

        return (result, unresolved)
    }

    /// Extract variable names referenced in a template string (e.g. ``"{{提示词}}"`` → ``"提示词"``).
    static func extractVariableNames(from template: String) -> Set<String> {
        let pattern = try! NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}")
        let nsRange = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = pattern.matches(in: template, range: nsRange)
        var names = Set<String>()
        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: template) else { continue }
            names.insert(String(template[keyRange]))
        }
        return names
    }

    /// Build input variable map from a node's input port names and resolved values.
    /// Keys are ``WorkflowPort.name`` (e.g. "提示词", "图片").
    static func variableMap(from inputs: [String: WorkflowValue], ports: [WorkflowPort]) -> [String: WorkflowValue] {
        var map: [String: WorkflowValue] = [:]
        for port in ports {
            if let value = inputs[port.id] {
                map[port.name] = value
            }
        }
        return map
    }

    private static func stringValue(for value: WorkflowValue) -> String {
        switch value {
        case .text(let t): return t
        case .image(let img): return img.remoteURL ?? img.localFile?.name ?? "[图片]"
        case .video(let v): return v.remoteURL
        case .file(let f): return f.name
        case .json(let d): return String(data: d, encoding: .utf8) ?? "[JSON]"
        case .none: return ""
        case .images(let imgs): return imgs.compactMap { $0.remoteURL ?? $0.localFile?.name }.joined(separator: ", ")
        }
    }
}

// MARK: - Validation Errors


enum WorkflowValidationError: Error, LocalizedError, Equatable {
    case duplicateNodeId(String)
    case duplicatePortId(String)
    case portNodeIdMismatch(portId: String, expectedNodeId: String, actualNodeId: String)
    case missingNode(nodeId: String)
    case missingPort(portId: String)
    case sourcePortNotOutput(portId: String)
    case targetPortNotInput(portId: String)
    case portTypeMismatch(edgeId: String, sourceType: WorkflowPortType, targetType: WorkflowPortType)
    case cycleDetected(nodeIds: [String])
    case multipleSourcesForInputPort(portId: String, sourceEdgeIds: [String])
    case missingInputSource(portId: String, nodeId: String, nodeTitle: String, portName: String, expectedType: WorkflowPortType)
    case missingAnyRequiredInput(nodeId: String, nodeTitle: String, portNames: [String])
    case invalidConfig(String)

    /// The node ID associated with this error, if any.
    var affectedNodeId: String? {
        switch self {
        case .duplicateNodeId(let id): return id
        case .portNodeIdMismatch(_, let expectedNodeId, _): return expectedNodeId
        case .missingNode(let nodeId): return nodeId
        case .sourcePortNotOutput, .targetPortNotInput, .missingPort, .duplicatePortId: return nil
        case .portTypeMismatch: return nil
        case .cycleDetected(let nodeIds): return nodeIds.first
        case .multipleSourcesForInputPort: return nil
        case .missingInputSource(_, let nodeId, _, _, _): return nodeId
        case .missingAnyRequiredInput(let nodeId, _, _): return nodeId
        case .invalidConfig: return nil
        }
    }

    /// The port ID associated with this error, if any.
    var affectedPortId: String? {
        switch self {
        case .duplicatePortId(let id): return id
        case .portNodeIdMismatch(let portId, _, _): return portId
        case .missingPort(let portId): return portId
        case .sourcePortNotOutput(let portId): return portId
        case .targetPortNotInput(let portId): return portId
        case .multipleSourcesForInputPort(let portId, _): return portId
        case .missingInputSource(let portId, _, _, _, _): return portId
        case .missingAnyRequiredInput: return nil
        default: return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .duplicateNodeId(let id):
            return "重复的节点 ID: \(id)"
        case .duplicatePortId(let id):
            return "重复的端口 ID: \(id)"
        case .portNodeIdMismatch(let portId, let expected, let actual):
            return "端口 \(portId) 的 nodeId 为 \(actual)，预期属于节点 \(expected)"
        case .missingNode(let id):
            return "连线引用了不存在的节点: \(id)"
        case .missingPort(let id):
            return "连线引用了不存在的端口: \(id)"
        case .sourcePortNotOutput(let id):
            return "连线源端口 \(id) 不是输出端口"
        case .targetPortNotInput(let id):
            return "连线目标端口 \(id) 不是输入端口"
        case .portTypeMismatch(let edgeId, let src, let tgt):
            return "连线 \(edgeId) 端口类型不兼容: \(src.displayName) -> \(tgt.displayName)"
        case .cycleDetected(let ids):
            return "工作流包含环，涉及节点: \(ids.joined(separator: ", "))"
        case .multipleSourcesForInputPort(let portId, let edgeIds):
            return "输入端口 \(portId) 有多个来源连线: \(edgeIds.joined(separator: ", "))"
        case .missingInputSource(_, _, let nodeTitle, let portName, let expectedType):
            return "\"\(nodeTitle)\" 的端口 \"\(portName)\" 缺少 \(expectedType.displayName) 类型输入"
        case .missingAnyRequiredInput(_, let nodeTitle, let portNames):
            return "\"\(nodeTitle)\" 需要至少有一个输入：\(portNames.joined(separator: " 或 "))"
        case .invalidConfig(let msg):
            return "配置无效: \(msg)"
        }
    }
}

// MARK: - DAG Validation

extension WorkflowDefinition {

    /// Validate the structural integrity of the workflow DAG.
    /// Checks: node/port uniqueness, port ownership, edge endpoints, port direction,
    /// type compatibility, single-source input ports, mode-aware missing input sources, and cycle-free.
    func validate() -> [WorkflowValidationError] {
        var errors: [WorkflowValidationError] = []

        var nodeMap: [String: WorkflowNode] = [:]
        for node in nodes {
            if nodeMap[node.id] != nil {
                errors.append(.duplicateNodeId(node.id))
            } else {
                nodeMap[node.id] = node
            }
        }
        var allPortIds = Set<String>()
        var portNodeMap: [String: String] = [:]
        var inputPortSources: [String: [String]] = [:]

        // ── Port uniqueness & ownership ──
        for node in nodes {
            for port in node.inputPorts + node.outputPorts {
                if allPortIds.contains(port.id) {
                    errors.append(.duplicatePortId(port.id))
                } else {
                    allPortIds.insert(port.id)
                    portNodeMap[port.id] = node.id
                }
                if port.nodeId != node.id {
                    errors.append(.portNodeIdMismatch(
                        portId: port.id, expectedNodeId: node.id, actualNodeId: port.nodeId
                    ))
                }
            }
        }

        // ── Edge validation ──
        for edge in edges {
            guard let sourceNode = nodeMap[edge.sourceNodeId] else {
                errors.append(.missingNode(nodeId: edge.sourceNodeId))
                continue
            }
            guard let targetNode = nodeMap[edge.targetNodeId] else {
                errors.append(.missingNode(nodeId: edge.targetNodeId))
                continue
            }
            guard let sourcePort = sourceNode.outputPorts.first(where: { $0.id == edge.sourcePortId }) else {
                if sourceNode.inputPorts.contains(where: { $0.id == edge.sourcePortId }) {
                    errors.append(.sourcePortNotOutput(portId: edge.sourcePortId))
                } else {
                    errors.append(.missingPort(portId: edge.sourcePortId))
                }
                continue
            }
            guard let targetPort = targetNode.inputPorts.first(where: { $0.id == edge.targetPortId }) else {
                if targetNode.outputPorts.contains(where: { $0.id == edge.targetPortId }) {
                    errors.append(.targetPortNotInput(portId: edge.targetPortId))
                } else {
                    errors.append(.missingPort(portId: edge.targetPortId))
                }
                continue
            }
            if targetPort.portType != .any && sourcePort.portType != .any
                && sourcePort.portType != targetPort.portType {
                errors.append(.portTypeMismatch(
                    edgeId: edge.id, sourceType: sourcePort.portType, targetType: targetPort.portType
                ))
            }
            inputPortSources[edge.targetPortId, default: []].append(edge.id)
        }

        // ── Multiple sources for single input ──
        for (portId, edgeIds) in inputPortSources where edgeIds.count > 1 {
            errors.append(.multipleSourcesForInputPort(portId: portId, sourceEdgeIds: edgeIds))
        }

        // ── Missing input sources (per required port, mode-aware) ──
        for node in nodes {
            for port in node.inputPorts where node.config.isRequiredInputPort(port) {
                let sources = inputPortSources[port.id] ?? []
                if sources.isEmpty {
                    errors.append(.missingInputSource(
                        portId: port.id, nodeId: node.id, nodeTitle: node.title,
                        portName: port.name, expectedType: port.portType
                    ))
                }
            }
        }

        // ── Node-level OR constraints ──
        for node in nodes {
            if case .videoGen(let config) = node.config,
               config.genType == .seedance, config.mode == .reference {
                let promptPort = node.inputPorts.first(where: { $0.role == .prompt })
                let imagePort = node.inputPorts.first(where: { $0.role == .image })
                let hasPrompt = promptPort.flatMap { inputPortSources[$0.id] }?.isEmpty == false
                let hasImage = imagePort.flatMap { inputPortSources[$0.id] }?.isEmpty == false
                if !hasPrompt && !hasImage {
                    let names = [promptPort?.name, imagePort?.name].compactMap { $0 }
                    errors.append(.missingAnyRequiredInput(
                        nodeId: node.id, nodeTitle: node.title, portNames: names
                    ))
                }
            }
        }

        // ── Cycle detection (only if structure is otherwise valid) ──
        if errors.isEmpty {
            do {
                _ = try topologicalNodeIds()
            } catch let error as WorkflowValidationError {
                errors.append(error)
            } catch { }
        }

        return errors
    }

    /// Validate config fields for every node.
    func validateConfigs() -> [WorkflowValidationError] {
        var errors = nodes.flatMap { $0.config.validate() }
        // Additional DAG-specific config validation
        for node in nodes {
            if case .videoGen(let config) = node.config {
                if config.genType == .wan {
                    errors.append(.invalidConfig("Wan 视频需要本地文件输入，暂不支持在画布中使用"))
                }
            }
        }
        return errors
    }

    /// Run full validation (structure + configs).
    func fullValidate() -> [WorkflowValidationError] {
        validate() + validateConfigs()
    }

    /// Return node ids in topological order (Kahn's algorithm).
    /// Throws `.cycleDetected` if a cycle exists.
    func topologicalNodeIds() throws -> [String] {
        var inDegree: [String: Int] = [:]
        var adjacency: [String: [String]] = [:]

        for node in nodes {
            inDegree[node.id] = 0
            adjacency[node.id] = []
        }
        for edge in edges {
            adjacency[edge.sourceNodeId, default: []].append(edge.targetNodeId)
            inDegree[edge.targetNodeId, default: 0] += 1
        }

        var queue = inDegree.filter { $0.value == 0 }.map(\.key)
        var result: [String] = []
        while !queue.isEmpty {
            let nodeId = queue.removeFirst()
            result.append(nodeId)
            for neighbor in adjacency[nodeId] ?? [] {
                inDegree[neighbor]! -= 1
                if inDegree[neighbor]! == 0 {
                    queue.append(neighbor)
                }
            }
        }

        if result.count != nodes.count {
            let remaining = inDegree.filter { $0.value > 0 }.keys
            throw WorkflowValidationError.cycleDetected(nodeIds: Array(remaining))
        }
        return result
    }
}

// MARK: - JSON Helpers

extension WorkflowDefinition {

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            let ms = Int64((date.timeIntervalSinceReferenceDate * 1000).rounded())
            try c.encode(ms)
        }
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> WorkflowDefinition {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let ms = try c.decode(Int64.self)
            return Date(timeIntervalSinceReferenceDate: Double(ms) / 1000)
        }
        return try decoder.decode(WorkflowDefinition.self, from: data)
    }
}

// MARK: - Workflow Template

struct WorkflowTemplate: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let nodeCount: Int
    let outputType: String
    let makeDefinition: @Sendable () -> WorkflowDefinition
}

// MARK: - Built-in Templates

extension WorkflowDefinition {

    /// 验收样例：文本输入 → 图片生成 → 视频生成（图生视频模式）
    static func sample() -> WorkflowDefinition {
        templates[0].makeDefinition()
    }

    /// 内置模板列表
    static let templates: [WorkflowTemplate] = [
        textToImageToVideo,
        promptToImageToVideo,
        referenceToVideo,
        startEndFrameToVideo,
    ]

    // MARK: - 模板 1：文生图 → 图生视频

    static let textToImageToVideo = WorkflowTemplate(
        id: "text-to-image-to-video",
        name: "文生图转视频",
        description: "输入文字描述 → 生成图片 → 图片生成视频",
        icon: "photo.on.rectangle.angled",
        nodeCount: 4,
        outputType: "视频",
        makeDefinition: {
            let textNode = WorkflowNode(
                title: "文本输入",
                config: .textInput(TextInputNodeConfig(text: "一只在月光下奔跑的狐狸"))
            )
            let imageNode = WorkflowNode(
                title: "图片生成",
                position: WorkflowPoint(x: 300, y: 0),
                config: .imageGen(ImageGenNodeConfig())
            )
            var videoCfg = VideoGenNodeConfig()
            videoCfg.mode = .image
            let videoNode = WorkflowNode(
                title: "视频生成",
                position: WorkflowPoint(x: 600, y: 0),
                config: .videoGen(videoCfg)
            )
            let resultNode = WorkflowNode(
                title: "结果",
                position: WorkflowPoint(x: 900, y: 0),
                config: .resultOutput(ResultOutputNodeConfig(label: "最终视频"))
            )

            let textOutput = textNode.outputPorts.first(where: { $0.role == .text })!
            let imagePromptInput = imageNode.inputPorts.first(where: { $0.role == .prompt })!
            let imageOutput = imageNode.outputPorts.first(where: { $0.role == .image })!
            let videoImageInput = videoNode.inputPorts.first(where: { $0.role == .image })!
            let videoOutput = videoNode.outputPorts.first(where: { $0.role == .video })!
            let resultInput = resultNode.inputPorts.first(where: { $0.role == .input })!

            return WorkflowDefinition(
                name: "文生图转视频",
                nodes: [textNode, imageNode, videoNode, resultNode],
                edges: [
                    WorkflowEdge(sourceNodeId: textNode.id, sourcePortId: textOutput.id,
                                 targetNodeId: imageNode.id, targetPortId: imagePromptInput.id),
                    WorkflowEdge(sourceNodeId: imageNode.id, sourcePortId: imageOutput.id,
                                 targetNodeId: videoNode.id, targetPortId: videoImageInput.id),
                    WorkflowEdge(sourceNodeId: videoNode.id, sourcePortId: videoOutput.id,
                                 targetNodeId: resultNode.id, targetPortId: resultInput.id),
                ]
            )
        }
    )

    // MARK: - 模板 2：提示词 → 图片 → 视频

    static let promptToImageToVideo = WorkflowTemplate(
        id: "prompt-to-image-to-video",
        name: "提示词转图片转视频",
        description: "用模板拼装提示词 → 批量生成图片 → 逐个生成视频",
        icon: "text.badge.plus",
        nodeCount: 5,
        outputType: "视频",
        makeDefinition: {
            let promptNode = WorkflowNode(
                title: "提示词模板",
                position: WorkflowPoint(x: 0, y: 0),
                config: .promptTemplate(PromptTemplateNodeConfig(
                    template: "一只可爱的猫咪，{{风格}}，高清细节"
                )),
                inputPorts: [WorkflowPort(name: "风格", portType: .text, nodeId: "", role: .styleVariable)]
            )
            let styleNode = WorkflowNode(
                title: "风格输入",
                position: WorkflowPoint(x: -300, y: 0),
                config: .textInput(TextInputNodeConfig(text: "赛博朋克风格"))
            )
            let imageNode = WorkflowNode(
                title: "图片生成",
                position: WorkflowPoint(x: 300, y: 0),
                config: .imageGen(ImageGenNodeConfig())
            )
            var videoCfg = VideoGenNodeConfig()
            videoCfg.mode = .image
            let videoNode = WorkflowNode(
                title: "视频生成",
                position: WorkflowPoint(x: 600, y: 0),
                config: .videoGen(videoCfg)
            )
            let resultNode = WorkflowNode(
                title: "结果",
                position: WorkflowPoint(x: 900, y: 0),
                config: .resultOutput(ResultOutputNodeConfig(label: "最终视频"))
            )

            let styleOutput = styleNode.outputPorts.first(where: { $0.role == .text })!
            let promptVarInput = promptNode.inputPorts.first(where: { $0.role == .styleVariable })!
            let promptOutput = promptNode.outputPorts.first(where: { $0.role == .text })!
            let imagePromptInput = imageNode.inputPorts.first(where: { $0.role == .prompt })!
            let imageOutput = imageNode.outputPorts.first(where: { $0.role == .image })!
            let videoImageInput = videoNode.inputPorts.first(where: { $0.role == .image })!
            let videoOutput = videoNode.outputPorts.first(where: { $0.role == .video })!
            let resultInput = resultNode.inputPorts.first(where: { $0.role == .input })!

            return WorkflowDefinition(
                name: "提示词转图片转视频",
                nodes: [styleNode, promptNode, imageNode, videoNode, resultNode],
                edges: [
                    WorkflowEdge(sourceNodeId: styleNode.id, sourcePortId: styleOutput.id,
                                 targetNodeId: promptNode.id, targetPortId: promptVarInput.id),
                    WorkflowEdge(sourceNodeId: promptNode.id, sourcePortId: promptOutput.id,
                                 targetNodeId: imageNode.id, targetPortId: imagePromptInput.id),
                    WorkflowEdge(sourceNodeId: imageNode.id, sourcePortId: imageOutput.id,
                                 targetNodeId: videoNode.id, targetPortId: videoImageInput.id),
                    WorkflowEdge(sourceNodeId: videoNode.id, sourcePortId: videoOutput.id,
                                 targetNodeId: resultNode.id, targetPortId: resultInput.id),
                ]
            )
        }
    )

    // MARK: - 模板 3：参考图 → Veo 视频

    static let referenceToVideo = WorkflowTemplate(
        id: "reference-to-video",
        name: "参考图转视频",
        description: "生成参考图片 → Veo 生成相似风格视频",
        icon: "photo.badge.arrow.down",
        nodeCount: 5,
        outputType: "视频",
        makeDefinition: {
            let refPromptNode = WorkflowNode(
                title: "参考图描述",
                position: WorkflowPoint(x: 0, y: -60),
                config: .textInput(TextInputNodeConfig(text: "一幅油画风格的日落风景"))
            )
            let refImageNode = WorkflowNode(
                title: "参考图生成",
                position: WorkflowPoint(x: 0, y: 80),
                config: .imageGen(ImageGenNodeConfig())
            )
            let videoPromptNode = WorkflowNode(
                title: "视频描述",
                position: WorkflowPoint(x: 300, y: -60),
                config: .textInput(TextInputNodeConfig(text: "参考这张图的风格，生成一段日落延时摄影视频"))
            )
            var videoCfg = VideoGenNodeConfig()
            videoCfg.genType = .veo
            videoCfg.channel = .official
            videoCfg.model = "pro"
            videoCfg.mode = .reference
            let videoNode = WorkflowNode(
                title: "Veo 参考生视频",
                position: WorkflowPoint(x: 300, y: 80),
                config: .videoGen(videoCfg)
            )
            let resultNode = WorkflowNode(
                title: "结果",
                position: WorkflowPoint(x: 600, y: 80),
                config: .resultOutput(ResultOutputNodeConfig(label: "生成视频"))
            )

            let refPromptOutput = refPromptNode.outputPorts.first(where: { $0.role == .text })!
            let refImagePromptInput = refImageNode.inputPorts.first(where: { $0.role == .prompt })!
            let refImageOutput = refImageNode.outputPorts.first(where: { $0.role == .image })!
            let videoPromptOutput = videoPromptNode.outputPorts.first(where: { $0.role == .text })!
            let videoTextInput = videoNode.inputPorts.first(where: { $0.role == .prompt })!
            let videoImageInput = videoNode.inputPorts.first(where: { $0.role == .image })!
            let videoOutput = videoNode.outputPorts.first(where: { $0.role == .video })!
            let resultInput = resultNode.inputPorts.first(where: { $0.role == .input })!

            return WorkflowDefinition(
                name: "参考图转视频",
                nodes: [refPromptNode, refImageNode, videoPromptNode, videoNode, resultNode],
                edges: [
                    WorkflowEdge(sourceNodeId: refPromptNode.id, sourcePortId: refPromptOutput.id,
                                 targetNodeId: refImageNode.id, targetPortId: refImagePromptInput.id),
                    WorkflowEdge(sourceNodeId: refImageNode.id, sourcePortId: refImageOutput.id,
                                 targetNodeId: videoNode.id, targetPortId: videoImageInput.id),
                    WorkflowEdge(sourceNodeId: videoPromptNode.id, sourcePortId: videoPromptOutput.id,
                                 targetNodeId: videoNode.id, targetPortId: videoTextInput.id),
                    WorkflowEdge(sourceNodeId: videoNode.id, sourcePortId: videoOutput.id,
                                 targetNodeId: resultNode.id, targetPortId: resultInput.id),
                ]
            )
        }
    )

    // MARK: - 模板 4：首尾帧 → Veo 视频

    static let startEndFrameToVideo = WorkflowTemplate(
        id: "start-end-frame-to-video",
        name: "首尾帧转视频",
        description: "生成首帧和尾帧图片 → Veo 生成过渡视频",
        icon: "rectangle.split.3x1",
        nodeCount: 7,
        outputType: "视频",
        makeDefinition: {
            let promptNode = WorkflowNode(
                title: "视频描述",
                position: WorkflowPoint(x: 0, y: -60),
                config: .textInput(TextInputNodeConfig(text: "从白天到黑夜的城市延时摄影"))
            )
            let firstPromptNode = WorkflowNode(
                title: "首帧描述",
                position: WorkflowPoint(x: -200, y: 80),
                config: .textInput(TextInputNodeConfig(text: "白天的城市鸟瞰图，阳光明媚"))
            )
            let firstFrameNode = WorkflowNode(
                title: "首帧图片",
                position: WorkflowPoint(x: 100, y: 80),
                config: .imageGen(ImageGenNodeConfig())
            )
            let lastPromptNode = WorkflowNode(
                title: "尾帧描述",
                position: WorkflowPoint(x: -200, y: 220),
                config: .textInput(TextInputNodeConfig(text: "夜晚的城市鸟瞰图，灯火辉煌"))
            )
            let lastFrameNode = WorkflowNode(
                title: "尾帧图片",
                position: WorkflowPoint(x: 100, y: 220),
                config: .imageGen(ImageGenNodeConfig())
            )
            var videoCfg = VideoGenNodeConfig()
            videoCfg.genType = .veo
            videoCfg.channel = .official
            videoCfg.model = "fast"
            videoCfg.mode = .startEnd
            let videoNode = WorkflowNode(
                title: "Veo 首尾帧视频",
                position: WorkflowPoint(x: 450, y: 80),
                config: .videoGen(videoCfg)
            )
            let resultNode = WorkflowNode(
                title: "结果",
                position: WorkflowPoint(x: 780, y: 80),
                config: .resultOutput(ResultOutputNodeConfig(label: "过渡视频"))
            )

            let promptOutput = promptNode.outputPorts.first(where: { $0.role == .text })!
            let firstPromptOutput = firstPromptNode.outputPorts.first(where: { $0.role == .text })!
            let firstImagePromptInput = firstFrameNode.inputPorts.first(where: { $0.role == .prompt })!
            let firstImageOutput = firstFrameNode.outputPorts.first(where: { $0.role == .image })!
            let lastPromptOutput = lastPromptNode.outputPorts.first(where: { $0.role == .text })!
            let lastImagePromptInput = lastFrameNode.inputPorts.first(where: { $0.role == .prompt })!
            let lastImageOutput = lastFrameNode.outputPorts.first(where: { $0.role == .image })!
            let videoTextInput = videoNode.inputPorts.first(where: { $0.role == .prompt })!
            let videoFirstInput = videoNode.inputPorts.first(where: { $0.role == .firstFrame })!
            let videoLastInput = videoNode.inputPorts.first(where: { $0.role == .lastFrame })!
            let videoOutput = videoNode.outputPorts.first(where: { $0.role == .video })!
            let resultInput = resultNode.inputPorts.first(where: { $0.role == .input })!

            return WorkflowDefinition(
                name: "首尾帧转视频",
                nodes: [promptNode, firstPromptNode, firstFrameNode, lastPromptNode, lastFrameNode, videoNode, resultNode],
                edges: [
                    WorkflowEdge(sourceNodeId: promptNode.id, sourcePortId: promptOutput.id,
                                 targetNodeId: videoNode.id, targetPortId: videoTextInput.id),
                    WorkflowEdge(sourceNodeId: firstPromptNode.id, sourcePortId: firstPromptOutput.id,
                                 targetNodeId: firstFrameNode.id, targetPortId: firstImagePromptInput.id),
                    WorkflowEdge(sourceNodeId: firstFrameNode.id, sourcePortId: firstImageOutput.id,
                                 targetNodeId: videoNode.id, targetPortId: videoFirstInput.id),
                    WorkflowEdge(sourceNodeId: lastPromptNode.id, sourcePortId: lastPromptOutput.id,
                                 targetNodeId: lastFrameNode.id, targetPortId: lastImagePromptInput.id),
                    WorkflowEdge(sourceNodeId: lastFrameNode.id, sourcePortId: lastImageOutput.id,
                                 targetNodeId: videoNode.id, targetPortId: videoLastInput.id),
                    WorkflowEdge(sourceNodeId: videoNode.id, sourcePortId: videoOutput.id,
                                 targetNodeId: resultNode.id, targetPortId: resultInput.id),
                ]
            )
        }
    )
}

// MARK: - Linear Chain Detection & Conversion

extension WorkflowDefinition {

    /// Whether this DAG is a simple linear chain (no branching, no fan-in/out).
    var isLinearChain: Bool {
        guard !nodes.isEmpty else { return true }

        // Build adjacency: sourceNodeId -> [targetNodeId]
        var outgoing: [String: [String]] = [:]
        var incoming: [String: [String]] = [:]
        for edge in edges {
            outgoing[edge.sourceNodeId, default: []].append(edge.targetNodeId)
            incoming[edge.targetNodeId, default: []].append(edge.sourceNodeId)
        }

        // Every node must have at most 1 outgoing and 1 incoming edge
        for node in nodes {
            if (outgoing[node.id] ?? []).count > 1 { return false }
            if (incoming[node.id] ?? []).count > 1 { return false }
        }

        // Find the source node (no incoming edges)
        let sources = nodes.filter { (incoming[$0.id] ?? []).isEmpty }
        guard sources.count == 1, let source = sources.first else { return false }

        // Walk the chain from source
        var visited = Set<String>()
        var current: String? = source.id
        while let nodeId = current {
            guard visited.insert(nodeId).inserted else { return false } // cycle
            let targets = outgoing[nodeId] ?? []
            current = targets.first
        }

        // All nodes must be visited
        return visited.count == nodes.count
    }

    /// Convert a linear DAG to `[WorkflowStep]` for the simple editor.
    /// Returns empty array if the DAG is not a linear chain.
    func toLinearSteps() -> [WorkflowStep] {
        guard isLinearChain else { return [] }
        guard !nodes.isEmpty else { return [] }

        // Build adjacency for ordering
        var outgoing: [String: String] = [:]
        var incoming: [String: String] = [:]
        for edge in edges {
            outgoing[edge.sourceNodeId] = edge.targetNodeId
            incoming[edge.targetNodeId] = edge.sourceNodeId
        }

        // Find source (no incoming)
        guard let source = nodes.first(where: { incoming[$0.id] == nil }) else { return [] }

        // Walk chain
        var steps: [WorkflowStep] = []
        var current: String? = source.id
        while let nodeId = current, let node = nodes.first(where: { $0.id == nodeId }) {
            steps.append(node.toLinearStep())
            current = outgoing[nodeId]
        }
        return steps
    }

    /// Build a linear `WorkflowDefinition` from `[WorkflowStep]`.
    /// Matches output→input ports by type compatibility (same type, or `.any`).
    /// When multiple candidates exist, prefers role-based match.
    static func fromLinearSteps(_ steps: [WorkflowStep], name: String) -> WorkflowDefinition {
        guard !steps.isEmpty else {
            return WorkflowDefinition(name: name)
        }

        var nodes: [WorkflowNode] = []
        var edges: [WorkflowEdge] = []
        var previousNode: WorkflowNode?

        for (index, step) in steps.enumerated() {
            let x = CGFloat(index) * 300
            let node = step.toWorkflowNode(position: WorkflowPoint(x: x, y: 0))
            nodes.append(node)

            if let prev = previousNode {
                if let (outPort, inPort) = bestPortMatch(from: prev, to: node) {
                    edges.append(WorkflowEdge(
                        sourceNodeId: prev.id,
                        sourcePortId: outPort.id,
                        targetNodeId: node.id,
                        targetPortId: inPort.id
                    ))
                }
            }
            previousNode = node
        }

        return WorkflowDefinition(name: name, nodes: nodes, edges: edges)
    }

    /// Find the best output→input port pair between two nodes.
    /// Priority: 1) same type 2) `.any` type 3) first available.
    private static func bestPortMatch(from source: WorkflowNode, to target: WorkflowNode) -> (WorkflowPort, WorkflowPort)? {
        let outputs = source.outputPorts
        let inputs = target.inputPorts
        guard !outputs.isEmpty, !inputs.isEmpty else { return nil }

        // Pass 1: exact type match (e.g. image→image, video→video)
        for out in outputs {
            for in_ in inputs {
                if out.portType == in_.portType && out.portType != .any {
                    return (out, in_)
                }
            }
        }

        // Pass 2: source output is .any or target input is .any
        for out in outputs {
            for in_ in inputs {
                if out.portType == .any || in_.portType == .any {
                    return (out, in_)
                }
            }
        }

        // Pass 3: fallback to first pair
        return (outputs[0], inputs[0])
    }
}

// MARK: - Node ↔ Step Conversion

extension WorkflowNode {
    /// Convert a `WorkflowNode` to a `WorkflowStep` for linear mode.
    func toLinearStep() -> WorkflowStep {
        var config = WorkflowStepConfig()
        let stepType: WorkflowStepType

        switch self.config {
        case .textInput(let c):
            stepType = .textInput
            config.text = c.text
        case .promptTemplate(let c):
            stepType = .promptTemplate
            config.promptTemplate = c.template
        case .imageGen(let c):
            stepType = .imageGen
            config.imageGenType = c.genType.rawValue
            config.imageChannel = c.channel.rawValue
            config.imageAspectRatio = c.aspectRatio.rawValue
            config.imageResolution = c.resolution.rawValue
            config.imageQuality = c.quality.rawValue
            config.imagePhotoReal = c.photoReal
        case .videoGen(let c):
            stepType = .videoGen
            config.videoGenType = c.genType.rawValue
            config.videoChannel = c.channel.rawValue
            config.videoModel = c.model
            config.videoMode = c.mode.rawValue
            config.videoAspectRatio = c.aspectRatio.rawValue
            config.videoResolution = c.resolution.rawValue
            config.videoDuration = c.duration
            config.videoGenerateAudio = c.generateAudio
            config.videoNegativePrompt = c.negativePrompt
            config.videoCount = c.count
        case .resultOutput(let c):
            stepType = .resultOutput
            config.outputLabel = c.label
        }

        return WorkflowStep(id: self.id, type: stepType, label: title, config: config)
    }
}

extension WorkflowStep {
    /// Convert a `WorkflowStep` to a `WorkflowNode` for canvas mode.
    func toWorkflowNode(position: WorkflowPoint = .zero) -> WorkflowNode {
        let nodeConfig: WorkflowNodeConfig

        switch type {
        case .textInput:
            nodeConfig = .textInput(TextInputNodeConfig(text: config.text))
        case .promptTemplate:
            nodeConfig = .promptTemplate(PromptTemplateNodeConfig(template: config.promptTemplate))
        case .imageGen:
            let genType = ImageGenType(rawValue: config.imageGenType) ?? .gptImage
            let channel = ImageChannel(rawValue: config.imageChannel) ?? .official
            let aspectRatio = AspectRatio(rawValue: config.imageAspectRatio) ?? .portrait
            let resolution = ImageResolution(rawValue: config.imageResolution) ?? .k2
            let quality = ImageQuality(rawValue: config.imageQuality) ?? .medium
            nodeConfig = .imageGen(ImageGenNodeConfig(
                genType: genType, channel: channel, aspectRatio: aspectRatio,
                resolution: resolution, quality: quality, photoReal: config.imagePhotoReal
            ))
        case .videoGen:
            let genType = VideoGenType(rawValue: config.videoGenType) ?? .veo
            let channel = VideoChannel(rawValue: config.videoChannel) ?? .budget
            let mode = VideoMode(rawValue: config.videoMode) ?? .text
            let aspectRatio = AspectRatio(rawValue: config.videoAspectRatio) ?? .portrait
            let resolution = VideoResolution(rawValue: config.videoResolution) ?? .p720
            nodeConfig = .videoGen(VideoGenNodeConfig(
                genType: genType, channel: channel, model: config.videoModel,
                mode: mode, aspectRatio: aspectRatio, resolution: resolution,
                duration: config.videoDuration, generateAudio: config.videoGenerateAudio,
                negativePrompt: config.videoNegativePrompt, count: config.videoCount
            ))
        case .resultOutput:
            nodeConfig = .resultOutput(ResultOutputNodeConfig(label: config.outputLabel))
        }

        return WorkflowNode(id: self.id, title: label, position: position, config: nodeConfig)
    }
}
