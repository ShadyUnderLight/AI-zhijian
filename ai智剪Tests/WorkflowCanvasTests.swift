import XCTest
@testable import aiZhijian

final class WorkflowCanvasTests: XCTestCase {

    // MARK: - WorkflowNode Tests

    func testWorkflowNodeDefaultPorts() {
        let node = WorkflowNode(
            title: "文本输入",
            config: .textInput(TextInputNodeConfig())
        )

        XCTAssertTrue(node.inputPorts.isEmpty)
        XCTAssertEqual(node.outputPorts.count, 1)
        XCTAssertEqual(node.outputPorts.first?.portType, .text)
    }

    func testWorkflowNodeImageGenPorts() {
        let node = WorkflowNode(
            title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )

        XCTAssertEqual(node.inputPorts.count, 1)
        XCTAssertEqual(node.inputPorts.first?.portType, .text)
        XCTAssertEqual(node.outputPorts.count, 1)
        XCTAssertEqual(node.outputPorts.first?.portType, .image)
    }

    func testWorkflowNodeVideoGenPorts() {
        let node = WorkflowNode(
            title: "视频生成",
            config: .videoGen(VideoGenNodeConfig())
        )

        XCTAssertEqual(node.inputPorts.count, 4)
        XCTAssertTrue(node.inputPorts.contains(where: { $0.name == "提示词" && $0.portType == .text }))
        XCTAssertTrue(node.inputPorts.contains(where: { $0.name == "图片" && $0.portType == .image }))
        XCTAssertTrue(node.inputPorts.contains(where: { $0.name == "首帧图片" && $0.portType == .image }))
        XCTAssertTrue(node.inputPorts.contains(where: { $0.name == "尾帧图片" && $0.portType == .image }))
        XCTAssertEqual(node.outputPorts.count, 1)
        XCTAssertEqual(node.outputPorts.first?.portType, .video)
    }

    // MARK: - WorkflowEdge Tests

    func testWorkflowEdgeCreation() {
        let edge = WorkflowEdge(
            sourceNodeId: "node1",
            sourcePortId: "port1",
            targetNodeId: "node2",
            targetPortId: "port2"
        )

        XCTAssertFalse(edge.id.isEmpty)
        XCTAssertEqual(edge.sourceNodeId, "node1")
        XCTAssertEqual(edge.sourcePortId, "port1")
        XCTAssertEqual(edge.targetNodeId, "node2")
        XCTAssertEqual(edge.targetPortId, "port2")
    }

    // MARK: - WorkflowDefinition Tests

    func testWorkflowDefinitionAddNode() {
        var definition = WorkflowDefinition(name: "测试工作流")
        let node = WorkflowNode(
            title: "文本输入",
            config: .textInput(TextInputNodeConfig())
        )

        definition.nodes.append(node)

        XCTAssertEqual(definition.nodes.count, 1)
        XCTAssertEqual(definition.nodes.first?.title, "文本输入")
    }

    func testWorkflowDefinitionAddEdge() {
        var definition = WorkflowDefinition(name: "测试工作流")

        let node1 = WorkflowNode(
            id: "node1",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig())
        )
        let node2 = WorkflowNode(
            id: "node2",
            title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )

        definition.nodes = [node1, node2]

        let edge = WorkflowEdge(
            sourceNodeId: "node1",
            sourcePortId: node1.outputPorts.first!.id,
            targetNodeId: "node2",
            targetPortId: node2.inputPorts.first!.id
        )

        definition.edges.append(edge)

