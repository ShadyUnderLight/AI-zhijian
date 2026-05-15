import Foundation

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
    case any

    var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .video: return "视频"
        case .file: return "文件"
        case .any: return "任意"
        }
    }
}

// MARK: - Port

struct WorkflowPort: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var portType: WorkflowPortType
    var nodeId: String

    /// Return a copy with `nodeId` set to the given value.
    func withNodeId(_ nodeId: String) -> WorkflowPort {
        var copy = self
        copy.nodeId = nodeId
        return copy
    }
}

// MARK: - Config Value Enums

enum ImageGenType: String, Codable, CaseIterable {
    case gptImage = "gpt-image"
    case banana
}

enum ImageChannel: String, Codable, CaseIterable {
    case official
}

enum ImageResolution: String, Codable, CaseIterable {
    case k1 = "1k"
    case k2 = "2k"
}

enum ImageQuality: String, Codable, CaseIterable {
    case low
    case medium
    case high
}

enum AspectRatio: String, Codable, CaseIterable {
    case square = "1:1"
    case landscape = "16:9"
    case portrait = "9:16"
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
}

enum VideoMode: String, Codable, CaseIterable {
    case text
    case image
    case reference
    case startEnd = "start_end"
    case extend
    case firstLast = "first_last"
}

enum VideoResolution: String, Codable, CaseIterable {
    case p720 = "720p"
    case p1080 = "1080p"
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
    var aspectRatio: AspectRatio = .square
    var resolution: ImageResolution = .k2
    var quality: ImageQuality = .medium
    var photoReal: Bool = false

    func validate() -> [WorkflowValidationError] {
        if genType == .banana && channel == .official {
            return [.invalidConfig("Banana 仅支持第三方渠道，请将 genType 设为 gpt-image 或改用专用 Banana 节点")]
        }
        return []
    }
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

    func validate() -> [WorkflowValidationError] {
        var errors: [WorkflowValidationError] = []
        let validModels: Set<String>
        let validModes: Set<VideoMode>

        switch genType {
        case .veo:
            switch channel {
            case .budget:
                validModels = ["fast", "pro"]
                if model == "fast" {
                    validModes = [.text, .image, .startEnd]
                } else if model == "pro" {
                    validModes = [.text, .startEnd]
                } else {
                    validModes = []
                }
            case .official:
                validModels = ["fast", "lite", "pro"]
                if model == "fast" {
                    validModes = [.text, .image, .startEnd, .extend]
                } else if model == "lite" {
                    validModes = [.text, .image, .startEnd]
                } else if model == "pro" {
                    validModes = Set(VideoMode.allCases)
                } else {
                    validModes = []
                }
            }
            if !validModels.contains(model) {
                errors.append(.invalidConfig("Veo 不支持模型 \(model)，可用: \(validModels.sorted().joined(separator: ", "))"))
            }
            if !validModes.isEmpty, !validModes.contains(mode) {
                errors.append(.invalidConfig("Veo \(channel.rawValue)/\(model) 不支持 \(mode.rawValue) 模式"))
            }
        case .grok:
            if mode != .text {
                errors.append(.invalidConfig("Grok 工作流仅支持文生视频 (text) 模式"))
            }
        case .seedance:
            if model.isEmpty || model == "fast" {
                errors.append(.invalidConfig("Seedance 需要指定模型，如 dreamina-seedance-2-0-260128"))
            }
            if ![.reference, .firstLast].contains(mode) {
                errors.append(.invalidConfig("Seedance 仅支持 reference / first_last 模式"))
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
            return [WorkflowPort(name: "文本", portType: .text, nodeId: nodeId)]
        case .imageGen:
            return [WorkflowPort(name: "提示词", portType: .text, nodeId: nodeId)]
        case .videoGen:
            return [
                WorkflowPort(name: "提示词", portType: .text, nodeId: nodeId),
                WorkflowPort(name: "图片", portType: .image, nodeId: nodeId)
            ]
        case .resultOutput:
            return [WorkflowPort(name: "输入", portType: .any, nodeId: nodeId)]
        }
    }

    private static func defaultOutputPorts(for config: WorkflowNodeConfig, nodeId: String) -> [WorkflowPort] {
        switch config {
        case .textInput:
            return [WorkflowPort(name: "文本", portType: .text, nodeId: nodeId)]
        case .promptTemplate:
            return [WorkflowPort(name: "拼装文本", portType: .text, nodeId: nodeId)]
        case .imageGen:
            return [WorkflowPort(name: "图片", portType: .image, nodeId: nodeId)]
        case .videoGen:
            return [WorkflowPort(name: "视频", portType: .video, nodeId: nodeId)]
        case .resultOutput:
            return []
        }
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
        case .skipped: return "已跳过"
        case .cancelled: return "已取消"
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
    case invalidConfig(String)

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
        case .invalidConfig(let msg):
            return "配置无效: \(msg)"
        }
    }
}

// MARK: - DAG Validation

extension WorkflowDefinition {

    /// Validate the structural integrity of the workflow DAG.
    /// Checks: node/port uniqueness, port ownership, edge endpoints, port direction,
    /// type compatibility, single-source input ports, and cycle-free.
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
        nodes.flatMap { $0.config.validate() }
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

    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, enc in
            let f = Self.makeISOFormatter()
            var c = enc.singleValueContainer()
            try c.encode(f.string(from: date.truncatedToMilliseconds))
        }
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> WorkflowDefinition {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let f = Self.makeISOFormatter()
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            guard let d = f.date(from: s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid ISO8601 date: \(s)")
            }
            return d
        }
        return try decoder.decode(WorkflowDefinition.self, from: data)
    }
}

// MARK: - Sample Workflow

extension WorkflowDefinition {
    /// 验收样例：文本输入 → 图片生成 → 视频生成（图生视频模式）
    static func sample() -> WorkflowDefinition {
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

        let textOutput = textNode.outputPorts.first(where: { $0.portType == .text })!
        let imageTextInput = imageNode.inputPorts.first(where: { $0.portType == .text })!
        let imageOutput = imageNode.outputPorts.first(where: { $0.portType == .image })!
        let videoImageInput = videoNode.inputPorts.first(where: { $0.portType == .image })!

        let edges: [WorkflowEdge] = [
            WorkflowEdge(
                sourceNodeId: textNode.id,
                sourcePortId: textOutput.id,
                targetNodeId: imageNode.id,
                targetPortId: imageTextInput.id
            ),
            WorkflowEdge(
                sourceNodeId: imageNode.id,
                sourcePortId: imageOutput.id,
                targetNodeId: videoNode.id,
                targetPortId: videoImageInput.id
            )
        ]

        return WorkflowDefinition(
            name: "文生图转视频",
            nodes: [textNode, imageNode, videoNode],
            edges: edges
        )
    }
}
