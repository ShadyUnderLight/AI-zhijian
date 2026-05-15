import Foundation

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
}

// MARK: - Node Configs

struct TextInputNodeConfig: Codable, Equatable, Hashable {
    var text: String = ""
}

struct PromptTemplateNodeConfig: Codable, Equatable, Hashable {
    var template: String = ""
}

struct ImageGenNodeConfig: Codable, Equatable, Hashable {
    var genType: String = "gpt-image"
    var channel: String = "official"
    var aspectRatio: String = "1:1"
    var resolution: String = "2k"
    var quality: String = "medium"
    var photoReal: Bool = false
}

struct VideoGenNodeConfig: Codable, Equatable, Hashable {
    var genType: String = "veo"
    var channel: String = "budget"
    var model: String = "fast"
    var mode: String = "text"
    var aspectRatio: String = "9:16"
    var resolution: String = "720p"
    var duration: String = "8"
    var generateAudio: Bool = false
}

struct ResultOutputNodeConfig: Codable, Equatable, Hashable {
    var label: String = "最终结果"
}

enum WorkflowNodeConfig: Codable, Equatable, Hashable {
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
        self.inputPorts = inputPorts ?? Self.defaultInputPorts(for: config, nodeId: nodeId)
        self.outputPorts = outputPorts ?? Self.defaultOutputPorts(for: config, nodeId: nodeId)
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
            return [WorkflowPort(name: "提示词", portType: .text, nodeId: nodeId)]
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
    var id: String = UUID().uuidString
    var name: String
    var nodes: [WorkflowNode] = []
    var edges: [WorkflowEdge] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
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

// MARK: - JSON Helpers

extension WorkflowDefinition {
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> WorkflowDefinition {
        try JSONDecoder().decode(WorkflowDefinition.self, from: data)
    }
}

// MARK: - Sample Workflow

extension WorkflowDefinition {
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
        let videoNode = WorkflowNode(
            title: "视频生成",
            position: WorkflowPoint(x: 600, y: 0),
            config: .videoGen(VideoGenNodeConfig())
        )

        let edges: [WorkflowEdge] = [
            WorkflowEdge(
                sourceNodeId: textNode.id,
                sourcePortId: textNode.outputPorts.first!.id,
                targetNodeId: imageNode.id,
                targetPortId: imageNode.inputPorts.first!.id
            ),
            WorkflowEdge(
                sourceNodeId: imageNode.id,
                sourcePortId: imageNode.outputPorts.first!.id,
                targetNodeId: videoNode.id,
                targetPortId: videoNode.inputPorts.first!.id
            )
        ]

        return WorkflowDefinition(
            name: "文生图转视频",
            nodes: [textNode, imageNode, videoNode],
            edges: edges
        )
    }
}