        XCTAssertEqual(definition.edges.count, 1)
        XCTAssertEqual(definition.edges.first?.sourceNodeId, "node1")
        XCTAssertEqual(definition.edges.first?.targetNodeId, "node2")
    }

    func testWorkflowDefinitionDeleteNodeRemovesEdges() {
        var definition = WorkflowDefinition(name: "测试工作流")

        let node1 = WorkflowNode(
            id: "node1",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig())
        )
        let node2 = WorkflowNode(
            id: "node2",
            title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )

        definition.nodes = [node1, node2]

        let edge = WorkflowEdge(
            sourceNodeId: "node1",
            sourcePortId: node1.outputPorts.first!.id,
            targetNodeId: "node2",
            targetPortId: node2.inputPorts.first!.id
        )

        definition.edges = [edge]

        // Delete node1
        definition.nodes.removeAll(where: { $0.id == "node1" })
        definition.edges.removeAll(where: { $0.sourceNodeId == "node1" || $0.targetNodeId == "node1" })

        XCTAssertEqual(definition.nodes.count, 1)
        XCTAssertTrue(definition.edges.isEmpty)
    }

    // MARK: - WorkflowNodeType Tests

    func testWorkflowNodeTypeDisplayName() {
        XCTAssertEqual(WorkflowNodeType.textInput.displayName, "文本输入")
        XCTAssertEqual(WorkflowNodeType.imageGen.displayName, "图片生成")
        XCTAssertEqual(WorkflowNodeType.videoGen.displayName, "视频生成")
        XCTAssertEqual(WorkflowNodeType.resultOutput.displayName, "结果输出")
    }

    func testWorkflowNodeTypeIcon() {
        XCTAssertEqual(WorkflowNodeType.textInput.icon, "text.cursor")
        XCTAssertEqual(WorkflowNodeType.imageGen.icon, "photo.badge.plus")
        XCTAssertEqual(WorkflowNodeType.videoGen.icon, "video.badge.plus")
        XCTAssertEqual(WorkflowNodeType.resultOutput.icon, "arrow.down.to.line")
    }

    // MARK: - WorkflowPortType Tests

    func testWorkflowPortTypeDisplayName() {
        XCTAssertEqual(WorkflowPortType.text.displayName, "文本")
        XCTAssertEqual(WorkflowPortType.image.displayName, "图片")
        XCTAssertEqual(WorkflowPortType.video.displayName, "视频")
        XCTAssertEqual(WorkflowPortType.any.displayName, "任意")
    }

    // MARK: - WorkflowNodeStatus Tests

    func testWorkflowNodeStatusDisplayName() {
        XCTAssertEqual(WorkflowNodeStatus.pending.displayName, "等待中")
        XCTAssertEqual(WorkflowNodeStatus.running.displayName, "执行中")
        XCTAssertEqual(WorkflowNodeStatus.succeeded.displayName, "已完成")
        XCTAssertEqual(WorkflowNodeStatus.failed.displayName, "失败")
    }

    // MARK: - CanvasNodePosition Tests

    func testCanvasNodePosition() {
        let position = CanvasNodePosition(id: "node1", position: CGPoint(x: 100, y: 200))
        XCTAssertEqual(position.id, "node1")
        XCTAssertEqual(position.position.x, 100)
        XCTAssertEqual(position.position.y, 200)
    }

    // MARK: - PortDragState Tests

    func testPortDragStateIdle() {
        let state: PortDragState = .idle
        if case .idle = state {
            // Pass
        } else {
            XCTFail("Expected idle state")
        }
    }

    func testPortDragStateDragging() {
        let state: PortDragState = .dragging(
            sourcePortId: "port1",
            sourceNodeId: "node1",
            sourceIsOutput: true,
            sourcePoint: CGPoint(x: 0, y: 0),
            currentPoint: CGPoint(x: 100, y: 100)
        )

        if case .dragging(let portId, let nodeId, let isOutput, _, _) = state {
            XCTAssertEqual(portId, "port1")
            XCTAssertEqual(nodeId, "node1")
            XCTAssertTrue(isOutput)
        } else {
            XCTFail("Expected dragging state")
        }
    }

    // MARK: - WorkflowDefinition JSON Roundtrip with Edges

    func testWorkflowDefinitionWithEdgesRoundTrips() throws {
        let node1 = WorkflowNode(
            id: "input",
            title: "输入",
            position: WorkflowPoint(x: 0, y: 0),
            config: .textInput(TextInputNodeConfig(text: "测试"))
        )
        let node2 = WorkflowNode(
            id: "output",
            title: "输出",
            position: WorkflowPoint(x: 300, y: 0),
            config: .resultOutput(ResultOutputNodeConfig())
        )

        let edge = WorkflowEdge(
            id: "edge1",
            sourceNodeId: "input",
            sourcePortId: node1.outputPorts.first!.id,
            targetNodeId: "output",
            targetPortId: node2.inputPorts.first!.id
        )

        let definition = WorkflowDefinition(
            id: "test",
            name: "测试工作流",
            nodes: [node1, node2],
            edges: [edge]
        )

        let data = try definition.encode()
        let decoded = try WorkflowDefinition.decode(from: data)

        XCTAssertEqual(decoded.nodes.count, 2)
        XCTAssertEqual(decoded.edges.count, 1)
        XCTAssertEqual(decoded.edges.first?.id, "edge1")
        XCTAssertEqual(decoded.edges.first?.sourceNodeId, "input")
        XCTAssertEqual(decoded.edges.first?.targetNodeId, "output")
    }

    // MARK: - WorkflowValue.imageValues Tests

    func testWorkflowValueImageReturnsImages() {
        let single = WorkflowValue.image(WorkflowImage(localFile: nil, remoteURL: "https://a.com/1.png"))
        XCTAssertEqual(single.imageValues?.count, 1)
        XCTAssertEqual(single.imageValues?.first?.remoteURL, "https://a.com/1.png")

        let multi = WorkflowValue.images([
            WorkflowImage(localFile: nil, remoteURL: "https://a.com/1.png"),
            WorkflowImage(localFile: nil, remoteURL: "https://a.com/2.png")
        ])
        XCTAssertEqual(multi.imageValues?.count, 2)
    }

    func testWorkflowValueImagesWorksWithVeoImageMode() {
        // Uses the shared firstRemoteImageURL helper
        let imageValue: WorkflowValue = .images([
            WorkflowImage(localFile: nil, remoteURL: "https://a.com/frame.png")
        ])

        XCTAssertEqual(imageValue.firstRemoteImageURL, "https://a.com/frame.png")

        let singleImage: WorkflowValue = .image(WorkflowImage(localFile: nil, remoteURL: "https://a.com/single.png"))
        XCTAssertEqual(singleImage.firstRemoteImageURL, "https://a.com/single.png")

        let noImage: WorkflowValue = .none
        XCTAssertNil(noImage.firstRemoteImageURL)
    }

    // MARK: - Seedance/Wan DAG Validation Tests

    func testSeedanceNodeFailsDAGValidation() {
        let textNode = WorkflowNode(
            id: "text",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "测试"))
        )
        var seedanceConfig = VideoGenNodeConfig()
        seedanceConfig.genType = .seedance
        seedanceConfig.model = "dreamina-seedance-2-0-260128"
        seedanceConfig.mode = .reference
        let seedanceNode = WorkflowNode(
            id: "video",
            title: "Seedance 视频",
            position: WorkflowPoint(x: 300, y: 0),
            config: .videoGen(seedanceConfig)
        )

        let definition = WorkflowDefinition(
            name: "Seedance 测试",
            nodes: [textNode, seedanceNode],
            edges: []
        )

        let errors = definition.fullValidate()
        XCTAssertTrue(errors.contains(.invalidConfig("画布暂不支持 Seedance 参考素材，请使用 Veo 或 Grok")))
    }

    func testWanNodeFailsDAGValidation() {
        let textNode = WorkflowNode(
            id: "text",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "测试"))
        )
        var wanConfig = VideoGenNodeConfig()
        wanConfig.genType = .wan
        let wanNode = WorkflowNode(
            id: "video",
            title: "Wan 视频",
            position: WorkflowPoint(x: 300, y: 0),
            config: .videoGen(wanConfig)
        )

        let definition = WorkflowDefinition(
            name: "Wan 测试",
            nodes: [textNode, wanNode],
            edges: []
        )

        let errors = definition.fullValidate()
        XCTAssertTrue(errors.contains(.invalidConfig("Wan 视频需要本地文件输入，暂不支持在画布中使用")))
    }

    func testVeoNodePassesDAGValidation() {
        let textNode = WorkflowNode(
            id: "text",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "测试"))
        )
        let veoConfig = VideoGenNodeConfig()
        let veoNode = WorkflowNode(
            id: "video",
            title: "Veo 视频",
            position: WorkflowPoint(x: 300, y: 0),
            config: .videoGen(veoConfig)
        )

        let edge = WorkflowEdge(
            sourceNodeId: "text",
            sourcePortId: textNode.outputPorts.first!.id,
            targetNodeId: "video",
            targetPortId: veoNode.inputPorts.first!.id
        )

        let definition = WorkflowDefinition(
            name: "Veo 测试",
            nodes: [textNode, veoNode],
            edges: [edge]
        )

        let errors = definition.fullValidate()
        let seedanceErrors = errors.filter {
            if case .invalidConfig(let msg) = $0 { return msg.contains("Seedance") || msg.contains("Wan") }
            return false
        }
        XCTAssertTrue(seedanceErrors.isEmpty, "Veo 节点不应被 Seedance/Wan 规则拒绝")
    }
}
